-- ============================================================
-- Migration: Merchant Wallet + Manual Top-up + Ledger
-- (قسم 7 من MASTER PRODUCT REQUIREMENTS — أول ميزة فعلية تستهلك
-- has_capability()/role_capabilities من "ADMIN CONTROL CENTER
-- FOUNDATION" بدل is_admin() المباشرة، تمامًا كما وُثِّق وقتها).
--
-- السياق: لا يوجد Payment Gateway. الدفع يتم في المكتب — التاجر يدفع
-- نقدًا، موظف الإدارة يسجّل "Manual Top-up" فيزيد رصيد التاجر. كل
-- طلب مُسلَّم (delivered) يُسجَّل تلقائيًا كحركة "commission" سالبة —
-- نفس نسبة العمولة المحسوبة أصلًا في create_order (platform_commission
-- _amount)، لا حساب جديد ولا Hardcoded.
--
-- تصميم "الرصيد": لا عمود balance منفصل يمكن أن ينحرف عن السجل — الرصيد
-- الفعلي هو ببساطة SUM(amount) لكل حركات التاجر في wallet_transactions
-- (تُحسَب عند القراءة في الواجهة). مصدر حقيقة واحد فقط، مطابق تمامًا
-- لمتطلَّب "كل حركة مالية يجب أن تكون قابلة للتدقيق" — لا رقم منفصل قد
-- يتعارض مع مجموع الحركات الفعلي.
--
-- التوقيع (sign convention): topup > 0، deduction/commission < 0.
-- الرصيد = مجموع كل الحركات ببساطة.
-- ============================================================

create table wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references merchants (id),
  type text not null check (type in ('topup', 'deduction', 'commission')),
  amount numeric not null,
  note text,
  order_id uuid references orders (id),
  created_by uuid references users (id),
  created_at timestamptz not null default now(),
  -- topup موجب دائمًا، deduction/commission سالبة دائمًا — يمنع خطأ
  -- إشارة عكسية عند الإدخال (سواء من RPC أو من الـ Trigger أدناه).
  constraint wallet_transactions_sign_check check (
    (type = 'topup' and amount > 0) or
    (type in ('deduction', 'commission') and amount < 0)
  ),
  -- حركة العمولة التلقائية مرتبطة بطلب واحد فقط، ومرة واحدة له (يمنع
  -- بنيويًا احتساب نفس عمولة الطلب مرتين لو أُعيد تشغيل الـ Trigger أو
  -- migration بالخطأ).
  constraint wallet_transactions_order_unique unique (order_id, type)
);

comment on table wallet_transactions is 'سجل حركات محفظة التاجر (Ledger) — المصدر الوحيد للحقيقة، الرصيد = SUM(amount). لا UPDATE ولا DELETE مسموح لأي طرف؛ الإدراج فقط عبر admin_wallet_topup/admin_wallet_deduct (يدوي) أو Trigger الطلب المُسلَّم (تلقائي).';

create index wallet_transactions_merchant_id_idx on wallet_transactions (merchant_id, created_at desc);

alter table wallet_transactions enable row level security;

-- القراءة فقط: لا Policy لـ insert/update/delete على الإطلاق — نفس نمط
-- settings المُتَّبع أصلًا (الكتابة حصرًا عبر SECURITY DEFINER).
create policy "wallet_transactions_select_admin"
  on wallet_transactions for select
  using (public.has_capability('wallet.view'));

create policy "wallet_transactions_select_own_merchant"
  on wallet_transactions for select
  using (
    exists (
      select 1 from merchants m
      where m.id = wallet_transactions.merchant_id
        and m.owner_user_id = auth.uid()
    )
  );

-- ============================================================
-- admin_wallet_topup / admin_wallet_deduct — الكتابة اليدوية الوحيدة
-- المسموحة، تمامًا كنمط admin_set_delivery_fee. أول استهلاك فعلي لـ
-- has_capability() بدل is_admin() المباشرة (wallet.manage مُهيَّأة
-- لدور admin فقط اليوم في role_capabilities الأصلية).
-- ============================================================

create function public.admin_wallet_topup(p_merchant_id uuid, p_amount numeric, p_note text default null)
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

  if not exists (select 1 from merchants where id = p_merchant_id) then
    raise exception 'المحل غير موجود';
  end if;

  insert into wallet_transactions (merchant_id, type, amount, note, created_by)
  values (p_merchant_id, 'topup', p_amount, p_note, auth.uid());
end;
$$;

comment on function public.admin_wallet_topup is 'تسجيل دفعة نقدية استلمها المكتب من التاجر — يزيد رصيده. الإجراء المالي اليدوي الوحيد المتاح اليوم (لا Payment Gateway).';

create function public.admin_wallet_deduct(p_merchant_id uuid, p_amount numeric, p_note text default null)
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

  if not exists (select 1 from merchants where id = p_merchant_id) then
    raise exception 'المحل غير موجود';
  end if;

  insert into wallet_transactions (merchant_id, type, amount, note, created_by)
  values (p_merchant_id, 'deduction', -p_amount, p_note, auth.uid());
end;
$$;

comment on function public.admin_wallet_deduct is 'خصم يدوي من رصيد التاجر (تصحيح/غرامة...) بقرار إداري صريح، مع سبب مسجَّل في note. p_amount يُدخَل موجبًا (مبلغ الخصم)، يُخزَّن سالبًا داخليًا تلقائيًا.';

-- ============================================================
-- الخصم التلقائي للعمولة عند تسليم الطلب فعليًا — يعيد استخدام
-- platform_commission_amount المحسوبة أصلًا في create_order (Phase 6)،
-- لا حساب جديد ولا نسبة Hardcoded هنا إطلاقًا. يعمل بغضّ النظر عن
-- الفاعل (موصّل أو إدارة) لأنه Trigger منفصل على القيمة النهائية للصف،
-- لا على من نفّذ التحديث.
-- ============================================================

create function public.record_order_commission_ledger()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- new.platform_commission_amount > 0 يستثني الحالة النادرة (نظريًا)
  -- لعمولة صفرية — لا فائدة من حركة Ledger بقيمة صفر، ويتجنّب أيضًا
  -- مخالفة wallet_transactions_sign_check التي تفرض amount < 0 صراحةً
  -- لنوع commission.
  if new.status = 'delivered' and old.status is distinct from new.status
     and new.platform_commission_amount > 0 then
    insert into wallet_transactions (merchant_id, type, amount, order_id)
    values (new.merchant_id, 'commission', -new.platform_commission_amount, new.id)
    on conflict (order_id, type) do nothing;
  end if;
  return new;
end;
$$;

comment on function public.record_order_commission_ledger is 'يسجّل تلقائيًا حركة عمولة سالبة فـ محفظة التاجر عند وصول الطلب لحالة delivered — مرة واحدة فقط لكل طلب (محمي بقيد wallet_transactions_order_unique + ON CONFLICT DO NOTHING دفاعيًا).';

create trigger orders_record_commission_ledger
  after update on orders
  for each row execute function public.record_order_commission_ledger();

-- تسجيل التوب-أب/الخصم اليدوي فـ سجل نشاطات الإدارة — نفس الدالة العامة
-- الموجودة أصلًا (log_admin_activity)، لا نظام Audit موازٍ جديد. تتجاهل
-- تلقائيًا حركات العمولة الآلية (auth.uid() هو الموصّل/النظام حينها، لا
-- أدمن) بفضل فحصها الداخلي is_admin() الموجود مسبقًا — سلوك صحيح: سجل
-- العمولة نفسه (wallet_transactions) هو التوثيق الكافي لها.
create trigger log_wallet_transactions_admin_activity
  after insert on wallet_transactions
  for each row execute function public.log_admin_activity();
