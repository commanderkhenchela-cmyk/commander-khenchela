-- ============================================================
-- Migration: صلاحيات Admin اللازمة للوحة تحكم الإدارة (PHASE 8)
--
-- فلسفة هذا الملف: كل الجداول أدناه كانت مبنية أصلًا لصلاحيتين فقط
-- (صاحب البيانات / الكل)، بدون أي مفهوم "Admin" حقيقي في RLS — الافتراض
-- كان أن كل عمل Admin سيمر عبر Service Role. لكن قرارنا المعماري
-- الموثّق في create_order (PHASE 6) هو: أي عملية DB بحتة (بدون نداء
-- خدمة خارجية) تُبنى كدالة Postgres بصلاحية security definer، تتحقق من
-- الدور بنفسها، بدل المرور بـ Service Role/Edge Function. هذا الملف يطبّق
-- نفس المبدأ على صلاحيات الإدارة: إما بتوسيع RLS بشرط "role = admin"
-- (قراءة، وكتابة محكومة أصلًا بـ trigger صارم كما في merchants/orders)،
-- أو بدالة RPC مخصّصة عند الحاجة لأمان إضافي (settings، تعديل رسوم التوصيل).
-- ============================================================

-- ---------- merchants: قراءة كل المحلات + الموافقة/الرفض ----------

create policy "merchants_select_admin"
  on merchants for select
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

create policy "merchants_update_admin"
  on merchants for update
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

-- إصلاح: protect_merchant_status كانت تسمح فقط لـ service_role بتغيير الحالة،
-- متجاهلة إمكانية وجود Admin حقيقي مسجّل دخول عبر auth.users. الآن تسمح للاثنين.
create or replace function public.protect_merchant_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status
     and auth.role() <> 'service_role'
     and not exists (select 1 from users where id = auth.uid() and role = 'admin') then
    new.status := old.status;
  end if;
  return new;
end;
$$;

-- ---------- categories: إدارة كاملة من Admin (لا أحد غيره يكتب هنا) ----------

create policy "categories_admin_write"
  on categories for insert
  with check (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

create policy "categories_admin_update"
  on categories for update
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

create policy "categories_admin_delete"
  on categories for delete
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

-- ---------- orders / order_items / order_status_history: رؤية كاملة لـ Admin ----------
-- (منطق أي انتقال حالة مسموح به لـ Admin محكوم أصلًا بـ
-- validate_order_status_transition — هذا فقط يفتح الوصول للجدول نفسه)

create policy "orders_select_admin"
  on orders for select
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

create policy "orders_update_admin"
  on orders for update
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

create policy "order_items_select_admin"
  on order_items for select
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

create policy "order_status_history_select_admin"
  on order_status_history for select
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

-- ---------- users: Admin يرى كل المستخدمين (مثلاً: بيانات مالك محل) ----------

create policy "users_select_admin"
  on users for select
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

-- ---------- products: Admin يقدر يخفي منتجًا مخالفًا (بدون حذف بيانات التاجر) ----------

create policy "products_update_admin"
  on products for update
  using (exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin'));

-- ============================================================
-- رسوم التوصيل: تُحدَّد يدويًا لكل طلب على حدة من طرف Admin (التوصيل نفسه
-- يدوي بالكامل في V1)، وليس رقمًا ثابتًا عامًا — لأن كل طلب قد يحتاج توصيلًا
-- بمسافة/تسعيرة مختلفة. الدالة أدناه تُحدّث delivery_fee وتعيد حساب
-- total_amount معًا بشكل ذرّي (atomic)، وتتحقق من صلاحية Admin بنفسها.
-- ============================================================

create function public.admin_set_delivery_fee(p_order_id uuid, p_fee numeric)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (select 1 from users where id = auth.uid() and role = 'admin') then
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

-- ============================================================
-- settings: الجدول بدون أي Policy عمدًا (مغلق تمامًا أمام أي عميل، حتى
-- Admin عبر REST مباشرة) — يبقى الأمر كذلك، وتُضاف بدلًا منه دالتان
-- آمنتان تتحققان من الدور صراحةً قبل أي قراءة أو كتابة.
-- ============================================================

create function public.admin_get_settings()
returns table (key text, value text, updated_at timestamptz)
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (select 1 from users where id = auth.uid() and role = 'admin') then
    raise exception 'هذا الإجراء متاح فقط للإدارة';
  end if;

  return query select s.key, s.value, s.updated_at from settings s order by s.key;
end;
$$;

create function public.admin_set_setting(p_key text, p_value text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (select 1 from users where id = auth.uid() and role = 'admin') then
    raise exception 'هذا الإجراء متاح فقط للإدارة';
  end if;

  insert into settings (key, value, updated_at)
  values (p_key, p_value, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;
