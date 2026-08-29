-- ============================================================
-- Migration: Fraud / Anti-Abuse System (PRD sections 17-18)
--
-- نطاق هذه المرحلة (قرار صريح، موثَّق لمنع الالتباس لاحقًا):
--
-- 1) جدول fraud_cases + تسجيل يدوي (الإدارة) وتلقائي (نظام) لمخالفة
--    واحدة قابلة للرصد الآلي الدقيق فعليًا اليوم: "إلغاء الطلبات
--    المتكرر" (العميل يلغي طلبه الخاص وهو pending). بقية أنواع
--    المخالفات المذكورة فـ الطلب الأصلي ("محاولة تنفيذ الطلب خارج
--    النظام"، "سلوك مشبوه"...) غير قابلة للرصد الآلي من البيانات
--    الموجودة اليوم — تُسجَّل فقط يدويًا من الإدارة عبر
--    admin_log_fraud_violation (نفس المسار، لا فرق فـ المعالجة).
--
-- 2) حدود Warning/Suspension قابلة للتعديل بالكامل من الإدارة — تُخزَّن
--    فـ جدول settings الموجود أصلًا (لا جدول تهيئة جديد)، بنفس مفاتيح
--    نصية جديدة (fraud_warning_threshold، fraud_suspension_threshold)،
--    تُقرأ/تُكتَب عبر admin_get_settings/admin_set_setting الموجودتين
--    فعلًا — تعمل تلقائيًا فـ صفحة الإعدادات الحالية بلا أي كود جديد.
--
-- 3) رقم التواصل عند الإيقاف: لا حاجة لإعداد "Support Contact" جديد —
--    app_contact موجود أصلًا ومعروض فعليًا فـ تطبيق الزبون بالكامل.
--
-- 4) الإيقاف (Suspension) فعليًا: عمود واحد users.is_suspended يقفل كل
--    الأدوار الثلاثة معًا (عميل/تاجر/موصّل جميعًا حسابات فـ users) —
--    بدل تعديل RLS عبر عشرات الجداول (خطر أكبر بكثير). التطبيق الفعلي
--    لهذه المرحلة: يُمنع الحساب الموقوف من إنشاء طلب جديد
--    (create_order) أو استلام طلب كموصّل (driver_claim_order) — أعلى
--    قيمة حماية فورية بأقل تدخّل. حجب الدخول الكامل (شاشة "حسابك
--    موقوف" فـ الواجهات الثلاث) مؤجَّل صراحةً لمرحلة لاحقة منفصلة —
--    يُذكَر هذا بوضوح فـ التقرير النهائي، لا يُدَّعى أنه منجَز.
--
-- 5) كل قرار آلي مسجَّل ضمنيًا داخل fraud_cases نفسه (نفس فلسفة Wallet
--    Ledger سابقًا: السجل نفسه هو التوثيق) — والإجراءات اليدوية
--    (admin_log_fraud_violation، admin_set_suspension) تُسجَّل أيضًا فـ
--    admin_activity_log الموجودة (users لديها trigger مرتبط أصلًا منذ
--    20260821050000، fraud_cases تُربَط أدناه بنفس الدالة العامة).
-- ============================================================

alter table users add column is_suspended boolean not null default false;
alter table users add column suspended_at timestamptz;

comment on column users.is_suspended is 'حساب موقوف بقرار إداري (يدوي أو تلقائي عبر تجاوز حدّ المخالفات فـ fraud_cases) — يمنع اليوم تحديدًا إنشاء طلب جديد (create_order) واستلام طلب كموصّل (driver_claim_order). لا يمنع بعد تسجيل الدخول نفسه أو القراءة العادية — enforcement أوسع مؤجَّل.';

create table fraud_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id),
  role text not null check (role in ('customer', 'merchant', 'driver')),
  violation_type text not null,
  violation_count integer not null default 1,
  severity text not null default 'low' check (severity in ('low', 'medium', 'high')),
  reason text,
  status text not null default 'open' check (status in ('open', 'warning', 'suspended', 'resolved')),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- حالة واحدة "حيّة" لكل (مستخدم، نوع مخالفة) — التكرار يزيد
  -- violation_count فـ نفس الصف بدل صفّ جديد لكل مرّة (يطابق حرفيًا
  -- بنية fraud_cases الموصوفة فـ الطلب: عدّاد على نفس الحالة، لا سجل
  -- كل حادثة منفصلة).
  constraint fraud_cases_user_violation_unique unique (user_id, violation_type)
);

comment on table fraud_cases is 'حالات المخالفات/المخاطر لكل مستخدم — صف واحد لكل (مستخدم، نوع مخالفة)، violation_count يتزايد مع التكرار. القرار الآلي (warning/suspended) يقارن مجموع violation_count عبر كل حالات نفس المستخدم بحدَّي settings.fraud_warning_threshold/fraud_suspension_threshold القابلين للتعديل من الإدارة.';

create index fraud_cases_user_id_idx on fraud_cases (user_id);

alter table fraud_cases enable row level security;

-- قراءة إدارية فقط اليوم — لا Policy لعرض المستخدم مخالفاته الخاصة
-- (قرار متعمَّد: كشف عدّاد المخالفات للمستخدم نفسه قد يسهّل التحايل
-- عليه، ولم يُطلَب صراحةً فـ المواصفة).
create policy "fraud_cases_select_admin"
  on fraud_cases for select
  using (public.has_capability('fraud.view'));

-- لا Policy لـ insert/update/delete لأي طرف — الكتابة حصرًا عبر
-- log_fraud_violation_internal (يستدعيها إما admin_log_fraud_violation
-- أو Trigger الرصد التلقائي أدناه).

create trigger log_fraud_cases_admin_activity
  after insert or update on fraud_cases
  for each row execute function public.log_admin_activity();

-- ============================================================
-- log_fraud_violation_internal: المنطق الفعلي (تسجيل/تصعيد/إيقاف) —
-- دالة داخلية عمدًا، غير قابلة للاستدعاء مباشرة من أي عميل (نُزيل صلاحية
-- EXECUTE من authenticated/anon أدناه) لأنها لا تتحقّق من أي صلاحية
-- بنفسها — تثق بالفاعل الذي استدعاها (admin_log_fraud_violation الذي
-- يتحقّق هو من fraud.manage، أو Trigger النظام التلقائي). استدعاء
-- SECURITY DEFINER لدالة أخرى يُنفَّذ بصلاحية المالك (postgres) بغضّ
-- النظر عن REVOKE أدناه — هذا هو الفرق العملي بين "داخلي" و"عام".
-- ============================================================

create function public.log_fraud_violation_internal(p_user_id uuid, p_role text, p_violation_type text, p_reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_total_violations integer;
  v_warning_threshold integer;
  v_suspension_threshold integer;
  v_new_status text;
begin
  insert into fraud_cases (user_id, role, violation_type, violation_count, reason)
  values (p_user_id, p_role, p_violation_type, 1, p_reason)
  on conflict (user_id, violation_type) do update
    set violation_count = fraud_cases.violation_count + 1,
        reason = excluded.reason,
        updated_at = now();

  select coalesce(sum(violation_count), 0) into v_total_violations
  from fraud_cases where user_id = p_user_id;

  select value::integer into v_warning_threshold
  from settings where key = 'fraud_warning_threshold';
  select value::integer into v_suspension_threshold
  from settings where key = 'fraud_suspension_threshold';

  if v_total_violations >= coalesce(v_suspension_threshold, 999999) then
    v_new_status := 'suspended';
    update users set is_suspended = true, suspended_at = now() where id = p_user_id;
  elsif v_total_violations >= coalesce(v_warning_threshold, 999999) then
    v_new_status := 'warning';
  else
    v_new_status := 'open';
  end if;

  -- كل حالات هذا المستخدم تعكس نفس القرار الإجمالي (Warning/Suspended
  -- مبنيّان على المجموع الكلي، لا حالة فردية) — إلا الحالات المحلولة
  -- (resolved) يدويًا من الإدارة سابقًا، تبقى كما تركها الأدمن.
  update fraud_cases
  set status = v_new_status
  where user_id = p_user_id and status <> 'resolved';
end;
$$;

comment on function public.log_fraud_violation_internal is 'دالة داخلية فقط — راجع تعليق REVOKE أدناه. المنطق: مجموع violation_count عبر كل حالات المستخدم يُقارَن بحدَّي settings القابلين للتعديل، الإيقاف عمود users.is_suspended.';

revoke execute on function public.log_fraud_violation_internal(uuid, text, text, text) from public, anon, authenticated;

-- ============================================================
-- admin_log_fraud_violation: المدخل الوحيد المتاح للإدارة لتسجيل
-- مخالفة يدويًا (كل الأنواع غير القابلة للرصد الآلي).
-- ============================================================

create function public.admin_log_fraud_violation(p_user_id uuid, p_role text, p_violation_type text, p_reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.has_capability('fraud.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة المخالفات';
  end if;

  if p_role not in ('customer', 'merchant', 'driver') then
    raise exception 'دور غير معروف: %', p_role;
  end if;

  if not exists (select 1 from users where id = p_user_id) then
    raise exception 'المستخدم غير موجود';
  end if;

  perform public.log_fraud_violation_internal(p_user_id, p_role, p_violation_type, p_reason);
end;
$$;

comment on function public.admin_log_fraud_violation is 'تسجيل مخالفة يدويًا من الإدارة — لأي نوع (بما فيها الأنواع غير القابلة للرصد الآلي مثل "محاولة تنفيذ الطلب خارج النظام").';

-- ============================================================
-- admin_set_suspension: تجاوز يدوي مباشر (إيقاف أو رفع إيقاف) بمعزل عن
-- عدّاد المخالفات — يبقى متاحًا حتى لو لم تُسجَّل أي مخالفة بعد (حالة
-- طارئة)، أو لإلغاء إيقاف تلقائي بعد مراجعة الإدارة للحالة.
-- ============================================================

create function public.admin_set_suspension(p_user_id uuid, p_suspended boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.has_capability('fraud.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة المخالفات';
  end if;

  update users
  set is_suspended = p_suspended,
      suspended_at = case when p_suspended then now() else null end
  where id = p_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;
end;
$$;

comment on function public.admin_set_suspension is 'إيقاف أو رفع إيقاف حساب يدويًا من الإدارة، بمعزل عن عدّاد fraud_cases التلقائي — مُسجَّل تلقائيًا فـ admin_activity_log (trigger log_users_admin_activity الموجود أصلًا على users).';

-- ============================================================
-- الرصد التلقائي الوحيد فـ هذه المرحلة: العميل يلغي طلبه الخاص وهو
-- pending. نميّز "ألغاه العميل نفسه" عن "ألغته الإدارة نيابة عنه" عبر
-- auth.uid() = customer_id (نفس أسلوب التمييز المُثبَت فـ باقي المشروع).
-- ============================================================

create function public.detect_customer_order_cancellation()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status = 'pending'
     and new.customer_id = auth.uid() then
    perform public.log_fraud_violation_internal(
      new.customer_id, 'customer', 'order_cancellation',
      'إلغاء الطلب رقم ' || new.id::text
    );
  end if;
  return new;
end;
$$;

comment on function public.detect_customer_order_cancellation is 'رصد تلقائي لإلغاء العميل طلبه الخاص وهو pending — إلغاء الإدارة أو التاجر (رفض) لا يُحتسَب هنا (auth.uid() مختلف عن customer_id فـ تلك الحالات).';

create trigger orders_detect_customer_cancellation
  after update on orders
  for each row execute function public.detect_customer_order_cancellation();

-- ============================================================
-- حدود Warning/Suspension الافتراضية — قابلة للتعديل فورًا من صفحة
-- الإعدادات الحالية (admin_set_setting) بلا أي تعديل كود إضافي.
-- ============================================================

insert into settings (key, value) values
  ('fraud_warning_threshold', '3'),
  ('fraud_suspension_threshold', '5')
on conflict (key) do nothing;

-- ============================================================
-- تطبيق الإيقاف الفعلي: create_order وdriver_claim_order — نفس الجسم
-- الحالي حرفيًا فـ كل منهما، فقط سطر تحقّق واحد يُضاف فـ البداية.
-- ============================================================

create or replace function public.create_order(
  p_merchant_id uuid,
  p_address_id uuid,
  p_items jsonb
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_subtotal numeric(10, 2) := 0;
  v_commission_rate numeric(5, 2);
  v_platform_commission numeric(10, 2);
  v_merchant_amount numeric(10, 2);
  v_order_id uuid;
  v_item jsonb;
  v_product record;
  v_quantity integer;
  v_line_subtotal numeric(10, 2);
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإنشاء طلب';
  end if;

  if exists (select 1 from users where id = v_customer_id and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if not exists (
    select 1 from merchants where id = p_merchant_id and status = 'approved'
  ) then
    raise exception 'المحل غير موجود أو غير موافَق عليه بعد';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = v_customer_id
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'لا يمكن إنشاء طلب فارغ';
  end if;

  insert into orders (
    customer_id, merchant_id, address_id, status,
    subtotal, commission_rate, platform_commission_amount,
    merchant_amount, delivery_fee, total_amount
  ) values (
    v_customer_id, p_merchant_id, p_address_id, 'pending',
    0, 0, 0, 0, 0, 0
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, price, is_active, merchant_id into v_product
    from products
    where id = (v_item ->> 'product_id')::uuid;

    if v_product.id is null then
      raise exception 'منتج غير موجود';
    end if;

    if v_product.merchant_id <> p_merchant_id then
      raise exception 'كل منتجات الطلب يجب أن تكون من نفس المحل';
    end if;

    if not v_product.is_active then
      raise exception 'أحد المنتجات لم يعد متوفرًا حاليًا';
    end if;

    v_quantity := (v_item ->> 'quantity')::integer;
    v_line_subtotal := v_product.price * v_quantity;

    insert into order_items (order_id, product_id, quantity, unit_price, subtotal)
    values (v_order_id, v_product.id, v_quantity, v_product.price, v_line_subtotal);

    v_subtotal := v_subtotal + v_line_subtotal;
  end loop;

  select commission_rate_override into v_commission_rate
  from merchants where id = p_merchant_id;

  if v_commission_rate is null then
    select value::numeric into v_commission_rate
    from settings where key = 'platform_commission_rate';
  end if;

  v_platform_commission := round(v_subtotal * v_commission_rate / 100, 2);
  v_merchant_amount := v_subtotal - v_platform_commission;

  update orders set
    subtotal = v_subtotal,
    commission_rate = v_commission_rate,
    platform_commission_amount = v_platform_commission,
    merchant_amount = v_merchant_amount,
    delivery_fee = 0,
    total_amount = v_subtotal
  where id = v_order_id;

  return v_order_id;
end;
$$;

comment on function public.create_order is 'الطريقة الآمنة الوحيدة لإنشاء طلب - تحسب كل الأرقام من قاعدة البيانات، لا تثق بأي رقم من العميل. نسبة العمولة: استثناء التاجر إن وُجد، وإلا الإعداد المركزي العام. يرفض الحسابات الموقوفة (is_suspended) قبل أي شيء آخر.';

create or replace function public.driver_claim_order(p_order_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  if exists (select 1 from users where id = auth.uid() and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  select id into v_driver_id from drivers
  where user_id = auth.uid() and status = 'approved';

  if v_driver_id is null then
    raise exception 'حساب الموصّل غير موجود أو غير موافَق عليه بعد';
  end if;

  update orders
  set driver_id = v_driver_id
  where id = p_order_id
    and status = 'ready_for_pickup'
    and driver_id is null;

  if not found then
    raise exception 'هذا الطلب لم يعد متاحًا (استلمه موصّل آخر أو تغيّرت حالته)';
  end if;
end;
$$;

comment on function public.driver_claim_order is 'شرط driver_id is null داخل نفس جملة update يمنع بنيويًا استلام موصّلَين لنفس الطلب في نفس اللحظة — قفل Postgres على مستوى الصفّ يضمن فوز معاملة واحدة فقط، والخاسر يحصل على استثناء نظيف. يرفض الحسابات الموقوفة قبل أي شيء آخر.';
