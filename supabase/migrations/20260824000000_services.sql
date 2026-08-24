-- ============================================================
-- Migration: بنية "الخدمات" (Services Architecture) — قسم الرئيسية
-- الجديد + جاهزية Taxi/Delivery/Craftsmen مستقبلًا بدون كسر أي شيء.
--
-- لماذا جدول جديد وليس توسيع home_sections أو merchant_categories؟
-- راجعتُ الاثنين قبل الكتابة:
--   - home_sections: كتالوج أقسام *عرض محتوى* داخل صفحة خدمة واحدة
--     (Marketplace) — section_key مقيَّد بقيم مرتبطة بمنطق Marketplace
--     تحديدًا (hero/featured/nearby...)، مفهوم مختلف تمامًا عن "خدمة".
--   - merchant_categories: تصنيفات *داخل* Marketplace (بقالة، مطاعم...)
--     — المطاعم فعليًا صفّ واحد هنا بالفعل (راجع الأسفل)، وليست خدمة
--     منفصلة على مستوى التطبيق.
-- لا بنية موجودة تمثّل "نوع الخدمة الأعلى" (تسوّق مقابل توصيل ركّاب
-- مقابل حرفيين...) — هذا مفهوم جديد فعليًا، فجدول services مبرَّر.
--
-- تصميم مقصود يطابق قرار المشروع: enabled=false لا يعني "مبني وغير
-- مفعَّل" بل "غير موجود بعد" لـ taxi/delivery/craftsmen — التطبيق
-- (customer_app) يحمل قائمة الخدمات *المبنية فعليًا* داخل الكود نفسه
-- (raw hardcoded set صغير، لأنه قرار برمجي لا بيانات)، ويعرض "قريبًا"
-- لأي خدمة enabled لكن غير موجودة في تلك القائمة بعد — هذا يمنع دخول
-- المستخدم لميزة غير مكتملة حتى لو فعّلها الأدمن بالخطأ قبل اكتمال
-- بنائها فعليًا.
-- ============================================================

create table services (
  id uuid primary key default gen_random_uuid(),
  -- مجموعة مغلقة معروفة مسبقًا (نفس نمط home_sections.section_key) —
  -- إضافة خدمة جديدة فعليًا تتطلب أصلًا كتابة كودها في التطبيق، فلا
  -- فائدة من slug حر بلا قيد.
  slug text not null unique check (slug in (
    'marketplace', 'restaurants', 'taxi', 'delivery', 'craftsmen'
  )),
  name text not null,
  -- إيموجي كنص، نفس نمط merchant_categories.icon تمامًا — بدون أي حزمة
  -- أيقونات إضافية، قابل للتعديل من لوحة الإدارة كنص عادي.
  icon text not null,
  description text,
  enabled boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table services is 'الخدمات الأعلى مستوى في التطبيق (تسوّق، مطاعم، طاكسي، توصيل، حرفيون). enabled يتحكّم به الأدمن من لوحة الإدارة مباشرة. "مبنية فعليًا" أمر مختلف تمامًا يُحدَّد داخل كود customer_app (راجع تعليق أعلى الملف) — لا تخلط الاثنين.';

create index services_sort_order_idx on services (sort_order);

-- ---------- تحديث updated_at تلقائيًا عند أي تعديل ----------
create function public.set_services_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger services_set_updated_at
  before update on services
  for each row execute function public.set_services_updated_at();

-- ---------- RLS ----------
alter table services enable row level security;

create policy "services_select_public"
  on services for select
  using (enabled = true);

create policy "services_admin_all"
  on services for all
  using (public.can_manage_stores())
  with check (public.can_manage_stores());

-- ---------- سجلّ نشاط الإدارة (نفس الدالة العامة الموجودة أصلًا) ----------
create trigger log_services_admin_activity
  after insert or update or delete on services
  for each row execute function public.log_admin_activity();

-- ---------- البيانات الأولية ----------
-- التسوّق والمطاعم مفعَّلان فورًا (مبنيان فعليًا وجاهزان — المطاعم عبر
-- تصنيف "مطاعم" الموجود أصلًا داخل merchant_categories، بدون أي نظام
-- Restaurants مستقل). الثلاثة الباقية معطَّلة عمدًا — قرار محسوم سابقًا.
insert into services (slug, name, icon, description, enabled, sort_order) values
  ('marketplace', 'التسوّق', '🛍️', 'تسوّق من محلات خنشلة', true, 1),
  ('restaurants', 'المطاعم', '🍔', 'اطلب من مطاعم خنشلة', true, 2),
  ('taxi', 'الطاكسي', '🚕', 'احجز رحلتك القادمة', false, 3),
  ('delivery', 'التوصيل', '📦', 'أرسل طردك بسرعة', false, 4),
  ('craftsmen', 'الحرفيون', '🔧', 'خدمات وحرفيّون قريبون منك', false, 5);
