-- ============================================================
-- Migration: إصلاح خطأ "infinite recursion detected in policy for
-- relation users" (42P17).
--
-- السبب: كل قواعد RLS الخاصة بـ Admin التي أضفناها في
-- 20260820023000 و20260820030000 تتحقق من الدور بشرط
--   exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin')
-- وهذا الشرط نفسه هو SELECT على جدول users، فيُعاد تطبيق RLS عليه من
-- جديد (بما فيها نفس الـ Policy)، فتتكرر العملية إلى ما لا نهاية —
-- Postgres يكتشف هذا ويرفض الاستعلام بدل التعليق للأبد.
--
-- الحل القياسي: دالة security definer منفصلة (تعمل بصلاحية مالكها
-- postgres، الذي يتجاوز RLS تلقائيًا — تمامًا كما تفعل create_order
-- وvalidate_order_status_transition بنجاح منذ Phase 6). نستبدل كل
-- الشروط المباشرة بنداء لهذه الدالة، فتُحسب مرة واحدة بدون أي RLS
-- على الاستعلام الداخلي.
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from users where id = auth.uid() and role = 'admin');
$$;

-- ---------- إعادة إنشاء كل Policy كانت تستخدم الشرط المباشر ----------

drop policy if exists "addresses_select_admin" on addresses;
create policy "addresses_select_admin"
  on addresses for select
  using (public.is_admin());

drop policy if exists "merchants_select_admin" on merchants;
create policy "merchants_select_admin"
  on merchants for select
  using (public.is_admin());

drop policy if exists "merchants_update_admin" on merchants;
create policy "merchants_update_admin"
  on merchants for update
  using (public.is_admin());

drop policy if exists "categories_admin_write" on categories;
create policy "categories_admin_write"
  on categories for insert
  with check (public.is_admin());

drop policy if exists "categories_admin_update" on categories;
create policy "categories_admin_update"
  on categories for update
  using (public.is_admin());

drop policy if exists "categories_admin_delete" on categories;
create policy "categories_admin_delete"
  on categories for delete
  using (public.is_admin());

drop policy if exists "orders_select_admin" on orders;
create policy "orders_select_admin"
  on orders for select
  using (public.is_admin());

drop policy if exists "orders_update_admin" on orders;
create policy "orders_update_admin"
  on orders for update
  using (public.is_admin());

drop policy if exists "order_items_select_admin" on order_items;
create policy "order_items_select_admin"
  on order_items for select
  using (public.is_admin());

drop policy if exists "order_status_history_select_admin" on order_status_history;
create policy "order_status_history_select_admin"
  on order_status_history for select
  using (public.is_admin());

drop policy if exists "users_select_admin" on users;
create policy "users_select_admin"
  on users for select
  using (public.is_admin());

drop policy if exists "products_update_admin" on products;
create policy "products_update_admin"
  on products for update
  using (public.is_admin());
