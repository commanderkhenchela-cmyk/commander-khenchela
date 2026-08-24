-- ============================================================
-- Migration: ربط "تصنيفات المحلات" بـ"الخدمات" — Service != Category
--
-- قرار معماري صريح: الخدمة (services) مستوى أعلى من التصنيف
-- (merchant_categories). "مطاعم" لم تعد تصنيفًا مستقلاً بجانب "بقالة"
-- و"ملابس" — أصبحت *هي* خدمة "Restaurants" نفسها، وتصنيفاتها الفرعية
-- (بيتزا، مشاوي...) تصنيفات *داخل* هذه الخدمة تحديدًا عبر parent_id
-- الموجود أصلاً بالجدول (كان محجوزًا لهذا الغرض بالضبط منذ
-- migration 20260820090000، غير مُستخدَم حتى الآن).
--
-- لا حذف لأي بيانات: كل تصنيف موجود يبقى، فقط يُضاف له service_id.
-- ============================================================

alter table merchant_categories add column service_id uuid references services (id);

-- ---------- تعيين تصنيف "مطاعم" الحالي لخدمة Restaurants ----------
update merchant_categories
set service_id = (select id from services where slug = 'restaurants')
where name = 'مطاعم';

-- ---------- بقية التصنيفات الحالية تتبع خدمة Shopping ----------
update merchant_categories
set service_id = (select id from services where slug = 'marketplace')
where service_id is null;

-- من الآن فصاعدًا كل تصنيف جديد يجب أن يتبع خدمة معروفة صراحة —
-- الإدارة تختار الخدمة عند إنشاء أي تصنيف جديد.
alter table merchant_categories alter column service_id set not null;

create index merchant_categories_service_id_idx on merchant_categories (service_id);

comment on column merchant_categories.service_id is 'الخدمة التي ينتمي إليها هذا التصنيف (Shopping أو Restaurants حاليًا). راجع services.slug.';
comment on column merchant_categories.parent_id is 'تصنيف أب اختياري — يُستخدم الآن فعليًا لتصنيفات المطاعم الفرعية (بيتزا/وجبات سريعة...) تحت تصنيف "مطاعم" الرئيسي، بعد أن كان محجوزًا بلا استخدام.';

-- ---------- تصنيفات فرعية جديدة لخدمة المطاعم ----------
-- (تبدأ بلا محلات مرتبطة بها — الإدارة تُعيد تصنيف المحلات المناسبة
-- إليها لاحقًا من لوحة الإدارة، هذا عمل بيانات وليس عمل كود).
insert into merchant_categories (name, icon, sort_order, service_id, parent_id)
select
  sub.name,
  sub.icon,
  sub.sort_order,
  (select id from services where slug = 'restaurants'),
  (select id from merchant_categories where name = 'مطاعم')
from (
  values
    ('بيتزا', '🍕', 1),
    ('وجبات سريعة', '🍟', 2),
    ('مشاوي ودجاج', '🍗', 3),
    ('مقاهي', '☕', 4),
    ('حلويات', '🍰', 5)
) as sub(name, icon, sort_order);

-- ---------- إخفاء قسم "تصفّح حسب التصنيف" من الصفحة الرئيسية ----------
-- قرار UX محسوم: الرئيسية تعرض "الخدمات" فقط، لا شبكة تصنيفات مباشرة.
-- إخفاء لا حذف — الصف والـsection_key يبقيان موجودين، قابلان لإعادة
-- التفعيل من لوحة الإدارة لو تغيّر القرار مستقبلاً (نفس فلسفة home_sections
-- بأكملها: is_active يتحكّم بالظهور بدون أي حذف).
update home_sections set is_active = false where section_key = 'categories';
