-- ============================================================
-- Migration: إضافة "الأكثر مشاهدة" كقسم رسمي في كتالوج home_sections —
-- ممكن الآن بعد بناء تتبّع views_count الحقيقي (راجع
-- 20260821100000_merchant_views.sql). كان هذا القسم مستبعدًا صراحةً من
-- إعادة بناء الصفحة الرئيسية الأولى لعدم وجود بيانات حقيقية تدعمه.
-- ============================================================

alter table home_sections drop constraint if exists home_sections_section_key_check;
alter table home_sections add constraint home_sections_section_key_check
  check (section_key in (
    'hero', 'categories', 'featured', 'nearby', 'newest', 'most_ordered', 'most_viewed'
  ));

insert into home_sections (section_key, title, sort_order)
values ('most_viewed', 'الأكثر مشاهدة', 7)
on conflict (section_key) do nothing;
