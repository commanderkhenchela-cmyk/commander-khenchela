-- ============================================================
-- Migration: أنواع مركبات الموصّلين — دراجة / سيارة (Taxi) / شاحنة
--
-- الوضع قبل هذه الـmigration (فجوة حقيقية اكتُشفت اليوم): drivers.
-- vehicle_type كان مقفولًا تقنيًا على 'bike' فقط منذ الإنشاء (migration
-- 20260822010000)، بتعليق صريح "سيارات الأجرة مرحلة قادمة منفصلة".
-- لكن Taxi (migration 20260906000000) بُنيت لاحقًا وأعادت استخدام نفس
-- جدول drivers بالضبط — والسياسات الثلاث (orders_select_driver_pool،
-- delivery_requests_select_driver_pool، ride_requests_select_driver_pool)
-- كلها تتحقق فقط من status='approved'، بلا أي فحص لنوع المركبة. النتيجة
-- العملية: أي موصّل دراجة يرى (ويقدر تقنيًا يقبل) طلبات Taxi أيضًا —
-- خلل منطقي حقيقي (الدراجة لا تحمل راكبًا).
--
-- القرار (بالاتفاق مع صاحب المنصّة):
--   1) توسيع vehicle_type لثلاث قيم: bike / car / truck.
--   2) orders و"اطلب أي شيء" (delivery_requests) يبقيان حصريًا على
--      الدراجات (bike) — طرود صغيرة، لا حاجة لسيارة.
--   3) Taxi (ride_requests) حصريًا على السيارات (car).
--   4) 'truck' = حجز تسمية لخدمة "التوصيل بالشاحنات/شاحنات المياه"
--      المستقبلية المحجوزة (راجع migration 20260908000000 لنفس القرار
--      على مستوى services.name) — يمكن للموصّل اختيارها والتسجيل بها
--      *الآن*، لكن لا يوجد أي مجمّع طلبات لها بعد لأن الخدمة نفسها غير
--      مبنية؛ الموصّل يبقى "بانتظار" الخدمة نفسها لا "بانتظار الموافقة"
--      (الموافقة على هويته منفصلة تمامًا عن توفّر عمل فعلي لنوعه).
--
-- vehicle_type يبقى غير قابل للتعديل الذاتي بعد التسجيل (trigger
-- protect_driver_status الموجود أصلًا يغطّي هذا فعلًا بلا أي تعديل
-- هنا — يعمل على أي قيمة عمود، لا فقط 'bike') — فقط الإدارة تقدر
-- تغيّره لاحقًا.
-- ============================================================

alter table drivers drop constraint if exists drivers_vehicle_type_check;
alter table drivers add constraint drivers_vehicle_type_check
  check (vehicle_type in ('bike', 'car', 'truck'));

comment on column drivers.vehicle_type is 'bike = طرود صغيرة (orders + اطلب أي شيء). car = Taxi (ride_requests). truck = شاحنات شحن/مياه، حجز تسمية لخدمة مستقبلية غير مبنية بعد — لا مجمّع طلبات لها اليوم. غير قابل للتعديل الذاتي بعد التسجيل (protect_driver_status).';

comment on table drivers is 'حسابات الموصّلين — دراجات وسيارات Taxi وشاحنات (الأخيرة حجز تسمية فقط، راجع تعليق migration 20260910000000). كل نوع يرى مجمّع طلباته الخاص فقط عبر RLS، لا تداخل بين الأنواع.';

-- ============================================================
-- تحديث مجمّعات الطلبات الثلاثة — إضافة فلتر نوع المركبة. لا CREATE OR
-- REPLACE للسياسات (Postgres لا يدعمها لتغيير USING) — DROP ثم CREATE.
-- ============================================================

drop policy if exists "orders_select_driver_pool" on orders;
create policy "orders_select_driver_pool"
  on orders for select
  using (
    status = 'ready_for_pickup'
    and driver_id is null
    and exists (
      select 1 from drivers d
      where d.user_id = auth.uid() and d.status = 'approved' and d.vehicle_type = 'bike'
    )
  );

drop policy if exists "delivery_requests_select_driver_pool" on delivery_requests;
create policy "delivery_requests_select_driver_pool"
  on delivery_requests for select
  using (
    status = 'pending'
    and driver_id is null
    and exists (
      select 1 from drivers d
      where d.user_id = auth.uid() and d.status = 'approved' and d.vehicle_type = 'bike'
    )
  );

drop policy if exists "ride_requests_select_driver_pool" on ride_requests;
create policy "ride_requests_select_driver_pool"
  on ride_requests for select
  using (
    status = 'pending'
    and driver_id is null
    and exists (
      select 1 from drivers d
      where d.user_id = auth.uid() and d.status = 'approved' and d.vehicle_type = 'car'
    )
  );

-- عنوانا الانطلاق/الوجهة فـ مجمّع Taxi (قبل القبول) — كانت مرئية لأي
-- موصّل approved بلا فحص نوع، نفس الفجوة بالضبط على مستوى addresses.
-- دفاع بعمق يطابق ride_requests_select_driver_pool أعلاه تمامًا.
drop policy if exists "addresses_select_driver_via_ride_pool" on addresses;
create policy "addresses_select_driver_via_ride_pool"
  on addresses for select
  using (
    exists (
      select 1 from ride_requests r
      where (r.pickup_address_id = addresses.id or r.dropoff_address_id = addresses.id)
        and r.status = 'pending'
        and r.driver_id is null
        and exists (
          select 1 from drivers d
          where d.user_id = auth.uid() and d.status = 'approved' and d.vehicle_type = 'car'
        )
    )
  );
