-- خطأ حقيقي اكتُشف أثناء اختبار حي على جهاز حقيقي: شاشة "طلباتي" في
-- تطبيق الزبون كانت تتعطّل (type 'Null' is not a subtype of type
-- 'Map<String, dynamic>') لأن استعلامها يضمّ merchants(store_name) —
-- وسياسات RLS الحالية على merchants تسمح فقط بقراءة محل "approved"
-- علنيًا، أو محل المالك نفسه، أو الإدارة. إذا كان محل طلب سابق للعميل
-- لم يعد "approved" حاليًا (رُفض/عُلِّق لاحقًا)، لا توجد أي سياسة تسمح
-- للعميل برؤية اسم ذلك المحل — الانضمام (join) يرجع null ويكسر التطبيق،
-- رغم أن العميل يملك صلاحية رؤية طلبه نفسه فعليًا عبر orders_select_own_customer.
--
-- الحل: نفس نمط addresses_select_merchant_via_orders/addresses_select_driver_via_orders
-- الموجودتين أصلًا — عميل يملك طلبًا حقيقيًا مع محل يقدر يرى اسم ذلك
-- المحل دائمًا، بغض النظر عن حالته الحالية.
create policy "merchants_select_via_customer_orders"
  on merchants for select
  using (
    exists (
      select 1 from orders o
      where o.merchant_id = merchants.id and o.customer_id = auth.uid()
    )
  );

-- نفس الثغرة بالضبط من جهة الموصّل — job_order.dart في driver_app
-- يضمّ merchants(...) أيضًا، ولا توجد أي سياسة تسمح للموصّل برؤية محل
-- طلبه المُعيَّن إن لم يكن "approved" حاليًا.
create policy "merchants_select_via_driver_orders"
  on merchants for select
  using (
    exists (
      select 1 from orders o
      join drivers d on d.id = o.driver_id
      where o.merchant_id = merchants.id and d.user_id = auth.uid()
    )
  );
