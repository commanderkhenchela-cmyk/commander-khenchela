-- ============================================================
-- Migration: "اطلب أي شيء" (Request Anything) — طلبات توصيل بلا تاجر
--
-- لماذا جدول مستقل تمامًا عن orders، لا توسيع orders.merchant_id
-- ليصبح nullable؟ فحصت orders أولًا: merchant_id عمود NOT NULL
-- مُعتمَد عليه بنيويًا في: validate_order_status_transition
-- (is_merchant_owner)، كل RLS policies الخاصة بالتاجر، مشغّلات العمولة/
-- المحفظة، ولوحتا التاجر والإدارة بالكامل. جعله nullable كان يعني لمس
-- كل هذا المنطق الحيّ العامل فعليًا فـ الإنتاج — خطر لا داعي له إطلاقًا
-- حين يكفي جدول مستقل بمنطقه الخاص. نفس فلسفة الاستقلال المعمارية التي
-- بُني عليها calculate_delivery_fee أصلًا (عام، لا يعرف شيئًا عن
-- Marketplace) — هنا نعيد استخدامه فعليًا كأول عميل حقيقي غير Marketplace.
--
-- نقطة الانطلاق (origin) لحساب رسوم التوصيل: موقع الموصّل الحالي وقت
-- قبوله الطلب (drivers.current_lat/current_lng، مُحدَّثة أصلًا كل 60
-- ثانية أثناء "متصل" — راجع DriverService.pingLocation فـ driver_app،
-- لا تتبّع جديد مطلوب). نتيجة هذا القرار: **لا يمكن معاينة الرسوم قبل
-- قبول موصّل الطلب** (لا موصّل = لا نقطة انطلاق معروفة) — العميل يرى
-- الرسم فقط بعد القبول، بخلاف Marketplace حيث merchant.latitude معروف
-- سلفًا. هذا تصميم مقصود متّفق عليه، ليس نقصًا.
--
-- دورة حياة أبسط من orders عمدًا (لا مرحلة "تحضير" — لا تاجر يُحضّر
-- شيئًا): pending -> accepted -> delivered، أو pending -> cancelled.
-- ============================================================

create table delivery_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references users (id),
  address_id uuid not null references addresses (id),
  description text not null check (trim(description) <> ''),
  status text not null default 'pending' check (status in (
    'pending', 'accepted', 'delivered', 'cancelled'
  )),
  driver_id uuid references drivers (id),
  delivery_fee numeric(10, 2) not null default 0 check (delivery_fee >= 0),
  delivery_fee_method text not null default 'unconfigured' check (delivery_fee_method in (
    'fixed', 'distance', 'zone', 'unconfigured'
  )),
  driver_earning_share numeric(10, 2) not null default 0 check (driver_earning_share >= 0),
  platform_delivery_share numeric(10, 2) not null default 0 check (platform_delivery_share >= 0),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'collected')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  constraint delivery_requests_driver_share_not_exceed_fee check (driver_earning_share <= delivery_fee)
);

comment on table delivery_requests is '"اطلب أي شيء" — طلبات توصيل حرّة بوصف نصي، بلا تاجر. سعر الغرض نفسه يُسوَّى نقدًا مباشرة بين العميل والموصّل عند التسليم (خارج التطبيق تمامًا، تمامًا كما تُحصَّل مبالغ orders نقدًا) — المنصّة تحسب وتتتبّع رسوم التوصيل فقط، لا سعر الغرض.';

create index delivery_requests_customer_id_idx on delivery_requests (customer_id);
create index delivery_requests_driver_id_idx on delivery_requests (driver_id);
create index delivery_requests_status_idx on delivery_requests (status);

-- ============================================================
-- محرّك الانتقالات — نفس نمط validate_order_status_transition
-- بالضبط، بمجموعة انتقالات أبسط تطابق دورة الحياة الأقصر أعلاه.
-- ============================================================
create function public.validate_delivery_request_status_transition()
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

  if old.status in ('delivered', 'cancelled') then
    raise exception 'لا يمكن تغيير حالة طلب في حالة نهائية (%)', old.status;
  end if;

  if old.status = 'pending' and new.status = 'accepted' and actor_role = 'driver' then
    return new;
  elsif old.status = 'pending' and new.status = 'cancelled'
        and (new.customer_id = auth.uid() or actor_role in ('admin', 'manager')) then
    return new;
  elsif old.status = 'accepted' and new.status = 'delivered'
        and (actor_role in ('admin', 'manager') or is_assigned_driver) then
    return new;
  elsif old.status = 'accepted' and new.status = 'cancelled' and actor_role in ('admin', 'manager') then
    return new;
  else
    raise exception 'انتقال حالة غير مسموح: من % إلى %', old.status, new.status;
  end if;
end;
$$;

create trigger delivery_requests_validate_status_transition
  before update on delivery_requests
  for each row execute function public.validate_delivery_request_status_transition();

-- ============================================================
-- الأمان (RLS)
-- ============================================================
alter table delivery_requests enable row level security;

create policy "delivery_requests_select_own_customer"
  on delivery_requests for select
  using (customer_id = auth.uid());

-- مجمع الطلبات المتاحة: pending وبلا موصّل بعد، يراها أي موصّل موافَق
-- عليه — نفس نمط orders_select_driver_pool بالحرف.
create policy "delivery_requests_select_driver_pool"
  on delivery_requests for select
  using (
    status = 'pending'
    and driver_id is null
    and exists (select 1 from drivers d where d.user_id = auth.uid() and d.status = 'approved')
  );

create policy "delivery_requests_select_driver_own"
  on delivery_requests for select
  using (
    exists (select 1 from drivers d where d.id = delivery_requests.driver_id and d.user_id = auth.uid())
  );

create policy "delivery_requests_select_admin"
  on delivery_requests for select
  using (public.can_manage_stores());

create policy "delivery_requests_update_customer"
  on delivery_requests for update
  using (customer_id = auth.uid());

create policy "delivery_requests_update_driver"
  on delivery_requests for update
  using (
    exists (select 1 from drivers d where d.id = delivery_requests.driver_id and d.user_id = auth.uid())
  );

create policy "delivery_requests_update_admin"
  on delivery_requests for update
  using (public.can_manage_stores());

-- العميل يحتاج رؤية عنوانه هو أصلًا (RLS addresses_select_own الموجودة
-- تكفي). الموصّل يحتاج رؤية عنوان الطلب الذي قبِله فعليًا — نفس نمط
-- addresses_select_driver_via_orders بالحرف.
create policy "addresses_select_driver_via_delivery_requests"
  on addresses for select
  using (
    exists (
      select 1 from delivery_requests r
      join drivers d on d.id = r.driver_id
      where r.address_id = addresses.id and d.user_id = auth.uid()
    )
  );

-- ============================================================
-- إنشاء الطلب — نفس هيكل create_order (فحص تسجيل الدخول + الإيقاف +
-- ملكية العنوان)، بلا حاجة لسطور منتجات بالطبع.
-- ============================================================
create function public.create_delivery_request(
  p_address_id uuid,
  p_description text
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_request_id uuid;
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإنشاء طلب';
  end if;

  if exists (select 1 from users where id = v_customer_id and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = v_customer_id
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  if trim(coalesce(p_description, '')) = '' then
    raise exception 'صف ما تريد طلبه أولًا';
  end if;

  insert into delivery_requests (customer_id, address_id, description, status)
  values (v_customer_id, p_address_id, trim(p_description), 'pending')
  returning id into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.create_delivery_request is 'ينشئ طلب "اطلب أي شيء" بحالة pending، بلا أي رسوم توصيل محسوبة بعد — تُحسَب فقط عند القبول (driver_accept_delivery_request)، لأن نقطة الانطلاق (موقع الموصّل) غير معروفة قبل ذلك.';

-- ============================================================
-- قبول الموصّل — يحسب رسوم التوصيل هنا فعليًا (لا وقت الإنشاء)، لأن
-- هذه هي أول لحظة تتوفّر فيها نقطة انطلاق حقيقية (موقع الموصّل).
-- ============================================================
create function public.driver_accept_delivery_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
  v_driver_lat double precision;
  v_driver_lng double precision;
  v_service_id uuid;
  v_dest_lat double precision;
  v_dest_lng double precision;
  v_dest_commune_id integer;
  v_fee record;
begin
  if exists (select 1 from users where id = auth.uid() and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  select id, current_lat, current_lng into v_driver_id, v_driver_lat, v_driver_lng
  from drivers
  where user_id = auth.uid() and status = 'approved';

  if v_driver_id is null then
    raise exception 'حساب الموصّل غير موجود أو غير موافَق عليه بعد';
  end if;

  if v_driver_lat is null or v_driver_lng is null then
    raise exception 'يلزم تفعيل "متصل" أولًا حتى يُعرَف موقعك — بدونه لا يمكن حساب رسوم التوصيل';
  end if;

  select id into v_service_id from services where slug = 'delivery';

  select latitude, longitude, commune_id
    into v_dest_lat, v_dest_lng, v_dest_commune_id
  from addresses
  where id = (select address_id from delivery_requests where id = p_request_id);

  select * into v_fee
  from public.calculate_delivery_fee(
    v_service_id, v_driver_lat, v_driver_lng, v_dest_lat, v_dest_lng, v_dest_commune_id
  );

  update delivery_requests
  set driver_id = v_driver_id,
      status = 'accepted',
      accepted_at = now(),
      delivery_fee = v_fee.fee,
      delivery_fee_method = v_fee.method_used,
      driver_earning_share = v_fee.driver_share,
      platform_delivery_share = v_fee.platform_share
  where id = p_request_id
    and status = 'pending'
    and driver_id is null;

  if not found then
    raise exception 'هذا الطلب لم يعد متاحًا (قبِله موصّل آخر أو أُلغي)';
  end if;
end;
$$;

comment on function public.driver_accept_delivery_request is 'نفس قفل الصفّ الذري لـ driver_claim_order (status=pending and driver_id is null داخل نفس update) — يمنع بنيويًا قبول موصّلَين لنفس الطلب معًا. calculate_delivery_fee نفسه المستخدَم فـ Marketplace بالحرف، فقط origin مختلف (موقع الموصّل بدل موقع التاجر) — لا تعديل على الدالة العامة نفسها إطلاقًا.';

create function public.driver_complete_delivery_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid;
begin
  select id into v_driver_id from drivers where user_id = auth.uid();

  update delivery_requests
  set status = 'delivered'
  where id = p_request_id
    and driver_id = v_driver_id
    and status = 'accepted';

  if not found then
    raise exception 'لا يمكن إتمام هذا الطلب في حالته الحالية';
  end if;
end;
$$;

-- ============================================================
-- الشبكة العامة الموجودة أصلًا — إعادة استخدام حرفي بلا أي كود جديد.
-- notify_order_webhook: الجدول غير مُعالَج بعد داخل Edge Function
-- send-order-notification (لا فرع delivery_requests فيها بعد) — ربطه
-- هنا الآن غير ضارّ إطلاقًا (ترجع "ignored" بأمان)، ويجهّز الإشعارات
-- الفورية لتُفعَّل لاحقًا بمجرّد إضافة الفرع ونشر الدالة، بلا أي
-- migration إضافية حينها.
-- ============================================================
create trigger delivery_requests_notify_webhook
  after insert or update on delivery_requests
  for each row execute function public.notify_order_webhook();

create trigger log_delivery_requests_admin_activity
  after insert or update or delete on delivery_requests
  for each row execute function public.log_admin_activity();

alter publication supabase_realtime add table delivery_requests;

-- ============================================================
-- تفعيل خدمة "التوصيل" (services.slug='delivery') — كانت enabled=false
-- منذ migration 20260824000000 عمدًا ("غير مبنية بعد فعليًا"، راجع
-- تعليقها). الآن مبنية. صفحة رسوم التوصيل بلوحة الإدارة
-- (/dashboard/delivery-fees) عامة أصلًا لكل services — ستعرض بطاقة
-- "التوصيل" تلقائيًا فور هذا التفعيل، بلا أي كود جديد فيها.
-- ============================================================
update services set enabled = true where slug = 'delivery';

