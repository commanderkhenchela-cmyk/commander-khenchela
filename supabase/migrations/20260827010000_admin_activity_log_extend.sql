-- ============================================================
-- Migration: PHASE — ADMIN CONTROL CENTER FOUNDATION (2/2)
-- توسيع Activity Log الموجود (لا نظام Audit موازٍ جديد).
--
-- 1) عمود source (nullable, إضافي) — يحضّر الحقل المطلوب مستقبلًا
--    (مصدر الإجراء: admin-dashboard/merchant-dashboard/mobile...).
--    لا شيء يكتب فيه بعد هذا الملف — يبقى NULL حتى تُحدَّث نقاط
--    الكتابة لاحقًا لتمريره صراحةً. توثيق هذا صراحة حتى لا يُفهَم
--    خطأً أن "Source" يعمل فعليًا اليوم.
--
-- 2) توسيع تغطية log_admin_activity() لتشمل جدول orders — كان مفقودًا:
--    admin_set_delivery_fee يُحدِّث orders.delivery_fee بلا أي تسجيل.
--    نفس الدالة العامة الموجودة أصلًا (log_admin_activity) تُستخدَم
--    حرفيًا، فقط Trigger جديد يربطها — لا دالة جديدة.
--
--    ملاحظة أمان الأداء: log_admin_activity() نفسها تُنهي التنفيذ
--    فورًا (return coalesce(new,old)) لأي فاعل ليس أحد أدوار لوحة
--    الإدارة الثلاثة — أي تحديث طلب من تاجر/عميل/موصّل (وهو الأغلبية
--    الساحقة لتحديثات orders) يمرّ بفحص EXISTS واحد سريع (بحث بالمفتاح
--    الأساسي على users.id) ثم يتوقف بلا أي INSERT — نفس النمط المُثبَت
--    فعلًا على merchants/categories/advertisements منذ عدة migrations.
--
-- 3) settings عمدًا غير مربوط هنا: مفتاحها الأساسي `key` وليس `id`،
--    ودالة log_admin_activity() تفترض `new.id` — ربطها بها كما هي
--    سيفشل وقت التنفيذ. تحتاج Trigger مخصَّصًا منفصلًا لاحقًا، وليس
--    ضرورية الآن (سجل يدوي عبر Settings Form كافٍ حاليًا لإعداد واحد).
-- ============================================================

alter table admin_activity_log add column source text;

comment on column admin_activity_log.source is 'مصدر الإجراء (مثلًا admin-dashboard) — عمود مُحضَّر للمستقبل، لا شيء يكتب قيمة فيه بعد؛ يبقى NULL حتى تُحدَّث نقاط الكتابة صراحةً.';

create trigger log_orders_admin_activity
  after update on orders
  for each row execute function public.log_admin_activity();

-- نفس الفجوة موجودة في drivers أيضًا (لوحظت أثناء بناء عرض النشاط
-- الخاص بكل موصّل في هذه المرحلة): جدول drivers لم يُربَط قط بـ
-- log_admin_activity() منذ إنشائه (migration 20260822010000) — قرارات
-- اعتماد/رفض الموصّلين اليوم غير مسجَّلة في سجل النشاطات إطلاقًا. نفس
-- الدالة العامة الموجودة، فقط Trigger جديد.
create trigger log_drivers_admin_activity
  after update on drivers
  for each row execute function public.log_admin_activity();

-- ============================================================
-- توحيد إضافي (بدون كسر السلوك): log_admin_activity() كانت تتحقّق من
-- الفاعل بشرط `role = 'admin'` مباشرة (مكتوب داخل الدالة نفسها منذ
-- migration 20260820080000)، بدل استدعاء is_admin() الموجودة أصلًا —
-- وهي بالضبط نفس الحالة التي طلب صاحب المشروع مراجعتها في
-- admin_set_delivery_fee وأخواتها. is_admin() تُعرَّف حرفيًا كـ
-- `role = 'admin'` (راجع 20260820040000) — لا فرق في السلوك إطلاقًا،
-- توحيد فلسفة فقط. باقي الدالة (تحديد الإجراء، التقاط JSONB
-- before/after، الإدراج في السجل) بلا أي تغيير.
-- ============================================================

create or replace function public.log_admin_activity()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_admin_name text;
  v_action text;
  v_record_id text;
  v_changes jsonb;
begin
  if not public.is_admin() then
    return coalesce(new, old);
  end if;

  select full_name into v_admin_name from users where id = v_admin_id;

  if TG_OP = 'INSERT' then
    v_action := 'إنشاء';
    v_record_id := new.id::text;
    v_changes := to_jsonb(new);
  elsif TG_OP = 'UPDATE' then
    v_action := 'تعديل';
    v_record_id := new.id::text;
    v_changes := jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new));
  elsif TG_OP = 'DELETE' then
    v_action := 'حذف';
    v_record_id := old.id::text;
    v_changes := to_jsonb(old);
  end if;

  insert into admin_activity_log (admin_id, admin_name, action, table_name, record_id, changes)
  values (v_admin_id, coalesce(v_admin_name, ''), v_action, TG_TABLE_NAME, v_record_id, v_changes);

  return coalesce(new, old);
end;
$$;
