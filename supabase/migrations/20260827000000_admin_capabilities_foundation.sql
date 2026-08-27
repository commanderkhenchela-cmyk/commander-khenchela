-- ============================================================
-- Migration: PHASE — ADMIN CONTROL CENTER FOUNDATION (1/2)
-- طبقة Capabilities قابلة للتوسّع فوق RBAC الحالي.
--
-- المشكلة التي تُحلّ هنا: الصلاحيات اليوم = دالة SQL منفصلة لكل نطاق
-- (is_admin, can_manage_stores, can_manage_ads)، كل واحدة بقائمة أدوار
-- Hardcoded داخلها. هذا يعمل لـ3 نطاقات، لكن لا يتوسّع نظيفًا لـ12+
-- Capability (merchant.approve, order.cancel, wallet.topup...) بلا
-- كتابة عشرات الدوال شبه المتطابقة.
--
-- الحل: جدول بيانات واحد (role → capability) + دالة تحقّق عامة واحدة
-- (has_capability). إضافة دور أو صلاحية جديدة لاحقًا = صف بيانات جديد،
-- لا دالة SQL جديدة ولا RLS Policy جديدة لكل ميزة.
--
-- ============================================================
-- مهم جدًا — هذا الملف لا يغيّر أي سلوك حالي:
-- • is_admin() / can_manage_stores() / can_manage_ads() تبقى كما هي
--   حرفيًا، وكل RLS Policy تستدعيها تبقى كما هي — صفر خطر على أي شيء
--   يعمل اليوم.
-- • الصفوف المُدرَجة أدناه (seed) توثّق فقط ما هو صحيح فعليًا اليوم
--   (تحقَّقتُ من كل RLS Policy/صفحة Next.js قبل كتابة كل صف) — لا
--   صلاحية جديدة تُمنَح لأي دور بهذا الملف.
-- • wallet.*/fraud.*/merchant.suspend/driver.suspend/order.cancel لا
--   يتحقّق منها أي كود اليوم (لا Wallet ولا Fraud ولا Suspension
--   مُنفَّذة) — صفوف بيانات خاملة (Inert) تُحضِّر الأرضية فقط، بلا أي
--   أثر تشغيلي، تمامًا كما طُلِب صراحةً ("لا تنفّذ Wallet/Fraud الآن،
--   لكن تأكد أن Architecture قابلة لاستيعابها لاحقًا").
-- ============================================================

create table role_capabilities (
  role text not null,
  capability text not null,
  created_at timestamptz not null default now(),
  primary key (role, capability)
);

comment on table role_capabilities is 'خريطة دور→صلاحية (Capability) — مصدر الحقيقة الوحيد لصلاحيات لوحة الإدارة. يُستهلَك من Postgres (has_capability()) ومن Next.js (admin-context.ts) معًا، بدل تكرار نفس القاعدة في مكانين كما كان الحال سابقًا.';

alter table role_capabilities enable row level security;

-- بيانات وصفية عامة غير حسّاسة (لا تكشف شيئًا عن مستخدم بعينه) — القراءة
-- متاحة لأي مستخدم مسجَّل دخوله فقط (لا لعميل مجهول)، تمامًا مثل احتياج
-- Next.js لمعرفة صلاحيات المستخدم الحالي بأمان.
create policy "role_capabilities_select_authenticated"
  on role_capabilities for select
  using (auth.role() = 'authenticated');

-- لا Policy لـ insert/update/delete — هذا الجدول بيانات تهيئة (Config)
-- تُدار حصرًا عبر migrations، وليست بيانات تشغيلية يعدّلها أي تطبيق.

create function public.has_capability(p_capability text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from users u
    join role_capabilities rc on rc.role = u.role
    where u.id = auth.uid() and rc.capability = p_capability
  );
$$;

comment on function public.has_capability is 'الدالة العامة الوحيدة للتحقّق من صلاحية محدَّدة (resource.action) — تحلّ محلّ الحاجة لكتابة can_manage_X() جديدة لكل ميزة مستقبلية. لا تُستخدَم بعد في أي RLS/RPC حالية (is_admin/can_manage_stores/can_manage_ads تبقى الحارس الفعلي اليوم) — جاهزة للاستخدام في ميزات جديدة (Wallet، Fraud) عند بنائها لاحقًا.';

-- ============================================================
-- Seed: التوثيق الدقيق لما هو صحيح فعليًا اليوم في RLS + صفحات
-- admin-dashboard (تحقَّقتُ من كل سطر أدناه في الكود قبل كتابته):
--   admin        → Super Admin: كل شيء (RLS: is_admin() يفتح كل شيء).
--   manager      → can_manage_stores(): محلات/موصّلون/خدمات فقط
--                   (لا orders — orders_select_admin تتحقّق role='admin'
--                   حصرًا، وصفحة /dashboard/orders محروسة بـ isSuperAdmin
--                   فقط في layout.tsx — لا وصول لـ manager اليوم).
--   ads_manager  → can_manage_ads(): إعلانات فقط.
--   notification.view → متاحة للثلاثة أدوار اليوم (رابط الإشعارات في
--                   layout.tsx بلا أي شرط صلاحية إطلاقًا).
-- ============================================================

insert into role_capabilities (role, capability) values
  -- admin: صلاحية كاملة (بما فيها صلاحيات مستقبلية خاملة اليوم)
  ('admin', 'merchant.view'),
  ('admin', 'merchant.manage'),
  ('admin', 'merchant.approve'),
  ('admin', 'merchant.suspend'),
  ('admin', 'driver.view'),
  ('admin', 'driver.manage'),
  ('admin', 'driver.approve'),
  ('admin', 'driver.suspend'),
  ('admin', 'order.view'),
  ('admin', 'order.manage'),
  ('admin', 'order.cancel'),
  ('admin', 'service.view'),
  ('admin', 'service.manage'),
  ('admin', 'advertisement.view'),
  ('admin', 'advertisement.manage'),
  ('admin', 'notification.view'),
  ('admin', 'notification.manage'),
  ('admin', 'settings.view'),
  ('admin', 'settings.manage'),
  ('admin', 'reports.view'),
  ('admin', 'wallet.view'),
  ('admin', 'wallet.manage'),
  ('admin', 'fraud.view'),
  ('admin', 'fraud.manage'),
  ('admin', 'support.manage'),

  -- manager: نفس نطاق can_manage_stores() الفعلي اليوم بالضبط
  ('manager', 'merchant.view'),
  ('manager', 'merchant.manage'),
  ('manager', 'merchant.approve'),
  ('manager', 'driver.view'),
  ('manager', 'driver.manage'),
  ('manager', 'driver.approve'),
  ('manager', 'service.view'),
  ('manager', 'service.manage'),
  ('manager', 'advertisement.view'),
  ('manager', 'advertisement.manage'),
  ('manager', 'notification.view'),

  -- ads_manager: نفس نطاق can_manage_ads() الفعلي اليوم بالضبط
  ('ads_manager', 'advertisement.view'),
  ('ads_manager', 'advertisement.manage'),
  ('ads_manager', 'notification.view');

-- ============================================================
-- توحيد الفلسفة (بدون كسر السلوك): الدوال الأربع التالية كانت تكرّر
-- الشرط `role = 'admin'` يدويًا بدل استدعاء is_admin() الموجودة أصلًا
-- منذ migration 20260820040000. لا تغيير في المنطق إطلاقًا — نفس
-- الشرط بالضبط، فقط عبر دالة واحدة بدل تكراره حرفيًا 4 مرات.
-- ============================================================

create or replace function public.admin_set_delivery_fee(p_order_id uuid, p_fee numeric)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'هذا الإجراء متاح فقط للإدارة';
  end if;

  if p_fee < 0 then
    raise exception 'رسوم التوصيل لا يمكن أن تكون سالبة';
  end if;

  update orders
  set delivery_fee = p_fee,
      total_amount = subtotal + p_fee
  where id = p_order_id;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;
end;
$$;

create or replace function public.admin_get_settings()
returns table (key text, value text, updated_at timestamptz)
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'هذا الإجراء متاح فقط للإدارة';
  end if;

  return query select s.key, s.value, s.updated_at from settings s order by s.key;
end;
$$;

create or replace function public.admin_set_setting(p_key text, p_value text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'هذا الإجراء متاح فقط للإدارة';
  end if;

  insert into settings (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;

create or replace function public.admin_set_user_role(p_user_id uuid, p_new_role text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'تغيير الأدوار متاح فقط لـ Super Admin';
  end if;

  if p_new_role not in ('customer', 'merchant', 'admin', 'manager', 'ads_manager') then
    raise exception 'دور غير معروف: %', p_new_role;
  end if;

  update users set role = p_new_role where id = p_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;
end;
$$;
