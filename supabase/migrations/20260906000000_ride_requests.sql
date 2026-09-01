-- ============================================================
-- Migration: Taxi — بنية أساسية (ride_requests)
--
-- نفس فلسفة delivery_requests بالحرف (migration 20260905000000):
-- جدول مستقل تمامًا عن orders، بلا أي لمس لمنطق Marketplace الحيّ.
-- الفرق الجوهري الوحيد عن "اطلب أي شيء": نقطتا انطلاق ووصول معروفتان
-- كلتاهما *وقت الإنشاء* (عنوان الانطلاق وعنوان الوجهة، كلاهما من
-- addresses الموجود أصلًا — لا حاجة لأي مكوّن خرائط/GPS جديد، نفس
-- قيد بنية التطبيق الحالية: لا اعتماد على أي مزوّد خرائط بعد)، بخلاف
-- "اطلب أي شيء" حيث الانطلاق (موقع الموصّل) غير معروف قبل القبول.
-- النتيجة: calculate_delivery_fee (نفس المحرك العام بالحرف، هنا ثاني
-- عميل غير-Marketplace له بعد التوصيل الحرّ) تُستدعى هنا وقت الإنشاء
-- مباشرة — لا وقت القبول — فمعاينة الأجرة ممكنة للعميل *قبل* إرسال
-- الطلب، بخلاف "اطلب أي شيء" عمدًا.
--
-- عنوان الانطلاق مرئي للموصّل حتى فـ المجمّع (قبل القبول) — بخلاف
-- عنوان "اطلب أي شيء" الذي يبقى مخفيًا حتى القبول — لأن الموصّل هنا
-- يحتاج فعليًا معرفة أين الزبون قبل قبول التوجّه إليه (نفس منطق رؤية
-- موقع التاجر فـ orders_select_driver_pool). عنوان الوجهة يبقى مرئيًا
-- أيضًا (V1 بسيط: لا مفاجآت، الموصّل يقرّر بمعرفة كاملة).
--
-- دورة حياة أطول بخطوة واحدة عن delivery_requests (in_progress تمثّل
-- "الراكب فـ السيارة الآن" — لا يوجد مكافئ لها فـ توصيل الأغراض):
-- pending -> accepted -> in_progress -> completed، أو
-- pending/accepted -> cancelled (تراجع الموصّل ممكن فقط accepted، نفس
-- قيد driver_release_order قبل "الاستلام الفعلي").
-- ============================================================

create table ride_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references users (id),
  pickup_address_id uuid not null references addresses (id),
  dropoff_address_id uuid not null references addresses (id),
  status text not null default 'pending' check (status in (
    'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  )),
  driver_id uuid references drivers (id),
  fare numeric(10, 2) not null default 0 check (fare >= 0),
  fare_method text not null default 'unconfigured' check (fare_method in (
    'fixed', 'distance', 'zone', 'unconfigured'
  )),
  driver_earning_share numeric(10, 2) not null default 0 check (driver_earning_share >= 0),
  platform_share numeric(10, 2) not null default 0 check (platform_share >= 0),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'collected')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  constraint ride_requests_pickup_dropoff_distinct check (pickup_address_id <> dropoff_address_id),
  constraint ride_requests_driver_share_not_exceed_fare check (driver_earning_share <= fare)
);

comment on table ride_requests is 'Taxi — طلبات رحلة ركّاب من نقطة انطلاق إلى نقطة وصول (عنوانان محفوظان، لا التقاط خرائط حيّ بعد). الأجرة تُحسَب وقت الإنشاء عبر calculate_delivery_fee (service_id لخدمة taxi) — بخلاف delivery_requests، الوجهتان معروفتان سلفًا فلا داعي لتأجيل الحساب لوقت القبول.';

create index ride_requests_customer_id_idx on ride_requests (customer_id);
create index ride_requests_driver_id_idx on ride_requests (driver_id);
create index ride_requests_status_idx on ride_requests (status);

-- ============================================================
-- محرّك الانتقالات — نفس نمط validate_delivery_request_status_transition
-- بخطوة accepted -> in_progress إضافية.
-- ============================================================
create function public.validate_ride_request_status_transition()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor_role text;
  is_assigned_driver boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  if auth.role() = 'service_role' then
    return new;
  end if;

  select role into actor_role from users where id = auth.uid();

  is_assigned_driver := exists (
    select 1 from drivers d
    where d.id = old.driver_id and d.user_id = auth.uid()
  );

  if old.status in ('completed', 'cancelled') then
    raise exception 'لا يمكن تغيير حالة رحلة فـ حالة نهائية (%)', old.status;
  end if;

  if old.status = 'pending' and new.status = 'accepted' and actor_role = 'driver' then
    return new;
  elsif old.status = 'pending' and new.status = 'cancelled'
        and (new.customer_id = auth.uid() or actor_role in ('admin', 'manager')) then
    return new;
  elsif old.status = 'accepted' and new.status = 'pending'
        and (actor_role in ('admin', 'manager') or is_assigned_driver) then
    -- تراجع الموصّل عن رحلة قبِلها (driver_release_ride_request) —
    -- نفس مفهوم driver_release_order، لكن هنا status نفسها تُميِّز
    -- "مقبولة" عن "بانتظار"، فالتراجع يستلزم إعادتها لـ pending فعليًا.
    return new;
  elsif old.status = 'accepted' and new.status = 'in_progress'
        and (actor_role in ('admin', 'manager') or is_assigned_driver) then
    return new;
  elsif old.status = 'accepted' and new.status = 'cancelled'
        and (actor_role in ('admin', 'manager') or is_assigned_driver
             or new.customer_id = auth.uid()) then
    return new;
  elsif old.status = 'in_progress' and new.status = 'completed'
        and (actor_role in ('admin', 'manager') or is_assigned_driver) then
    return new;
  else
    raise exception 'انتقال حالة غير مسموح: من % إلى %', old.status, new.status;
  end if;
end;
$$;

create trigger ride_requests_validate_status_transition
  before update on ride_requests
  for each row execute function public.validate_ride_request_status_transition();

-- ============================================================
-- الأمان (RLS)
-- ============================================================
alter table ride_requests enable row level security;

create policy "ride_requests_select_own_customer"
  on ride_requests for select
  using (customer_id = auth.uid());

create policy "ride_requests_select_driver_pool"
  on ride_requests for select
  using (
    status = 'pending'
    and driver_id is null
    and exists (select 1 from drivers d where d.user_id = auth.uid() and d.status = 'approved')
  );

create policy "ride_requests_select_driver_own"
  on ride_requests for select
  using (
    exists (select 1 from drivers d where d.id = ride_requests.driver_id and d.user_id = auth.uid())
  );

create policy "ride_requests_select_admin"
  on ride_requests for select
  using (public.can_manage_stores());

create policy "ride_requests_update_customer"
  on ride_requests for update
  using (customer_id = auth.uid());

create policy "ride_requests_update_driver"
  on ride_requests for update
  using (
    exists (select 1 from drivers d where d.id = ride_requests.driver_id and d.user_id = auth.uid())
  );

create policy "ride_requests_update_admin"
  on ride_requests for update
  using (public.can_manage_stores());

-- عنوانا الانطلاق/الوجهة مرئيان للموصّل حتى فـ المجمّع (status=pending)
-- — راجع تعليق الملف أعلاه لسبب الفرق عن delivery_requests. سياسة
-- واحدة تغطّي كلا العمودين (pickup_address_id وdropoff_address_id)
-- لأن addresses.id تتطابق مع أيّهما هنا سيّان.
create policy "addresses_select_driver_via_ride_pool"
  on addresses for select
  using (
    exists (
      select 1 from ride_requests r
      where (r.pickup_address_id = addresses.id or r.dropoff_address_id = addresses.id)
        and r.status = 'pending'
        and r.driver_id is null
        and exists (select 1 from drivers d where d.user_id = auth.uid() and d.status = 'approved')
    )
  );

create policy "addresses_select_driver_via_ride_requests"
  on addresses for select
  using (
    exists (
      select 1 from ride_requests r
      join drivers d on d.id = r.driver_id
      where (r.pickup_address_id = addresses.id or r.dropoff_address_id = addresses.id)
        and d.user_id = auth.uid()
    )
  );

-- ============================================================
-- إنشاء الطلب — يحسب الأجرة فورًا (بخلاف create_delivery_request)
-- لأن كلا الطرفين معروف سلفًا.
-- ============================================================
create function public.create_ride_request(
  p_pickup_address_id uuid,
  p_dropoff_address_id uuid
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_request_id uuid;
  v_service_id uuid;
  v_pickup_lat double precision;
  v_pickup_lng double precision;
  v_dropoff_lat double precision;
  v_dropoff_lng double precision;
  v_dropoff_commune_id integer;
  v_fee record;
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لطلب رحلة';
  end if;

  if exists (select 1 from users where id = v_customer_id and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if p_pickup_address_id = p_dropoff_address_id then
    raise exception 'نقطتا الانطلاق والوجهة يجب أن تكونا مختلفتين';
  end if;

  if not exists (
    select 1 from addresses where id = p_pickup_address_id and user_id = v_customer_id
  ) then
    raise exception 'عنوان الانطلاق غير صالح أو لا يخصك';
  end if;

  if not exists (
    select 1 from addresses where id = p_dropoff_address_id and user_id = v_customer_id
  ) then
    raise exception 'عنوان الوجهة غير صالح أو لا يخصك';
  end if;

  select id into v_service_id from services where slug = 'taxi';

  select latitude, longitude into v_pickup_lat, v_pickup_lng
  from addresses where id = p_pickup_address_id;

  select latitude, longitude, commune_id
    into v_dropoff_lat, v_dropoff_lng, v_dropoff_commune_id
  from addresses where id = p_dropoff_address_id;

  select * into v_fee
  from public.calculate_delivery_fee(
    v_service_id, v_pickup_lat, v_pickup_lng, v_dropoff_lat, v_dropoff_lng, v_dropoff_commune_id
  );

  insert into ride_requests (
    customer_id, pickup_address_id, dropoff_address_id, status,
    fare, fare_method, driver_earning_share, platform_share
  )
  values (
    v_customer_id, p_pickup_address_id, p_dropoff_address_id, 'pending',
    v_fee.fee, v_fee.method_used, v_fee.driver_share, v_fee.platform_share
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.create_ride_request is 'ينشئ طلب رحلة taxi بحالة pending، ويحسب الأجرة فورًا (calculate_delivery_fee بموقعَي عنوانَي الانطلاق/الوجهة المحفوظَين) — بخلاف create_delivery_request، لا حاجة لانتظار قبول موصّل هنا لأن كلا الطرفين معروف سلفًا. الأجرة "unconfigured/0" إن لم يضبط الأدمن تسعير خدمة taxi بعد، أو إن كان أحد العنوانين بلا إحداثيات محفوظة — لا يمنع إنشاء الطلب أبدًا.';

-- ============================================================
-- قبول/بدء/إنهاء/تراجع — نفس أنماط driver_claim_order/
-- driver_release_order بالحرف، بلا أي حساب أجرة هنا (محسوبة سلفًا).
-- ============================================================
create function public.driver_accept_ride_request(p_request_id uuid)
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

  update ride_requests
  set driver_id = v_driver_id,
      status = 'accepted',
      accepted_at = now()
  where id = p_request_id
    and status = 'pending'
    and driver_id is null;

  if not found then
    raise exception 'هذه الرحلة لم تعد متاحة (قبِلها موصّل آخر أو أُلغيت)';
  end if;
end;
$$;

create function public.driver_release_ride_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select id into v_driver_id from drivers where user_id = auth.uid();

  update ride_requests
  set driver_id = null,
      status = 'pending',
      accepted_at = null
  where id = p_request_id
    and driver_id = v_driver_id
    and status = 'accepted';

  if not found then
    raise exception 'لا يمكن التراجع عن هذه الرحلة فـ حالتها الحالية';
  end if;
end;
$$;

comment on function public.driver_release_ride_request is 'تراجع مسموح فقط قبل بدء الرحلة الفعلي (accepted) — نفس قيد driver_release_order — الطلب يعود لـ pending فـ المجمّع لموصّل آخر.';

create function public.driver_start_ride(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select id into v_driver_id from drivers where user_id = auth.uid();

  update ride_requests
  set status = 'in_progress',
      started_at = now()
  where id = p_request_id
    and driver_id = v_driver_id
    and status = 'accepted';

  if not found then
    raise exception 'لا يمكن بدء هذه الرحلة فـ حالتها الحالية';
  end if;
end;
$$;

create function public.driver_complete_ride(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select id into v_driver_id from drivers where user_id = auth.uid();

  update ride_requests
  set status = 'completed',
      completed_at = now()
  where id = p_request_id
    and driver_id = v_driver_id
    and status = 'in_progress';

  if not found then
    raise exception 'لا يمكن إتمام هذه الرحلة فـ حالتها الحالية';
  end if;
end;
$$;

-- ============================================================
-- الشبكة العامة الموجودة أصلًا — إعادة استخدام حرفي، نفس تعليق
-- delivery_requests: notify_order_webhook يرجع "ignored" بأمان لجدول
-- لم يُعالَج بعد فـ send-order-notification (لا فرع ride_requests
-- فيها بعد) — مربوط الآن لتفادي أي migration إضافية لاحقًا فقط.
-- ============================================================
create trigger ride_requests_notify_webhook
  after insert or update on ride_requests
  for each row execute function public.notify_order_webhook();

create trigger log_ride_requests_admin_activity
  after insert or update or delete on ride_requests
  for each row execute function public.log_admin_activity();

alter publication supabase_realtime add table ride_requests;

-- ============================================================
-- تفعيل خدمة "Taxi" (services.slug='taxi') — كانت enabled=false منذ
-- migration 20260824000000 عمدًا. صفحة رسوم التوصيل بلوحة الإدارة
-- (/dashboard/delivery-fees) عامة أصلًا لكل services — ستعرض بطاقة
-- "Taxi" تلقائيًا فور هذا التفعيل، بلا أي كود جديد فيها. الاسم
-- "رسوم التوصيل" يبقى دقيقًا مفاهيميًا حتى لـTaxi: نفس آلية التسعير
-- (ثابت/مسافة/منطقة) تنطبق حرفيًا على أجرة رحلة.
-- ============================================================
update services set enabled = true where slug = 'taxi';
