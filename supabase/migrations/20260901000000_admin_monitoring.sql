-- ============================================================
-- Migration: Admin Monitoring — تتبّع موحَّد للطلب (PRD section 24)
--
-- "أريد Admin أن تكون قادرة على تتبع المنظومة ككل: Customer → Order →
-- Merchant → Driver → GPS → Payment/Wallet → Commission → Notification
-- → Fraud." كل هذه البيانات موجودة أصلًا فـ جداول منفصلة (users،
-- orders، merchants، drivers، wallet_transactions، notifications،
-- fraud_cases) — هذه المرحلة لا تُنشئ أي جدول جديد، فقط تفتح للإدارة
-- قراءة الجدول الوحيد الناقص صلاحية القراءة الإدارية عنه: notifications
-- (كان القارئ الوحيد المسموح هو صاحب الإشعار نفسه). كل الجداول الأخرى
-- (wallet_transactions، fraud_cases، drivers، merchants، users) لديها
-- أصلًا Policy قراءة إدارية كافية من المراحل السابقة.
--
-- الحارس هنا عمدًا is_admin() مباشرة، وليس
-- has_capability('notification.view'): تلك الصلاحية مُهيَّأة اليوم
-- لغرض مختلف تمامًا (إظهار رابط "🔔 الإشعارات" فـ التنقّل للأدوار
-- الثلاثة — لا علاقة له بقراءة إشعارات مستخدمين آخرين). استخدامها هنا
-- كان سيمنح manager/ads_manager بالخطأ قدرة قراءة إشعارات أي مستخدم
-- عبر REST مباشرة، رغم أن صفحة تفاصيل الطلب (الوحيدة التي تستهلك هذا)
-- محصورة أصلًا بـ Super Admin. is_admin() يطابق الحاجة الفعلية بدقة.
-- ============================================================

create policy "notifications_select_admin"
  on notifications for select
  using (public.is_admin());

comment on policy "notifications_select_admin" on notifications is 'يسمح لـ Super Admin فقط بقراءة إشعارات أي مستخدم — ضروري لعرض "الإشعارات المرتبطة بهذا الطلب" فـ صفحة تفاصيل الطلب الموحَّدة (محصورة هي نفسها بـ Super Admin). عمدًا is_admin() لا has_capability(\'notification.view\') — تلك مُهيَّأة لغرض مختلف (إظهار رابط تنقّل)، استخدامها هنا كان سيوسّع صلاحية manager/ads_manager بالخطأ.';
