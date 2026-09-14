-- ============================================================
-- Migration: Driver Wallet (محفظة الموصّلين) — نفس نظام محفظة التجار
-- (merchant_wallet, migration 20260829000000) بالحرف، لكل من التوصيل
-- والطاكسي. طلب صريح من المستخدم بعد شرح النظام المالي الحالي.
--
-- السياق: orders/ride_requests/delivery_requests الثلاثة تحسب بالفعل
-- حصة الموصّل (driver_earning_share) وحصة المنصّة (platform_delivery
-- _share/platform_share) وقت الإنشاء — لكن هذه الأرقام معلوماتية فقط
-- حاليًا، بلا أي تسوية فعلية (راجع تعليق العمود فـ migration
-- 20260901000000: "لا يوجد نظام محفظة/صرف للموصّلين بعد"). هذه الـ
-- migration تسدّ هذه الفجوة بالضبط.
--
-- الفرق الجوهري عن محفظة التجار: مصدر واحد للخصم عند التجار (orders
-- فقط)، ثلاثة مصادر مستقلة تمامًا عند الموصّلين (orders/ride_requests/
-- delivery_requests) — لذا driver_wallet_transactions تحمل 3 أعمدة
-- مرجعية اختيارية بدل واحد، بدل جدول واحد أو ثلاثة جداول منفصلة.
--
-- المبلغ المخصوم من الموصّل هو حصة المنصّة (platform_*_share)، لا حصة
-- الموصّل (driver_earning_share يبقى ملكه بالكامل) — نفس منطق التاجر
-- بالضبط (المنصّة تأخذ عمولتها، الباقي يبقى للطرف الآخر).
-- ============================================================

create table driver_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references drivers (id),
  type text not null check (type in ('topup', 'deduction', 'commission')),
  amount numeric not null,
  note text,
  order_id uuid references orders (id),
  ride_request_id uuid references ride_requests (id),
  delivery_request_id uuid references delivery_requests (id),
  created_by uuid references users (id),
  created_at timestamptz not null default now(),
  -- نفس sign convention محفظة التجار بالحرف: topup > 0، deduction/commission < 0.
  constraint driver_wallet_transactions_sign_check check (
    (type = 'topup' and amount > 0) or
    (type in ('deduction', 'commission') and amount < 0)
  ),
  -- حركة "commission" مرتبطة بمصدر واحد بالضبط (طلبية أو رحلة أو طلب
  -- حر، لا أكثر من واحد ولا صفر)؛ topup/deduction اليدويتان بلا أي
  -- مصدر (الثلاثة null).
  constraint driver_wallet_transactions_source_check check (
    (type in ('topup', 'deduction')
      and order_id is null and ride_request_id is null and delivery_request_id is null)
    or
    (type = 'commission'
      and (case when order_id is not null then 1 else 0 end
         + case when ride_request_id is not null then 1 else 0 end
         + case when delivery_request_id is not null then 1 else 0 end) = 1)
  ),
  -- منع خصم مزدوج لنفس المهمة — ثلاثة قيود منفصلة بدل واحد لأن NULL لا
  -- يخالف أي قيد unique (سلوك SQL قياسي)، فكل قيد يتجاهل الصفوف التي
  -- عمودها المرجعي فارغ تلقائيًا. نفس حماية
  -- wallet_transactions_order_unique الأصلية بالضبط.
  constraint driver_wallet_transactions_order_unique unique (order_id, type),
  constraint driver_wallet_transactions_ride_unique unique (ride_request_id, type),
  constraint driver_wallet_transactions_delivery_unique unique (delivery_request_id, type)
);

comment on table driver_wallet_transactions is 'سجل حركات محفظة الموصّل (Ledger) — المصدر الوحيد للحقيقة، الرصيد = SUM(amount). لا UPDATE ولا DELETE مسموح لأي طرف؛ الإدراج فقط عبر admin_driver_wallet_topup/admin_driver_wallet_deduct (يدوي) أو الـ3 Triggers أدناه (تلقائي عند اكتمال كل نوع مهمة).';

create index driver_wallet_transactions_driver_id_idx on driver_wallet_transactions (driver_id, created_at desc);

alter table driver_wallet_transactions enable row level security;

create policy "driver_wallet_transactions_select_admin"
  on driver_wallet_transactions for select
  using (public.has_capability('wallet.view'));

create policy "driver_wallet_transactions_select_own_driver"
  on driver_wallet_transactions for select
  using (
    exists (
      select 1 from drivers d
      where d.id = driver_wallet_transactions.driver_id
        and d.user_id = auth.uid()
    )
  );

-- ============================================================
-- admin_driver_wallet_topup / admin_driver_wallet_deduct — نسخة حرفية
-- من admin_wallet_topup/admin_wallet_deduct (merchant_wallet).
-- ============================================================

create function public.admin_driver_wallet_topup(p_driver_id uuid, p_amount numeric, p_note text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.has_capability('wallet.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة المحفظة';
  end if;

  if p_amount <= 0 then
    raise exception 'مبلغ الإيداع يجب أن يكون أكبر من صفر';
  end if;

  if not exists (select 1 from drivers where id = p_driver_id) then
    raise exception 'الموصّل غير موجود';
  end if;

  insert into driver_wallet_transactions (driver_id, type, amount, note, created_by)
  values (p_driver_id, 'topup', p_amount, p_note, auth.uid());
end;
$$;

comment on function public.admin_driver_wallet_topup is 'تسجيل دفعة نقدية استلمها المكتب من الموصّل — يزيد رصيده. الإجراء المالي اليدوي الوحيد المتاح اليوم (لا Payment Gateway).';

create function public.admin_driver_wallet_deduct(p_driver_id uuid, p_amount numeric, p_note text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.has_capability('wallet.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة المحفظة';
  end if;

  if p_amount <= 0 then
    raise exception 'مبلغ الخصم يجب أن يكون أكبر من صفر';
  end if;

  if not exists (select 1 from drivers where id = p_driver_id) then
    raise exception 'الموصّل غير موجود';
  end if;

  insert into driver_wallet_transactions (driver_id, type, amount, note, created_by)
  values (p_driver_id, 'deduction', -p_amount, p_note, auth.uid());
end;
$$;

comment on function public.admin_driver_wallet_deduct is 'خصم يدوي من رصيد الموصّل (تصحيح/غرامة...) بقرار إداري صريح، مع سبب مسجَّل في note. p_amount يُدخَل موجبًا (مبلغ الخصم)، يُخزَّن سالبًا داخليًا تلقائيًا.';

-- ============================================================
-- الخصم التلقائي لحصة المنصّة عند اكتمال كل نوع مهمة فعليًا — ثلاثة
-- Triggers مستقلة، كل واحد على جدوله الخاص. نفس منطق
-- record_order_commission_ledger (محفظة التجار) بالحرف، فقط الجدول
-- والعمود المرجعي والحقل المخصوم يتغيّرون.
-- ============================================================

create function public.record_order_driver_commission_ledger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'delivered' and old.status is distinct from new.status
     and new.driver_id is not null and new.platform_delivery_share > 0 then
    insert into driver_wallet_transactions (driver_id, type, amount, order_id)
    values (new.driver_id, 'commission', -new.platform_delivery_share, new.id)
    on conflict (order_id, type) do nothing;
  end if;
  return new;
end;
$$;

comment on function public.record_order_driver_commission_ledger is 'يسجّل تلقائيًا حركة عمولة سالبة فـ محفظة الموصّل (حصة المنصّة من رسوم التوصيل) عند وصول طلبية لحالة delivered — مرة واحدة فقط لكل طلبية.';

create trigger orders_record_driver_commission_ledger
  after update on orders
  for each row execute function public.record_order_driver_commission_ledger();

create function public.record_ride_driver_commission_ledger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'completed' and old.status is distinct from new.status
     and new.driver_id is not null and new.platform_share > 0 then
    insert into driver_wallet_transactions (driver_id, type, amount, ride_request_id)
    values (new.driver_id, 'commission', -new.platform_share, new.id)
    on conflict (ride_request_id, type) do nothing;
  end if;
  return new;
end;
$$;

comment on function public.record_ride_driver_commission_ledger is 'يسجّل تلقائيًا حركة عمولة سالبة فـ محفظة الموصّل (حصة المنصّة من الأجرة) عند وصول رحلة Taxi لحالة completed — مرة واحدة فقط لكل رحلة.';

create trigger ride_requests_record_driver_commission_ledger
  after update on ride_requests
  for each row execute function public.record_ride_driver_commission_ledger();

create function public.record_delivery_request_driver_commission_ledger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'delivered' and old.status is distinct from new.status
     and new.driver_id is not null and new.platform_delivery_share > 0 then
    insert into driver_wallet_transactions (driver_id, type, amount, delivery_request_id)
    values (new.driver_id, 'commission', -new.platform_delivery_share, new.id)
    on conflict (delivery_request_id, type) do nothing;
  end if;
  return new;
end;
$$;

comment on function public.record_delivery_request_driver_commission_ledger is 'يسجّل تلقائيًا حركة عمولة سالبة فـ محفظة الموصّل (حصة المنصّة من رسوم التوصيل) عند وصول طلب "اطلب أي شيء" لحالة delivered — مرة واحدة فقط لكل طلب.';

create trigger delivery_requests_record_driver_commission_ledger
  after update on delivery_requests
  for each row execute function public.record_delivery_request_driver_commission_ledger();

-- تسجيل التوب-أب/الخصم اليدوي فـ سجل نشاطات الإدارة — نفس الدالة العامة
-- الموجودة أصلًا (log_admin_activity)، نفس نمط wallet_transactions.
create trigger log_driver_wallet_transactions_admin_activity
  after insert on driver_wallet_transactions
  for each row execute function public.log_admin_activity();
