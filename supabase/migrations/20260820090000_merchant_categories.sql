-- ============================================================
-- Migration: تصنيفات المحلات (Merchant Categories) — PHASE 6 تحسين كبير
--
-- تنبيه مهم: هذا جدول جديد ومختلف تمامًا عن جدول categories الموجود
-- سابقًا (Phase 1) — ذاك الجدول لتصنيف المنتجات *داخل* محل واحد (مثل
-- "ألبان"، "مشروبات" داخل بقالة معيّنة). هذا الجدول الجديد لتصنيف
-- المحلات *نفسها* على مستوى التطبيق (مطاعم، بقالة، صيدليات...) — حتى
-- لا يتصفح العميل قائمة واحدة مختلطة لكل المحلات.
--
-- كل محل ينتمي لتصنيف رئيسي واحد فقط في V1 (Subcategories/تصنيفات
-- فرعية مؤجَّلة عمدًا — العمود parent_id أدناه يجهّز البنية لها لاحقًا
-- بدون أي تعديل على الجداول الحالية، لكن لا واجهة لها بعد).
-- ============================================================

create table merchant_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- إيموجي كأيقونة: يعرض فورًا في Flutter والويب بدون أي حزمة أيقونات
  -- إضافية أو رفع ملفات صور، ويبقى قابلاً للتغيير من لوحة الإدارة كنص.
  icon text not null default '🛍️',
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  parent_id uuid references merchant_categories (id),
  created_at timestamptz not null default now()
);

comment on table merchant_categories is 'تصنيفات المحلات (مطاعم، بقالة، صيدليات...) — تُدار بالكامل من لوحة الإدارة، وليست Hardcoded في أي تطبيق';

create index merchant_categories_parent_id_idx on merchant_categories (parent_id);

alter table merchant_categories enable row level security;

create policy "merchant_categories_public_read"
  on merchant_categories for select
  using (is_active = true);

create policy "merchant_categories_admin_all"
  on merchant_categories for all
  using (public.is_admin())
  with check (public.is_admin());

create trigger log_merchant_categories_admin_activity
  after insert or update or delete on merchant_categories
  for each row execute function public.log_admin_activity();

-- ---------- ربط كل محل بتصنيفه الرئيسي ----------

alter table merchants add column category_id uuid references merchant_categories (id);

create index merchants_category_id_idx on merchants (category_id);

-- ---------- تصنيفات V1 الأساسية (يمكن للإدارة إضافة المزيد لاحقًا) ----------

insert into merchant_categories (name, icon, sort_order) values
  ('مطاعم', '🍔', 1),
  ('بقالة ومواد غذائية', '🛒', 2),
  ('مشروبات ومقاهي', '☕', 3),
  ('الجمال والعناية', '💄', 4),
  ('الملابس والأزياء', '👕', 5),
  ('الصحة والصيدليات', '💊', 6),
  ('الإلكترونيات', '📱', 7),
  ('المنزل', '🏠', 8),
  ('المخابز والحلويات', '🥖', 9),
  ('العطور', '🧴', 10),
  ('أكشاك', '🚬', 11),
  ('خدمات', '🔧', 12),
  ('متاجر متنوعة', '🛍️', 13);
