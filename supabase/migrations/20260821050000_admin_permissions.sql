-- ============================================================
-- Migration: نظام صلاحيات إدارة حقيقي (Super Admin / Manager /
-- Ads Manager) بدل دور "admin" واحد يملك كل شيء أو لا شيء.
--
-- الأدوار الثلاثة داخل لوحة الإدارة (فوق customer/merchant الحاليَّين):
--   • admin        → Super Admin: صلاحية كاملة (كما كانت is_admin() دائمًا).
--   • manager      → إدارة المحلات + تصنيفات المحلات + تصنيفات المنتجات
--                     + الإعلانات (كل شيء ما عدا الهوية/الإعدادات/الفريق).
--   • ads_manager   → إدارة الإعلانات وإحصائياتها فقط.
-- "Store Manager" من الطلب الأصلي هو فعليًا التاجر (owner_user_id على
-- merchants) — موجود أصلًا كنظام منفصل بالكامل (Merchant Dashboard)،
-- وليس دورًا داخل لوحة الإدارة، فلا حاجة لإعادة بنائه هنا.
--
-- ============================================================
-- ثغرة أمنية حقيقية اكتُشفت ووُجب إغلاقها أثناء هذا العمل:
-- سياسة "users_update_own" (منذ Phase 1) تسمح لأي مستخدم بتعديل صفّه
-- الخاص كاملًا — بما فيه عمود role نفسه! أي مستخدم عادي كان يقدر
-- نظريًا يرفع نفسه لـ admin بنداء مباشر:
--   supabase.from('users').update({role: 'admin'}).eq('id', auth.uid())
-- لم يكن هناك أي Trigger يحمي هذا العمود (خلافًا لـ status على
-- merchants الذي كان محميًا منذ البداية). الحماية أدناه (protect_
-- user_role) تسدّ هذه الثغرة بنفس نمط الحماية المستخدَم مسبقًا.
-- ============================================================

alter table users drop constraint if exists users_role_check;
alter table users add constraint users_role_check
  check (role in ('customer', 'merchant', 'admin', 'manager', 'ads_manager'));

-- ---------- إغلاق ثغرة تعديل role الذاتي ----------

create function public.protect_user_role()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.role() <> 'service_role'
     and not exists (select 1 from users where id = auth.uid() and role = 'admin') then
    new.role := old.role;
  end if;
  return new;
end;
$$;

comment on function public.protect_user_role is 'يمنع أي مستخدم من تغيير دوره (role) لنفسه — فقط Super Admin (role=admin) أو service_role يقدر. يسدّ ثغرة كانت موجودة منذ إنشاء جدول users (راجع تعليق الملف).';

create trigger users_protect_role
  before update on users
  for each row execute function public.protect_user_role();

-- ---------- دوال الصلاحيات المتدرّجة (نفس نمط is_admin()) ----------

create function public.can_manage_stores()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from users where id = auth.uid() and role in ('admin', 'manager')
  );
$$;

create function public.can_manage_ads()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from users
    where id = auth.uid() and role in ('admin', 'manager', 'ads_manager')
  );
$$;

comment on function public.can_manage_stores is 'صحيح لـ Super Admin وManager — يتحكّم بمن يدير المحلات/تصنيفاتها/تصنيفات المنتجات.';
comment on function public.can_manage_ads is 'صحيح لـ Super Admin وManager وAds Manager — يتحكّم بمن يدير الإعلانات.';

-- ---------- الطريقة الآمنة الوحيدة لتغيير دور مستخدم ----------
-- تُستخدَم من صفحة "الفريق" في لوحة الإدارة، بدل تعديل الجدول مباشرة.
-- الحماية الفعلية مزدوجة: هذا الفحص هنا + trigger الحماية أعلاه (حتى
-- لو نُودِيت هذه الدالة من سياق غير متوقَّع).

create function public.admin_set_user_role(p_user_id uuid, p_new_role text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (select 1 from users where id = auth.uid() and role = 'admin') then
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

-- ---------- توسيع الصلاحيات الحالية لتشمل Manager/Ads Manager ----------

-- merchants: الموافقة/الرفض/التصنيف/التمييز أصبحت متاحة لـ Manager أيضًا
create or replace function public.protect_merchant_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_manage_stores() then
    if new.status is distinct from old.status then
      new.status := old.status;
    end if;
    if new.category_id is distinct from old.category_id then
      new.category_id := old.category_id;
    end if;
    if new.is_featured is distinct from old.is_featured then
      new.is_featured := old.is_featured;
    end if;
    if new.orders_count is distinct from old.orders_count then
      new.orders_count := old.orders_count;
    end if;
  end if;

  return new;
end;
$$;

drop policy if exists "merchants_select_admin" on merchants;
create policy "merchants_select_admin"
  on merchants for select
  using (public.can_manage_stores());

drop policy if exists "merchants_update_admin" on merchants;
create policy "merchants_update_admin"
  on merchants for update
  using (public.can_manage_stores());

-- merchant_categories: تصنيفات المحلات
drop policy if exists "merchant_categories_admin_all" on merchant_categories;
create policy "merchant_categories_admin_all"
  on merchant_categories for all
  using (public.can_manage_stores())
  with check (public.can_manage_stores());

-- categories: تصنيفات المنتجات
drop policy if exists "categories_admin_write" on categories;
create policy "categories_admin_write"
  on categories for insert
  with check (public.can_manage_stores());

drop policy if exists "categories_admin_update" on categories;
create policy "categories_admin_update"
  on categories for update
  using (public.can_manage_stores());

drop policy if exists "categories_admin_delete" on categories;
create policy "categories_admin_delete"
  on categories for delete
  using (public.can_manage_stores());

-- products: إخفاء منتج مخالف
drop policy if exists "products_update_admin" on products;
create policy "products_update_admin"
  on products for update
  using (public.can_manage_stores());

-- users: Manager يحتاج رؤية بيانات مالك المحل عند إدارة المحلات
drop policy if exists "users_select_admin" on users;
create policy "users_select_admin"
  on users for select
  using (public.can_manage_stores());

-- advertisements: Manager وAds Manager معًا
drop policy if exists "advertisements_admin_all" on advertisements;
create policy "advertisements_admin_all"
  on advertisements for all
  using (public.can_manage_ads())
  with check (public.can_manage_ads());

-- ---------- سجل النشاطات: يلتقط الآن كل أدوار لوحة الإدارة الثلاثة ----------
create or replace function public.log_admin_activity()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_admin_name text;
  v_action text;
  v_record_id text;
  v_changes jsonb;
begin
  if not exists (
    select 1 from users
    where id = v_admin_id and role in ('admin', 'manager', 'ads_manager')
  ) then
    return coalesce(new, old);
  end if;

  select full_name into v_admin_name from users where id = v_admin_id;

  if TG_OP = 'INSERT' then
    v_action := 'إنشاء';
    v_record_id := new.id::text;
    v_changes := to_jsonb(new);
  elsif TG_OP = 'UPDATE' then
    v_action := 'تعديل';
    v_record_id := new.id::text;
    v_changes := jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new));
  elsif TG_OP = 'DELETE' then
    v_action := 'حذف';
    v_record_id := old.id::text;
    v_changes := to_jsonb(old);
  end if;

  insert into admin_activity_log (admin_id, admin_name, action, table_name, record_id, changes)
  values (v_admin_id, coalesce(v_admin_name, ''), v_action, TG_TABLE_NAME, v_record_id, v_changes);

  return coalesce(new, old);
end;
$$;

-- تغيير دور مستخدم (منح/سحب صلاحية إدارية) إجراء حسّاس يستحق سجلًا —
-- لم يكن على users أي Trigger سجل من قبل. الفلترة في log_admin_activity
-- نفسها تكفي لعدم تسجيل تعديل عميل عادي لاسمه/هاتفه الخاص (فاعل بلا
-- دور إداري لا يُسجَّل له شيء أصلًا).
create trigger log_users_admin_activity
  after update on users
  for each row execute function public.log_admin_activity();
