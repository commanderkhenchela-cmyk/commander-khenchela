-- خطأ حقيقي اكتُشف أثناء اختبار حي على جهاز حقيقي: شاشة "طلباتي" في
-- تطبيق الزبون كانت تتعطّل (type 'Null' is not a subtype of type
-- 'Map<String, dynamic>') لأن استعلامها يضمّ merchants(store_name) —
-- وسياسات RLS الحالية على merchants تسمح فقط بقراءة محل "approved"
-- علنيًا، أو محل المالك نفسه، أو الإدارة. إذا كان محل طلب سابق للعميل
-- لم يعد "approved" حاليًا (رُفض/عُلِّق لاحقًا)، لا توجد أي سياسة تسمح
-- للعميل برؤية اسم ذلك المحل — الانضمام (join) يرجع null ويكسر التطبيق،
-- رغم أن العميل يملك صلاحية رؤية طلبه نفسه فعليًا عبر orders_select_own_customer.
--
-- محاولة أولى بسيطة (exists (select 1 from orders where ...)) مباشرة
-- داخل سياسة merchants فشلت بخطأ حي حقيقي آخر: "infinite recursion
-- detected in policy for relation 'merchants' (42P17)" — لأن سياسات
-- orders نفسها (orders_select_own_merchant) تستعلم عن merchants،
-- فتتكوّن حلقة: merchants → orders → merchants → ... بلا نهاية. نفس
-- فئة الخطأ بالضبط التي عولجت سابقًا في هذا المشروع
-- (20260820040000_fix_admin_rls_recursion.sql) بنفس الحل: دالة
-- security definer تكسر الحلقة (تُنفَّذ بصلاحية مالكها فتتجاوز RLS
-- الداخلية بدل تشغيل سياسات orders من جديد).
-- الإصدار الأول من هذا الـ Migration (بدون دالة كاسرة للحلقة) طُبِّق
-- حيًا وفشل بخطأ 42P17 — نحذف تلك السياسة الخاطئة أولاً قبل إعادة
-- الإنشاء الصحيح، حتى يبقى هذا الملف قابلاً للتطبيق من الصفر أيضًا.
drop policy if exists "merchants_select_via_customer_orders" on merchants;
drop policy if exists "merchants_select_via_driver_orders" on merchants;

create or replace function public.customer_ordered_from_merchant(p_merchant_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from orders
    where merchant_id = p_merchant_id and customer_id = auth.uid()
  );
$$;

create policy "merchants_select_via_customer_orders"
  on merchants for select
  using (public.customer_ordered_from_merchant(id));

-- نفس الثغرة بالضبط من جهة الموصّل — job_order.dart في driver_app
-- يضمّ merchants(...) أيضًا، ولا توجد أي سياسة تسمح للموصّل برؤية محل
-- طلبه المُعيَّن إن لم يكن "approved" حاليًا. نفس حل كسر الحلقة.
create or replace function public.driver_has_order_for_merchant(p_merchant_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from orders o
    join drivers d on d.id = o.driver_id
    where o.merchant_id = p_merchant_id and d.user_id = auth.uid()
  );
$$;

create policy "merchants_select_via_driver_orders"
  on merchants for select
  using (public.driver_has_order_for_merchant(id));
