-- ============================================================
-- Migration: إصلاح تكرار لا نهائي (infinite recursion) بين سياسات
-- drivers وride_requests
--
-- خلل حقيقي مكتشَف مباشرة من Postgres Logs (رمز الخطأ 42P17):
--   "infinite recursion detected in policy for relation drivers"
--
-- السبب الجذري: حلقة مرجعية بين migration منفصلتين، كل واحدة منهما
-- صحيحة بمفردها لكن معًا تُنتج دورة:
--   1) 20260910000000: سياسة ride_requests_select_driver_pool (على
--      ride_requests) تستعلم عن drivers مباشرة فـ USING.
--   2) 20260911000000: سياسة drivers_select_via_assigned_ride (على
--      drivers) تستعلم عن ride_requests مباشرة فـ USING.
--
-- أي SELECT على drivers (حتى لو مصدره RLS بسيط كـ drivers_select_own —
-- كل السياسات المسموحة (permissive) تُقيَّم كلها، لا سياسة واحدة فقط)
-- يستدعي تقييم drivers_select_via_assigned_ride، الذي يستعلم
-- ride_requests، الذي بدوره يستدعي تقييم ride_requests_select_driver_pool،
-- الذي يستعلم drivers من جديد ← حلقة لا نهائية. هذا يكسر عمليًا أي
-- قراءة لجدول drivers فـ كل التطبيقات (ظهر أولًا فـ onboarding_screen.dart
-- بعد INSERT مباشرة، لكنه يؤثر على أي SELECT آخر بنفس القدر: قائمة
-- الموصّلين فـ admin-dashboard، جلب صفّ الموصّل الخاص، إلخ).
--
-- الإصلاح: تفكيك الحلقة عبر دالة SECURITY DEFINER واحدة (نفس نمط
-- can_manage_stores()/driver_claim_order() المستخدَم أصلًا فـ هذا
-- المشروع) — تُنفَّذ بصلاحية مالك الدالة (يتجاوز RLS)، فاستعلامها عن
-- ride_requests من داخلها لا يُعيد تفعيل سياسات ride_requests، ومنه لا
-- يُعيد استدعاء سياسة drivers من جديد. لا تغيير فـ المنطق الفعلي
-- للسياسة (نفس الشرط بالحرف)، فقط كسر إعادة الدخول فـ تقييم RLS.
-- ============================================================

create function public.customer_has_active_ride_with_driver(p_driver_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from ride_requests r
    where r.driver_id = p_driver_id
      and r.customer_id = auth.uid()
      and r.status in ('accepted', 'in_progress')
  );
$$;

comment on function public.customer_has_active_ride_with_driver is 'يفحص إن كان العميل الحالي يملك رحلة نشطة (accepted/in_progress) مع هذا الموصّل — SECURITY DEFINER عمدًا لتفادي تكرار لا نهائي مع سياسات ride_requests (راجع تعليق هذا الـ migration للتفصيل الكامل).';

drop policy if exists "drivers_select_via_assigned_ride" on drivers;
create policy "drivers_select_via_assigned_ride"
  on drivers for select
  using (public.customer_has_active_ride_with_driver(drivers.id));

comment on policy "drivers_select_via_assigned_ride" on drivers is 'يسمح للعميل برؤية صفّ الموصّل المعيَّن لرحلته (اسم/هاتف/موقعه الحيّ) فقط أثناء accepted/in_progress — عبر دالة SECURITY DEFINER لتفادي تكرار RLS لا نهائي مع ride_requests، لا تغيير فـ الشرط نفسه عن النسخة الأصلية.';
