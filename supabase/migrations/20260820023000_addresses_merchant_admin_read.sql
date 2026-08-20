-- ============================================================
-- Migration: السماح للتاجر (ولاحقًا Admin) بقراءة عنوان التوصيل
-- الخاص بطلب يملكه، لتنفيذ الطلب فعليًا (لوحة التاجر - PHASE 7).
--
-- المشكلة: عند إنشاء جدول addresses (Phase 1) كانت القاعدة الوحيدة
-- "المستخدم يرى فقط عنوانه الخاص" — هذا صحيح للعميل، لكنه يمنع التاجر
-- من رؤية عنوان توصيل طلب هو صاحبه فعليًا، رغم أن orders.address_id
-- يشير له. اكتُشفت هذه الثغرة الوظيفية أثناء بناء صفحة تفاصيل الطلب
-- في لوحة التاجر.
-- ============================================================

-- Policy: التاجر يقرأ فقط عنوان طلب يخص محله هو (وليس أي عنوان آخر)
create policy "addresses_select_merchant_via_orders"
  on addresses for select
  using (
    exists (
      select 1 from orders o
      join merchants m on m.id = o.merchant_id
      where o.address_id = addresses.id and m.owner_user_id = auth.uid()
    )
  );

-- Policy: Admin يقرأ كل العناوين (ضروري لإدارة التوصيل يدويًا في V1)
create policy "addresses_select_admin"
  on addresses for select
  using (
    exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin')
  );
