-- ============================================================
-- Migration: تفعيل شبكة الإشعارات لكل الأطراف (التاجر + الإدارة)
-- بدل الزبون فقط.
--
-- لا نظام جديد هنا — امتداد لنفس الأنبوب الموجود من PHASE 11:
-- trigger → net.http_post → Edge Function send-order-notification →
-- صفّ في جدول notifications (يُقرأ فورًا داخل التطبيق، بغض النظر عن
-- نجاح/فشل Push الخارجي). الدالة public.notify_order_webhook() عامة
-- فعليًا (تستخدم tg_table_name/to_jsonb(new/old) ديناميكيًا)، فنعيد
-- استخدامها حرفيًا على جدول merchants بدل تكرار كودها.
--
-- فرع drivers (تسجيل/موافقة موصّل) يُضاف لاحقًا مع migration جدول
-- drivers نفسه — لا داعي لتحضيره الآن لجدول غير موجود بعد.
-- ============================================================

create trigger merchants_notify_webhook
  after insert or update on merchants
  for each row execute function public.notify_order_webhook();

comment on trigger merchants_notify_webhook on merchants is 'يستدعي نفس Edge Function المستخدمة لإشعارات الطلبات (send-order-notification) عند تسجيل تاجر جديد أو تغيّر حالة محله — إشعار الإدارة بتاجر جديد بانتظار الموافقة، وإشعار التاجر بنتيجة المراجعة.';

-- ---------- تفعيل Realtime على notifications ----------
-- حتى تتحدّث شارة "غير مقروء" في كل تطبيق لحظيًا بدون Refresh يدوي.
-- لا بنية جديدة — تفعيل قياسي لميزة Supabase موجودة أصلًا في المشروع
-- (Realtime كانت جزءًا من التقنيات المعتمدة من البداية، لم تُستخدم بعد).
alter publication supabase_realtime add table notifications;
