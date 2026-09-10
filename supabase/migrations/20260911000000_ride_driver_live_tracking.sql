-- ============================================================
-- Migration: تتبّع حيّ لموقع الموصّل أثناء رحلة Taxi
--
-- الوضع قبل هذه الـmigration: drivers.current_lat/current_lng يُحدَّثان
-- أصلًا كل 60 ثانية أثناء "متصل" (DriverService.pingLocation فـ
-- driver_app، لا تتبّع جديد مطلوب هنا) — لكن العميل لا يملك أي صلاحية
-- قراءة لصفّ drivers إطلاقًا (السياستان الوحيدتان الموجودتان:
-- drivers_select_own وdrivers_select_admin) — حتى اسم/هاتف الموصّل
-- المعيَّن لرحلته لا يراهما العميل اليوم، فضلًا عن موقعه.
--
-- الإصلاح: سياسة قراءة واحدة جديدة، مقيَّدة بدقّة — العميل يرى صفّ
-- الموصّل *فقط* إن كان معيَّنًا فعليًا لرحلة يملكها هو، و*فقط* أثناء
-- المرحلتين accepted/in_progress (الرحلة فعليًا جارية أو قادمة). بمجرّد
-- completed/cancelled تختفي الرؤية تلقائيًا — لا حاجة لحذف أو تنظيف
-- يدوي، RLS نفسها تتوقّف. هذا يحمي خصوصية الموصّل (موقعه ليس مرئيًا
-- لعملاء سابقين بعد انتهاء علاقتهم به).
--
-- لا حماية على مستوى العمود هنا (نفس نمط بقية هذا المشروع بالكامل —
-- لا سابقة لـ column-level GRANT/REVOKE فـ أي migration سابقة)، فالعميل
-- يقدر تقنيًا يطلب id_card_path لو صاغ استعلامًا خامًا — لكن القيمة
-- بلا فائدة عمليًا بدونه: توليد رابط موقَّع لها (createSignedUrl) يتم
-- حصريًا من سياق الإدارة (admin-dashboard) على bucket خاص
-- (driver-documents)، لا صلاحية عميل هناك مطلقًا. العميل الفعلي يقرأ
-- فقط الأعمدة التي يختارها فـ .select() (نفس انضباط بقية هذا المشروع).
--
-- النطاق: ride_requests (Taxi) فقط الآن — نفس الفجوة/الحاجة موجودة
-- بنيويًا فـ orders وdelivery_requests (موصّل الدراجة) أيضًا، تُركت
-- عمدًا لمتابعة لاحقة منفصلة حتى يثبت هذا النمط عمليًا أولًا، تمامًا
-- كما تركت migration 20260910000000 توسيع أنواع المركبات لهذا النطاق
-- بالذات.
-- ============================================================

create policy "drivers_select_via_assigned_ride"
  on drivers for select
  using (
    exists (
      select 1 from ride_requests r
      where r.driver_id = drivers.id
        and r.customer_id = auth.uid()
        and r.status in ('accepted', 'in_progress')
    )
  );

comment on policy "drivers_select_via_assigned_ride" on drivers is 'يسمح للعميل برؤية صفّ الموصّل المعيَّن لرحلته (اسم/هاتف/موقعه الحيّ) فقط أثناء accepted/in_progress — تختفي تلقائيًا عند completed/cancelled، بلا أي عملية تنظيف يدوية.';

-- ============================================================
-- تفعيل Realtime على drivers — لم يكن مضافًا للشبكة العامة إطلاقًا فـ
-- أي migration سابقة (مقارنة بـ orders/delivery_requests/ride_requests/
-- craftsman_requests، كلها مضافة). بدونه، تحديثات current_lat/
-- current_lng لن تصل للعميل حيًّا مهما كانت RLS صحيحة — Realtime
-- يتطلّب كلا الأمرين معًا (نشر الجدول + RLS تسمح بالصفّ).
-- ============================================================
alter publication supabase_realtime add table drivers;
