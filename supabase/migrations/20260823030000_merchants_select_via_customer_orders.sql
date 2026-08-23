-- خطأ حقيقي اكتُشف أثناء اختبار حي على جهاز حقيقي: شاشة "طلباتي" في
-- تطبيق الزبون كانت تتعطّل (type 'Null' is not a subtype of type
-- 'Map<String, dynamic>') لأن استعلامها يضمّ merchants(store_name) —
-- وسياسات RLS الحالية على merchants تسمح فقط بقراءة محل "approved"
-- علنيًا، أو محل المالك نفسه، أو الإدارة. إذا كان محل طلب سابق للعميل
-- لم يعد "approved" حاليًا (رُفض/عُلِّق لاحقًا)، لا توجد أي سياسة تسمح
-- للعميل برؤية اسم ذلك المحل — الانضمام (join) يرجع null ويكسر التطبيق،
-- رغم أن العميل يملك صلاحية رؤية طلبه نفسه فعليًا عبر orders_select_own_customer.
--
-- محاولتان سابقتان فشلتا حيًا (كلتاهما بخطأ 42P17: infinite recursion
-- detected in policy for relation "merchants"):
--   1) exists (select 1 from orders where ...) مباشرة داخل سياسة
--      merchants — لأن orders_select_own_merchant تستعلم بدورها عن
--      merchants، فتتكوّن حلقة.
--   2) دالة security definer عادية (بدون تعطيل RLS صراحة) — تبيّن
--      حيًا أنها غير كافية وحدها هنا: Postgres يُقيِّم كل سياسات
--      orders المُطبَّقة (بما فيها orders_select_own_merchant
--      الراجعة لـ merchants) كتعبير OR واحد مجمَّع، حتى لو كانت سياسة
--      أخرى (orders_select_own_customer) ستكفي وحدها منطقيًا — لا
--      ضمانة أن التقييم يتوقف عند أول سياسة صحيحة. is_admin() نجحت
--      سابقًا فقط لأن استعلامها الداخلي (عن صفّ المستخدم نفسه) يطابق
--      شرط users_select_own مباشرة بلا أي حلقة أصلًا، وليس لأن
--      security definer تُعطِّل RLS تلقائيًا.
--
-- الحل الحاسم: تعطيل فحص RLS صراحة داخل الدالة (set row_security =
-- off) — يضمن تجاوز كل سياسات orders تمامًا لهذا الاستعلام الداخلي
-- تحديدًا، بغضّ النظر عن أي افتراضات حول ملكية الجداول.
drop policy if exists "merchants_select_via_customer_orders" on merchants;
drop policy if exists "merchants_select_via_driver_orders" on merchants;
drop function if exists public.customer_ordered_from_merchant(uuid);
drop function if exists public.driver_has_order_for_merchant(uuid);

create function public.customer_ordered_from_merchant(p_merchant_id uuid)
returns boolean
language sql
security definer
set search_path = public
set row_security = off
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
-- طلبه المُعيَّن إن لم يكن "approved" حاليًا. نفس حل تعطيل RLS صراحة.
create function public.driver_has_order_for_merchant(p_merchant_id uuid)
returns boolean
language sql
security definer
set search_path = public
set row_security = off
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
