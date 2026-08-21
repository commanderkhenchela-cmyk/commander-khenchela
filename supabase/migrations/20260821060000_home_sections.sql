-- ============================================================
-- Migration: أقسام الصفحة الرئيسية (Home Sections) — أساس تحكّم
-- الإدارة بمحتوى الصفحة الرئيسية بدل شبكة تصنيفات ثابتة واحدة.
--
-- تصميم مقصود: كتالوج أقسام محدود (section_key ثابت بعدد صغير من
-- الأنواع المعروفة)، وليس "منشئ صفحات" حر بأي محتوى — كل section_key
-- منطقه/استعلامه مكتوب في كود التطبيق (Dart)، لأن كل قسم يعتمد على
-- بيانات حقيقية مختلفة تمامًا (موقع جغرافي، عدد طلبات، تاريخ إنشاء...).
-- ما تتحكم به الإدارة فعليًا: أي الأقسام تظهر، بأي ترتيب، وبأي عنوان —
-- هذا هو الطلب الفعلي ("إضافة/حذف/إخفاء/ترتيب/تغيير عنوان")، ديناميكي
-- بالكامل بدون الحاجة لتعديل كود لتغيير الظهور أو الترتيب أو النص.
-- ============================================================

create table home_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text not null unique check (section_key in (
    'hero', 'categories', 'featured', 'nearby', 'newest', 'most_ordered'
  )),
  title text not null,
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table home_sections is 'يتحكّم بأقسام الصفحة الرئيسية لتطبيق العميل: أيها يظهر، بأي ترتيب، وبأي عنوان. القسم يُخفى تلقائيًا في التطبيق أيضًا إذا لم توجد له بيانات حقيقية كافية (راجع كود home_screen)، حتى لو كان is_active.';

create index home_sections_sort_order_idx on home_sections (sort_order);

alter table home_sections enable row level security;

create policy "home_sections_select_public"
  on home_sections for select
  using (is_active = true);

create policy "home_sections_admin_all"
  on home_sections for all
  using (public.can_manage_stores())
  with check (public.can_manage_stores());

create trigger log_home_sections_admin_activity
  after insert or update or delete on home_sections
  for each row execute function public.log_admin_activity();

insert into home_sections (section_key, title, sort_order) values
  ('hero', 'إعلانات ومحتوى مميّز', 1),
  ('categories', 'تصفّح حسب التصنيف', 2),
  ('featured', 'متاجر مميزة', 3),
  ('nearby', 'بالقرب منك', 4),
  ('newest', 'جديد في خنشلة', 5),
  ('most_ordered', 'الأكثر طلبًا', 6);
