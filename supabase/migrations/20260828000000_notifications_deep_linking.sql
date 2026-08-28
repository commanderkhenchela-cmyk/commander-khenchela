-- ============================================================
-- Migration: Notification Deep Linking
-- (الخطوة 1+2 من "الترتيب المقترح للتنفيذ" في REQUIREMENTS GAP
-- ANALYSIS — فجوة صغيرة موثَّقة سابقًا: onTap على أي إشعار اليوم
-- يُعلِّمه كمقروء فقط، بلا أي انتقال لصاحب الإشعار الفعلي).
--
-- تمديد إضافي بحت (Additive) — لا تغيير على أي عمود موجود، لا كسر
-- لأي إشعار قديم (يبقى entity_type/entity_id = NULL له، والواجهة
-- تتعامل مع NULL بأمان: onTap يُعلِّم كمقروء فقط كما كان تمامًا،
-- بدون أي محاولة تنقّل).
--
-- entity_id نوعه text وليس uuid عمدًا: بعض الإشعارات مستقبلًا قد
-- تشير لسجلّ بمفتاح غير uuid (نفس قرار admin_activity_log.record_id
-- الموجود أصلًا بهذا النمط بالضبط).
-- ============================================================

alter table notifications add column entity_type text;
alter table notifications add column entity_id text;

comment on column notifications.entity_type is 'نوع الكيان المرتبط بالإشعار (order/merchant/driver...) — يُستخدَم للتنقّل المباشر عند الضغط على الإشعار. NULL للإشعارات القديمة أو العامة التي لا كيان محدَّد لها.';
comment on column notifications.entity_id is 'معرّف الكيان المرتبط (id السجل في جدوله)، يُقرأ مع entity_type معًا فقط.';
