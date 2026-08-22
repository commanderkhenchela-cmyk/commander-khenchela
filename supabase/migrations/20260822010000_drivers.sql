-- ============================================================
-- Migration: نظام موصّلي التوصيل بالدراجات (المرحلة 1)
--
-- التوصيل كان يدويًا بالكامل عبر الإدارة (قرار V1 موثَّق). هذه
-- الـ migration تضيف طرفًا رابعًا حقيقيًا (الموصّل) يتولّى نفس ثلاث
-- خطوات التوصيل التي كانت الإدارة تنفّذها يدويًا
-- (ready_for_pickup → picked_up → out_for_delivery → delivered)،
-- بدون حذف صلاحية الإدارة في التجاوز في أي لحظة.
--
-- سيارات الأجرة (الكورسة) مرحلة قادمة منفصلة تمامًا — vehicle_type
-- مقيَّد بـ 'bike' فقط عمدًا الآن، يُوسَّع لاحقًا بمجرد تعديل الـ check.
-- ============================================================

-- ---------- السماح بدور driver في users.role ----------
alter table users drop constraint if exists users_role_check;
alter table users add constraint users_role_check
  check (role in ('customer', 'merchant', 'driver', 'admin', 'manager', 'ads_manager'));

-- ---------- جدول drivers ----------
create table drivers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id),
  full_name text not null,
  phone text not null,
  vehicle_type text not null default 'bike' check (vehicle_type in ('bike')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  is_online boolean not null default false,
  current_lat double precision,
  current_lng double precision,
  location_updated_at timestamptz,
  created_at timestamptz not null default now(),
  constraint drivers_user_id_key unique (user_id)
);

comment on table drivers is 'حسابات موصّلي التوصيل (دراجات فقط في المرحلة 1). vehicle_type مقيَّد بـ bike الآن فقط، لتفادي مشكلة merchants.owner_user_id (سجّل مكرَّر يكسر .maybeSingle()) — قيد unique على user_id من اليوم الأول.';

create index drivers_status_idx on drivers (status);
create index drivers_is_online_idx on drivers (is_online);

-- ---------- حماية الأعمدة الحسّاسة من التعديل المباشر ----------
-- نفس نمط protect_merchant_status(): RLS تسمح للموصّل بلمس صفّه، وهذا
-- الـ Trigger يعيد أي عمود حسّاس لقيمته القديمة صامتًا إن لم يكن
-- الفاعل can_manage_stores() (admin/manager).
create function public.protect_driver_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_manage_stores() then
    if new.status is distinct from old.status then
      new.status := old.status;
    end if;
    if new.vehicle_type is distinct from old.vehicle_type then
      new.vehicle_type := old.vehicle_type;
    end if;
  end if;
  return new;
end;
$$;

create trigger drivers_protect_status
  before update on drivers
  for each row execute function public.protect_driver_status();

-- ---------- RLS على drivers ----------
alter table drivers enable row level security;

create policy "drivers_select_own"
  on drivers for select
  using (user_id = auth.uid());

create policy "drivers_insert_own"
  on drivers for insert
  with check (user_id = auth.uid() and status = 'pending');

create policy "drivers_update_own"
  on drivers for update
  using (user_id = auth.uid());

create policy "drivers_select_admin"
  on drivers for select
  using (public.can_manage_stores());

create policy "drivers_update_admin"
  on drivers for update
  using (public.can_manage_stores());

-- ---------- ربط drivers بشبكة الإشعارات (امتداد المرحلة 0) ----------
-- نفس دالة notify_order_webhook العامة المستخدَمة لـ orders وmerchants.
create trigger drivers_notify_webhook
  after insert or update on drivers
  for each row execute function public.notify_order_webhook();

comment on trigger drivers_notify_webhook on drivers is 'يستدعي send-order-notification عند تسجيل موصّل جديد (إشعار للإدارة) أو تغيّر حالته (إشعار للموصّل نفسه) — فرع drivers يُضاف في نفس الدالة عند نشرها.';

-- ---------- ربط orders بالموصّل ----------
alter table orders add column driver_id uuid references drivers (id);
create index orders_driver_id_idx on orders (driver_id);

-- مجمع الطلبات المتاحة: جاهزة للاستلام ولم يُعيَّن لها موصّل بعد،
-- يراها أي موصّل موافَق عليه (وليس فقط موصّله المُعيَّن).
create policy "orders_select_driver_pool"
  on orders for select
  using (
    status = 'ready_for_pickup'
    and driver_id is null
    and exists (select 1 from drivers d where d.user_id = auth.uid() and d.status = 'approved')
  );

-- الطلبات التي يملكها الموصّل فعليًا (بعد الاستلام).
create policy "orders_select_driver_own"
  on orders for select
  using (
    exists (select 1 from drivers d where d.id = orders.driver_id and d.user_id = auth.uid())
  );

-- RLS تسمح للموصّل المُعيَّن بلمس صفّ طلبه، والـ Trigger أدناه يقرر إن
-- كان الانتقال نفسه مسموحًا (نفس نمط orders_update_customer/merchant).
create policy "orders_update_driver"
  on orders for update
  using (
    exists (select 1 from drivers d where d.id = orders.driver_id and d.user_id = auth.uid())
  );

-- الموصّل يحتاج يرى عنوان/هاتف العميل للطلب الذي استلمه فعليًا —
-- نفس نمط addresses_select_merchant_via_orders الموجودة أصلًا.
create policy "addresses_select_driver_via_orders"
  on addresses for select
  using (
    exists (
      select 1 from orders o
      join drivers d on d.id = o.driver_id
      where o.address_id = addresses.id and d.user_id = auth.uid()
    )
  );

-- ---------- استلام/تراجع طلب — RPC آمنتان من التعارض ----------
create function public.driver_claim_order(p_order_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
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

comment on function public.driver_claim_order is 'شرط driver_id is null داخل نفس جملة update يمنع بنيويًا استلام موصّلَين لنفس الطلب في نفس اللحظة — قفل Postgres على مستوى الصفّ يضمن فوز معاملة واحدة فقط، والخاسر يحصل على استثناء نظيف.';

create function public.driver_release_order(p_order_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select id into v_driver_id from drivers where user_id = auth.uid();

  update orders
  set driver_id = null
  where id = p_order_id
    and driver_id = v_driver_id
    and status = 'ready_for_pickup';

  if not found then
    raise exception 'لا يمكن التراجع عن هذا الطلب في حالته الحالية';
  end if;
end;
$$;

comment on function public.driver_release_order is 'تراجع مسموح فقط قبل الاستلام الفعلي (ready_for_pickup) — بعدها (picked_up وما بعدها) الأمر يحتاج تدخّل إدارة، ليس تراجعًا ذاتيًا.';

-- ---------- توسيع validate_order_status_transition: الموصّل كفاعل مسموح ----------
-- نفس نص الدالة الحالية حرفيًا (من 20260819050142_create_orders.sql)،
-- مع إضافة is_assigned_driver فقط على الانتقالات الثلاثة بعد الاستلام.
-- الإدارة تحتفظ بنفس صلاحياتها الكاملة في كل الانتقالات كما هي.
create or replace function public.validate_order_status_transition()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor_role text;
  is_merchant_owner boolean;
  is_assigned_driver boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  -- Edge Functions الموثوقة (Service Role) تتجاوز هذا الفحص
  if auth.role() = 'service_role' then
    return new;
  end if;

  select role into actor_role from users where id = auth.uid();

  is_merchant_owner := exists (
    select 1 from merchants m
    where m.id = new.merchant_id and m.owner_user_id = auth.uid()
  );

  is_assigned_driver := exists (
    select 1 from drivers d
    where d.id = old.driver_id and d.user_id = auth.uid()
  );

  if old.status in ('delivered', 'cancelled', 'rejected') then
    raise exception 'لا يمكن تغيير حالة طلب في حالة نهائية (%)', old.status;
  end if;

  if old.status = 'pending' and new.status = 'confirmed' and is_merchant_owner then
    return new;
  elsif old.status = 'pending' and new.status = 'rejected' and is_merchant_owner then
    return new;
  elsif old.status = 'pending' and new.status = 'cancelled'
        and (new.customer_id = auth.uid() or actor_role = 'admin') then
    return new;
  elsif old.status = 'confirmed' and new.status = 'preparing' and is_merchant_owner then
    return new;
  elsif old.status = 'confirmed' and new.status = 'cancelled' and actor_role = 'admin' then
    return new;
  elsif old.status = 'preparing' and new.status = 'ready_for_pickup' and is_merchant_owner then
    return new;
  elsif old.status = 'preparing' and new.status = 'cancelled' and actor_role = 'admin' then
    return new;
  elsif old.status = 'ready_for_pickup' and new.status = 'picked_up'
        and (actor_role = 'admin' or is_assigned_driver) then
    return new;
  elsif old.status = 'picked_up' and new.status = 'out_for_delivery'
        and (actor_role = 'admin' or is_assigned_driver) then
    return new;
  elsif old.status = 'out_for_delivery' and new.status = 'delivered'
        and (actor_role = 'admin' or is_assigned_driver) then
    return new;
  else
    raise exception 'انتقال حالة غير مسموح: من % إلى %', old.status, new.status;
  end if;
end;
$$;
