-- ============================================================
-- Migration: Delivery Fee Engine — عام، قابل لإعادة الاستخدام،
-- مُدار بالكامل من الإدارة (لا رسوم يدوية بعد الآن لكل طلب).
--
-- المشكلة التي تُحلّ: delivery_fee كان دائمًا صفرًا وقت الإنشاء، ولا
-- يُحدَّد إلا يدويًا من الإدارة بعد إنشاء الطلب (admin_set_delivery_fee)
-- — العميل يؤكّد طلبه دون رؤية سعر التوصيل إطلاقًا اليوم.
--
-- القرار المعماري الأهم (طلب صريح من صاحب المشروع، مُعاد تأكيده بعد
-- مراجعة الخطة): calculate_delivery_fee لا تعرف شيئًا عن "تاجر" أو
-- "عميل" أو Marketplace إطلاقًا — تستقبل فقط origin/destination
-- (إحداثيات + بلدية الوجهة) ومعرّف خدمة. ربط "التاجر = origin، عنوان
-- العميل = destination" موجود فقط داخل create_order/preview_delivery_fee
-- (المُستهلِكَين الحاليَّين)، بحيث يستطيع Taxi (نقطة استلام→نقطة نزول)
-- أو الحرفيون (عميل→موقع العمل) استخدام نفس المحرك حرفيًا لاحقًا،
-- بمصادر إحداثيات مختلفة تمامًا، بلا أي تعديل على المحرك نفسه.
--
-- كل الدوال الجديدة SECURITY DEFINER تضبط search_path = public صراحة،
-- بنفس اتفاقية كل دالة موجودة أصلًا فـ هذا المشروع (create_order،
-- admin_set_delivery_fee، protect_merchant_commission_override...).
-- حساب المبلغ النهائي مصدره الوحيد create_order نفسه على السيرفر —
-- لا يوجد أي معامل مبلغ/رسم يُقبَل من العميل، لا اليوم ولا بعد هذا
-- التعديل؛ توقيع create_order (3 معاملات) يبقى كما هو حرفيًا.
-- ============================================================

-- ============================================================
-- 1) addresses: إحداثيات اختيارية (لا وجود لها إطلاقًا اليوم) — تلزم
--    فقط لطريقة الحساب "حسب المسافة". NULL لكل عنوان قديم ولأي عنوان
--    جديد لم يفعّل المستخدم زر "استخدم موقعي" — لا كسر لأي عنوان قائم.
-- ============================================================

alter table addresses add column latitude double precision
  check (latitude is null or latitude between -90 and 90);
alter table addresses add column longitude double precision
  check (longitude is null or longitude between -180 and 180);

comment on column addresses.latitude is 'إحداثيات اختيارية يلتقطها العميل بزر "استخدم موقعي الحالي" فـ نموذج العنوان — تُستخدَم فقط لو كانت طريقة حساب رسوم التوصيل النشطة "حسب المسافة". NULL = لا تأثير، نفس سلوك اليوم.';
comment on column addresses.longitude is 'راجع تعليق latitude.';

-- ============================================================
-- 2) delivery_fee_configs: صف واحد لكل خدمة (services.id) — طريقة
--    الحساب + معاملاتها + حصة الموصّل. لا صف = "غير مُهيَّأ بعد"،
--    والمحرك يتعامل معها بأمان (رسم صفري، نفس سلوك اليوم تمامًا).
-- ============================================================

create table delivery_fee_configs (
  service_id uuid primary key references services (id),
  method text not null check (method in ('fixed', 'distance', 'zone')),
  fixed_amount numeric(10, 2) check (fixed_amount is null or fixed_amount >= 0),
  distance_base_amount numeric(10, 2) check (distance_base_amount is null or distance_base_amount >= 0),
  distance_per_km_amount numeric(10, 2) check (distance_per_km_amount is null or distance_per_km_amount >= 0),
  driver_share_type text not null check (driver_share_type in ('fixed', 'percentage')),
  driver_share_value numeric(10, 2) not null default 0 check (driver_share_value >= 0),
  enabled boolean not null default true,
  updated_by uuid references users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_fee_configs_fixed_requires_amount
    check (method <> 'fixed' or fixed_amount is not null),
  constraint delivery_fee_configs_distance_requires_amounts
    check (method <> 'distance' or (distance_base_amount is not null and distance_per_km_amount is not null)),
  constraint delivery_fee_configs_percentage_max_100
    check (driver_share_type <> 'percentage' or driver_share_value <= 100)
);

comment on table delivery_fee_configs is 'إعدادات رسوم التوصيل لكل خدمة — صف واحد لكل service_id. لا صف = رسم صفري افتراضيًا (نفس سلوك اليوم) حتى تُهيَّئه الإدارة صراحة. مصدر الحقيقة الوحيد لطريقة الحساب — لا شيء Hardcoded فـ أي تطبيق.';

alter table delivery_fee_configs enable row level security;

create policy "delivery_fee_configs_all_settings_manage"
  on delivery_fee_configs for all
  using (public.has_capability('settings.manage'))
  with check (public.has_capability('settings.manage'));

create function public.set_delivery_fee_configs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger delivery_fee_configs_set_updated_at
  before update on delivery_fee_configs
  for each row execute function public.set_delivery_fee_configs_updated_at();

create trigger log_delivery_fee_configs_admin_activity
  after insert or update or delete on delivery_fee_configs
  for each row execute function public.log_admin_activity();

-- ============================================================
-- 3) delivery_fee_zone_prices: طريقة "حسب البلدية" — لا يوجد جدول
--    "مناطق" فعلي فـ المشروع، communes هي أدقّ تقسيم جغرافي موجود
--    أصلًا، فنعتمدها بدل اختراع جغرافيا جديدة.
-- ============================================================

create table delivery_fee_zone_prices (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references services (id),
  commune_id integer not null references communes (id),
  price numeric(10, 2) not null check (price >= 0),
  updated_by uuid references users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_fee_zone_prices_unique unique (service_id, commune_id)
);

comment on table delivery_fee_zone_prices is 'سعر رسم التوصيل لكل (خدمة، بلدية) — يُستخدَم فقط عندما تكون طريقة الخدمة "zone". لا صف لبلدية معيّنة = رسم صفري افتراضيًا لتلك البلدية حتى تُسعَّر.';

alter table delivery_fee_zone_prices enable row level security;

create policy "delivery_fee_zone_prices_all_settings_manage"
  on delivery_fee_zone_prices for all
  using (public.has_capability('settings.manage'))
  with check (public.has_capability('settings.manage'));

create trigger delivery_fee_zone_prices_set_updated_at
  before update on delivery_fee_zone_prices
  for each row execute function public.set_delivery_fee_configs_updated_at();

create trigger log_delivery_fee_zone_prices_admin_activity
  after insert or update or delete on delivery_fee_zone_prices
  for each row execute function public.log_admin_activity();

-- ============================================================
-- 4) orders: أعمدة اللقطة (Snapshot) الجديدة — تُكتَب مرة واحدة فقط
--    وقت الإنشاء (أو التعديل الاستثنائي اليدوي)، لا تتأثر أبدًا بتغيير
--    إعدادات delivery_fee_configs لاحقًا. القيم الافتراضية لا تغيّر أي
--    صف قديم فعليًا (لم يكن لديه لا طريقة حساب ولا حصة موصّل أصلًا).
-- ============================================================

alter table orders add column delivery_fee_method text not null default 'unconfigured'
  check (delivery_fee_method in ('fixed', 'distance', 'zone', 'unconfigured', 'manual_override'));
alter table orders add column driver_earning_share numeric(10, 2) not null default 0
  check (driver_earning_share >= 0);
alter table orders add column platform_delivery_share numeric(10, 2) not null default 0
  check (platform_delivery_share >= 0);
alter table orders add column delivery_fee_override_reason text;

alter table orders add constraint orders_driver_share_not_exceed_fee
  check (driver_earning_share <= delivery_fee);

comment on column orders.delivery_fee_method is 'طريقة حساب رسوم التوصيل الفعلية وقت إنشاء هذا الطلب تحديدًا (لقطة، لا تتغيّر لاحقًا) — أو manual_override إن عدَّلها أدمن يدويًا بعد الإنشاء.';
comment on column orders.driver_earning_share is 'حصة الموصّل من رسوم التوصيل — لقطة محسوبة وقت الإنشاء (أو التعديل اليدوي)، معلوماتية/تدقيقية فقط، لا يوجد نظام محفظة/صرف للموصّلين بعد.';
comment on column orders.platform_delivery_share is 'حصة المنصة من رسوم التوصيل = delivery_fee - driver_earning_share وقت الحساب.';
comment on column orders.delivery_fee_override_reason is 'سبب آخر تعديل يدوي استثنائي على رسوم هذا الطلب من طرف الإدارة (admin_override_delivery_fee) — يظهر تلقائيًا فـ admin_activity_log.changes بفضل log_orders_admin_activity الموجودة أصلًا، بلا أي كود تسجيل جديد.';

-- ============================================================
-- 5) حماية أعمدة اللقطة: RLS الحالية لـ orders (orders_update_customer/
--    _merchant/_driver) تسمح بتحديث الصف عمومًا لأصحابه دون تقييد
--    الأعمدة — لا شيء يمنع اليوم مثلًا driver_app من إرسال
--    delivery_fee ضمن نفس نداء تحديث status (راجع advanceStatus فـ
--    order_service.dart، تحديث خام بلا فلترة أعمدة). كان بلا أثر طالما
--    delivery_fee = 0 دائمًا؛ يصبح ثغرة حقيقية الآن. نفس نمط
--    protect_merchant_commission_override تمامًا: رفض صامت للعمود
--    فقط، لا فشل للتحديث كاملًا.
--
--    آمنة تمامًا مع create_order: تلك الدالة تكتب أعمدة اللقطة فـ
--    INSERT الأولي فقط، ولا تلمسها إطلاقًا فـ UPDATE النهائي — فلا
--    تستدعي هذا الـ Trigger أصلًا على كتاباتها الخاصة.
-- ============================================================

create function public.protect_orders_delivery_fee_snapshot()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if (
    new.delivery_fee is distinct from old.delivery_fee
    or new.delivery_fee_method is distinct from old.delivery_fee_method
    or new.driver_earning_share is distinct from old.driver_earning_share
    or new.platform_delivery_share is distinct from old.platform_delivery_share
    or new.delivery_fee_override_reason is distinct from old.delivery_fee_override_reason
  ) and not public.has_capability('settings.manage') then
    new.delivery_fee := old.delivery_fee;
    new.delivery_fee_method := old.delivery_fee_method;
    new.driver_earning_share := old.driver_earning_share;
    new.platform_delivery_share := old.platform_delivery_share;
    new.delivery_fee_override_reason := old.delivery_fee_override_reason;
  end if;
  return new;
end;
$$;

create trigger orders_protect_delivery_fee_snapshot
  before update on orders
  for each row execute function public.protect_orders_delivery_fee_snapshot();

-- ============================================================
-- 6) haversine_km: نفس الصيغة المُستخدَمة فعليًا فـ الطرفين (Dart،
--    apps/customer_app/lib/utils/distance.dart وapps/driver_app بنفس
--    الطريقة) — منقولة حرفيًا لـ SQL، لا صيغة جديدة، ليكون الحساب
--    موثوقًا من السيرفر لا من العميل.
-- ============================================================

create function public.haversine_km(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
returns double precision
language sql
immutable
as $$
  select 6371.0 * 2 * asin(
    sqrt(
      sin(radians(lat2 - lat1) / 2) ^ 2
      + cos(radians(lat1)) * cos(radians(lat2)) * sin(radians(lon2 - lon1) / 2) ^ 2
    )
  );
$$;

comment on function public.haversine_km is 'نقل حرفي لصيغة Haversine المستخدَمة أصلًا فـ apps/customer_app و apps/driver_app (Dart) — نفس نصف قطر الأرض (6371 كم)، نفس الصيغة المثلثية، فقط بصياغة SQL بديلة رياضيًا لـ atan2 (asin هنا مكافئة تمامًا لصيغة Haversine القياسية).';

-- ============================================================
-- 7) calculate_delivery_fee: المحرك العام — لا تعرف شيئًا عن تاجر أو
--    عميل أو Marketplace، فقط origin/destination + معرّف خدمة. أي
--    خدمة مستقبلية (Taxi، توصيل عام، حرفيون) تستدعيها مباشرة بمصادر
--    إحداثيات مختلفة تمامًا بلا أي تعديل هنا.
-- ============================================================

create function public.calculate_delivery_fee(
  p_service_id uuid,
  p_origin_lat double precision,
  p_origin_lng double precision,
  p_destination_lat double precision,
  p_destination_lng double precision,
  p_destination_commune_id integer
)
returns table (fee numeric, method_used text, driver_share numeric, platform_share numeric)
language plpgsql
security definer set search_path = public
stable
as $$
declare
  v_config record;
  v_fee numeric(10, 2);
  v_driver_share numeric(10, 2);
begin
  if p_service_id is null then
    return query select 0::numeric, 'unconfigured'::text, 0::numeric, 0::numeric;
    return;
  end if;

  select * into v_config
  from delivery_fee_configs
  where service_id = p_service_id and enabled = true;

  if not found then
    return query select 0::numeric, 'unconfigured'::text, 0::numeric, 0::numeric;
    return;
  end if;

  if v_config.method = 'fixed' then
    v_fee := coalesce(v_config.fixed_amount, 0);
  elsif v_config.method = 'distance' then
    if p_origin_lat is null or p_origin_lng is null
       or p_destination_lat is null or p_destination_lng is null then
      -- إحداثيات ناقصة (تاجر لم يحدّد موقعه، أو عميل لم يفعّل "استخدم
      -- موقعي") — لا نمنع إنشاء الطلب، نرجع لنفس سلوك "غير مُهيَّأ".
      return query select 0::numeric, 'unconfigured'::text, 0::numeric, 0::numeric;
      return;
    end if;
    v_fee := v_config.distance_base_amount
      + v_config.distance_per_km_amount * public.haversine_km(p_origin_lat, p_origin_lng, p_destination_lat, p_destination_lng);
  elsif v_config.method = 'zone' then
    if p_destination_commune_id is null then
      return query select 0::numeric, 'unconfigured'::text, 0::numeric, 0::numeric;
      return;
    end if;
    select price into v_fee
    from delivery_fee_zone_prices
    where service_id = p_service_id and commune_id = p_destination_commune_id;

    if v_fee is null then
      -- بلدية لم تُسعَّر بعد لهذه الخدمة تحديدًا.
      return query select 0::numeric, 'unconfigured'::text, 0::numeric, 0::numeric;
      return;
    end if;
  end if;

  v_fee := round(greatest(v_fee, 0), 2);

  if v_config.driver_share_type = 'percentage' then
    v_driver_share := round(v_fee * v_config.driver_share_value / 100, 2);
  else
    v_driver_share := v_config.driver_share_value;
  end if;

  -- الحماية من تجاوز حصة ثابتة للرسم الفعلي (مثلاً حصة ثابتة 100 دج
  -- على رسم منطقة قريبة قيمته 50 دج فقط) — حصة المنصة لا يمكن أن تصبح
  -- سالبة أبدًا مهما كانت إعدادات الإدارة.
  v_driver_share := least(greatest(v_driver_share, 0), v_fee);

  return query select v_fee, v_config.method, v_driver_share, (v_fee - v_driver_share);
end;
$$;

comment on function public.calculate_delivery_fee is 'محرك حساب رسوم التوصيل العام — origin/destination فقط، لا معرفة بتاجر/عميل/Marketplace إطلاقًا. أي خدمة مستقبلية تستدعيها مباشرة بمصادر إحداثيات مختلفة تمامًا. غياب إعداد أو إحداثيات لا يمنع إنشاء الطلب أبدًا — يرجع (0، unconfigured) دائمًا كسلوك آمن مطابق تمامًا لما كان يحدث قبل هذا التعديل.';

-- ============================================================
-- 8) preview_delivery_fee: الغلاف الخاص بـ Marketplace/المطاعم —
--    هنا فقط (وليس داخل المحرك نفسه) يُربَط "التاجر = origin، عنوان
--    العميل = destination". للعرض فقط قبل التأكيد؛ لا تُستهلَك نتيجته
--    كمُدخَل لـ create_order إطلاقًا — create_order يعيد الحساب بنفسه
--    من الصفر على السيرفر، فلا يمكن لعميل التلاعب بالسعر عبر هذه الدالة.
-- ============================================================

create function public.preview_delivery_fee(p_merchant_id uuid, p_address_id uuid)
returns table (fee numeric, method_used text)
language plpgsql
security definer set search_path = public
stable
as $$
declare
  v_service_id uuid;
  v_merchant_lat double precision;
  v_merchant_lng double precision;
  v_address_lat double precision;
  v_address_lng double precision;
  v_commune_id integer;
begin
  if not exists (
    select 1 from merchants where id = p_merchant_id and status = 'approved'
  ) then
    raise exception 'المحل غير موجود أو غير موافَق عليه بعد';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = auth.uid()
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  select mc.service_id, m.latitude, m.longitude
    into v_service_id, v_merchant_lat, v_merchant_lng
  from merchants m
  left join merchant_categories mc on mc.id = m.category_id
  where m.id = p_merchant_id;

  select latitude, longitude, commune_id
    into v_address_lat, v_address_lng, v_commune_id
  from addresses where id = p_address_id;

  return query
    select c.fee, c.method_used
    from public.calculate_delivery_fee(
      v_service_id, v_merchant_lat, v_merchant_lng, v_address_lat, v_address_lng, v_commune_id
    ) c;
end;
$$;

comment on function public.preview_delivery_fee is 'معاينة رسم التوصيل قبل تأكيد الطلب (شاشة إتمام الطلب فـ customer_app) — للعرض فقط، لا تُستخدَم نتيجتها كمدخل لـ create_order إطلاقًا؛ الحساب النهائي الملزم يعيد حسابه create_order بنفسه من الصفر.';

-- ============================================================
-- 9) create_order — نفس الجسم الحالي حرفيًا (توقيع 3 معاملات كما هو،
--    بلا أي معامل رسم/مبلغ جديد)، فقط: (أ) حساب رسم التوصيل الفعلي
--    بين فحص ملكية العنوان وفحص السلة الفارغة، (ب) قيم INSERT الأولي
--    تحمل الرسم المحسوب بدل صفر ثابت، (ج) total_amount النهائي يضيف
--    رسم التوصيل لأول مرة. باقي المنطق (حلقة المنتجات، نسبة العمولة)
--    بلا أي تغيير إطلاقًا.
-- ============================================================

create or replace function public.create_order(
  p_merchant_id uuid,
  p_address_id uuid,
  p_items jsonb
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_subtotal numeric(10, 2) := 0;
  v_commission_rate numeric(5, 2);
  v_platform_commission numeric(10, 2);
  v_merchant_amount numeric(10, 2);
  v_order_id uuid;
  v_item jsonb;
  v_product record;
  v_quantity integer;
  v_line_subtotal numeric(10, 2);
  v_service_id uuid;
  v_merchant_lat double precision;
  v_merchant_lng double precision;
  v_address_lat double precision;
  v_address_lng double precision;
  v_commune_id integer;
  v_delivery_fee numeric(10, 2);
  v_delivery_fee_method text;
  v_driver_share numeric(10, 2);
  v_platform_share numeric(10, 2);
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإنشاء طلب';
  end if;

  if exists (select 1 from users where id = v_customer_id and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if not exists (
    select 1 from merchants where id = p_merchant_id and status = 'approved'
  ) then
    raise exception 'المحل غير موجود أو غير موافَق عليه بعد';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = v_customer_id
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  -- حساب رسم التوصيل: نفس ربط "تاجر=origin، عنوان=destination"
  -- المستخدَم فـ preview_delivery_fee بالضبط — المحرك نفسه (calculate_
  -- delivery_fee) لا يعرف شيئًا عن هذا الربط.
  select mc.service_id, m.latitude, m.longitude
    into v_service_id, v_merchant_lat, v_merchant_lng
  from merchants m
  left join merchant_categories mc on mc.id = m.category_id
  where m.id = p_merchant_id;

  select latitude, longitude, commune_id
    into v_address_lat, v_address_lng, v_commune_id
  from addresses where id = p_address_id;

  select fee, method_used, driver_share, platform_share
    into v_delivery_fee, v_delivery_fee_method, v_driver_share, v_platform_share
  from public.calculate_delivery_fee(
    v_service_id, v_merchant_lat, v_merchant_lng, v_address_lat, v_address_lng, v_commune_id
  );

  if jsonb_array_length(p_items) = 0 then
    raise exception 'لا يمكن إنشاء طلب فارغ';
  end if;

  -- إنشاء صف الطلب مبدئيًا بمبالغ المنتجات صفرية (سنحدّثها بعد حساب
  -- المنتجات كما كان الحال دائمًا)، لكن برسم التوصيل المحسوب فعليًا
  -- والفعليّة اللقطة (Snapshot) — تُكتَب هنا مرة واحدة فقط ولا تُلمَس
  -- ثانية فـ الـ UPDATE النهائي أدناه.
  insert into orders (
    customer_id, merchant_id, address_id, status,
    subtotal, commission_rate, platform_commission_amount,
    merchant_amount, delivery_fee, total_amount,
    delivery_fee_method, driver_earning_share, platform_delivery_share
  ) values (
    v_customer_id, p_merchant_id, p_address_id, 'pending',
    0, 0, 0, 0, v_delivery_fee, v_delivery_fee,
    v_delivery_fee_method, v_driver_share, v_platform_share
  ) returning id into v_order_id;

  -- المرور على كل منتج مطلوب، والتحقق من سعره وتوفره من الجدول الحقيقي
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, price, is_active, merchant_id into v_product
    from products
    where id = (v_item ->> 'product_id')::uuid;

    if v_product.id is null then
      raise exception 'منتج غير موجود';
    end if;

    if v_product.merchant_id <> p_merchant_id then
      raise exception 'كل منتجات الطلب يجب أن تكون من نفس المحل';
    end if;

    if not v_product.is_active then
      raise exception 'أحد المنتجات لم يعد متوفرًا حاليًا';
    end if;

    v_quantity := (v_item ->> 'quantity')::integer;
    v_line_subtotal := v_product.price * v_quantity;

    insert into order_items (order_id, product_id, quantity, unit_price, subtotal)
    values (v_order_id, v_product.id, v_quantity, v_product.price, v_line_subtotal);

    v_subtotal := v_subtotal + v_line_subtotal;
  end loop;

  select commission_rate_override into v_commission_rate
  from merchants where id = p_merchant_id;

  if v_commission_rate is null then
    select value::numeric into v_commission_rate
    from settings where key = 'platform_commission_rate';
  end if;

  v_platform_commission := round(v_subtotal * v_commission_rate / 100, 2);
  v_merchant_amount := v_subtotal - v_platform_commission;

  update orders set
    subtotal = v_subtotal,
    commission_rate = v_commission_rate,
    platform_commission_amount = v_platform_commission,
    merchant_amount = v_merchant_amount,
    total_amount = v_subtotal + v_delivery_fee
  where id = v_order_id;

  return v_order_id;
end;
$$;

comment on function public.create_order is 'الطريقة الآمنة الوحيدة لإنشاء طلب - تحسب كل الأرقام من قاعدة البيانات (بما فيها رسم التوصيل الآن، عبر calculate_delivery_fee)، لا تثق بأي رقم من العميل. نسبة العمولة: استثناء التاجر إن وُجد، وإلا الإعداد المركزي العام. يرفض الحسابات الموقوفة قبل أي شيء آخر.';

-- ============================================================
-- 10) admin_override_delivery_fee — يحلّ محلّ admin_set_delivery_fee،
--     سبب إلزامي، يُسجَّل تلقائيًا فـ admin_activity_log (نفس Trigger
--     log_orders_admin_activity الموجود أصلًا، بلا كود تسجيل جديد).
-- ============================================================

create function public.admin_override_delivery_fee(p_order_id uuid, p_new_fee numeric, p_reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_current_driver_share numeric(10, 2);
  v_new_driver_share numeric(10, 2);
begin
  if not public.has_capability('settings.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة الإعدادات';
  end if;

  if p_new_fee < 0 then
    raise exception 'رسوم التوصيل لا يمكن أن تكون سالبة';
  end if;

  if p_reason is null or trim(p_reason) = '' then
    raise exception 'يجب ذكر سبب التعديل';
  end if;

  select driver_earning_share into v_current_driver_share
  from orders where id = p_order_id;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  -- حصة الموصّل المُحدَّدة سابقًا قد تتجاوز الرسم الجديد الأصغر — نفس
  -- منطق الحماية من عدم سلبية حصة المنصة المُطبَّق فـ المحرك نفسه.
  v_new_driver_share := least(v_current_driver_share, p_new_fee);

  update orders set
    delivery_fee = p_new_fee,
    total_amount = subtotal + p_new_fee,
    delivery_fee_method = 'manual_override',
    driver_earning_share = v_new_driver_share,
    platform_delivery_share = p_new_fee - v_new_driver_share,
    delivery_fee_override_reason = p_reason
  where id = p_order_id;
end;
$$;

comment on function public.admin_override_delivery_fee is 'تعديل يدوي استثنائي على رسوم توصيل طلب موجود — سبب إلزامي. يستبدل admin_set_delivery_fee (محذوفة أدناه) التي لم تكن تفرض تسجيل سبب. القيمة القديمة/الجديدة تُسجَّل تلقائيًا فـ admin_activity_log بفضل log_orders_admin_activity الموجودة أصلًا على orders — لا كود تسجيل جديد.';

-- حذف صريح: تركها حيّة كان سيسمح لأدمن بتجاوز إلزامية السبب أعلاه عبر
-- استدعائها مباشرة. مستدعيها الوحيد فـ الكود (delivery-fee-form.tsx)
-- يُستبدَل فـ نفس هذه المرحلة.
drop function public.admin_set_delivery_fee(uuid, numeric);

-- ============================================================
-- 11) admin_upsert_delivery_fee_config / admin_set_delivery_fee_zone_
--     prices — مدخل الإدارة الوحيد للكتابة (RLS أعلاه تسمح بكتابة
--     مباشرة أيضًا لمن يملك settings.manage، لكن RPC هنا أبسط للواجهة
--     من صياغة upsert يدوي فـ كل مكوّن Next.js).
-- ============================================================

create function public.admin_upsert_delivery_fee_config(
  p_service_id uuid,
  p_method text,
  p_fixed_amount numeric,
  p_distance_base_amount numeric,
  p_distance_per_km_amount numeric,
  p_driver_share_type text,
  p_driver_share_value numeric,
  p_enabled boolean
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.has_capability('settings.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة الإعدادات';
  end if;

  insert into delivery_fee_configs (
    service_id, method, fixed_amount, distance_base_amount, distance_per_km_amount,
    driver_share_type, driver_share_value, enabled, updated_by, updated_at
  ) values (
    p_service_id, p_method, p_fixed_amount, p_distance_base_amount, p_distance_per_km_amount,
    p_driver_share_type, p_driver_share_value, p_enabled, auth.uid(), now()
  )
  on conflict (service_id) do update set
    method = excluded.method,
    fixed_amount = excluded.fixed_amount,
    distance_base_amount = excluded.distance_base_amount,
    distance_per_km_amount = excluded.distance_per_km_amount,
    driver_share_type = excluded.driver_share_type,
    driver_share_value = excluded.driver_share_value,
    enabled = excluded.enabled,
    updated_by = excluded.updated_by,
    updated_at = now();
end;
$$;

comment on function public.admin_upsert_delivery_fee_config is 'إنشاء/تحديث إعدادات رسوم التوصيل لخدمة واحدة — مدخل الإدارة الموصى به (RLS الجدول تسمح أيضًا بكتابة مباشرة، هذه فقط أبسط للواجهة).';

create function public.admin_set_delivery_fee_zone_prices(p_service_id uuid, p_prices jsonb)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_row jsonb;
begin
  if not public.has_capability('settings.manage') then
    raise exception 'هذا الإجراء متاح فقط لمن يملك صلاحية إدارة الإعدادات';
  end if;

  -- p_prices: [{"commune_id": 4001, "price": 200}, ...] — دفعة واحدة
  -- بدل جولة شبكة لكل بلدية.
  for v_row in select * from jsonb_array_elements(p_prices)
  loop
    insert into delivery_fee_zone_prices (service_id, commune_id, price, updated_by, updated_at)
    values (
      p_service_id,
      (v_row ->> 'commune_id')::integer,
      (v_row ->> 'price')::numeric,
      auth.uid(),
      now()
    )
    on conflict (service_id, commune_id) do update set
      price = excluded.price,
      updated_by = excluded.updated_by,
      updated_at = now();
  end loop;
end;
$$;

comment on function public.admin_set_delivery_fee_zone_prices is 'تحديث دفعة كاملة من أسعار البلديات لخدمة واحدة دفعة واحدة — يُستخدَم من جدول التسعير فـ لوحة الإدارة.';
