-- ============================================================
-- Migration: هوية التطبيق القابلة للتعديل من لوحة الإدارة (الشعار،
-- اسم التطبيق، اللون الأساسي) — بدون الحاجة لتعديل كود Flutter.
--
-- لماذا جدول منفصل عن settings وليس إضافة إليه؟ لأن settings مغلق
-- عمدًا أمام أي قراءة من العميل (عمولة المنصة بيانات حساسة). بيانات
-- الهوية هنا عكس ذلك تمامًا: يجب أن يقرأها أي زائر لتطبيق الزبون حتى
-- قبل تسجيل الدخول (لعرض الشعار في شاشة البداية) — لذلك قراءة عامة،
-- وكتابة محصورة بالإدارة فقط عبر is_admin() (نفس الدالة من migration
-- سابقة، تتجاوز RLS بأمان بدل تكرار مشكلة الاستدعاء الذاتي).
--
-- صف واحد ثابت (id = 'default') يكفي — لا حاجة لعدة صفوف.
-- ============================================================

create table app_branding (
  id text primary key default 'default',
  app_name text not null default 'كوموندور خنشلة',
  logo_url text,
  primary_color text not null default '#1B7A3D',
  error_color text not null default '#B3261E',
  updated_at timestamptz not null default now()
);

comment on table app_branding is 'هوية التطبيق (الاسم، الشعار، اللون الأساسي) — تُعدَّل من لوحة الإدارة، يقرأها تطبيق الزبون عند بدء التشغيل';

insert into app_branding (id) values ('default');

alter table app_branding enable row level security;

create policy "app_branding_public_read"
  on app_branding for select
  using (true);

create policy "app_branding_admin_update"
  on app_branding for update
  using (public.is_admin());

-- ============================================================
-- بيانات التواصل العامة (تظهر في شاشة "المساعدة" بتطبيق الزبون) —
-- جدول منفصل عن app_branding لوضوح الغرض، بنفس منطق القراءة العامة/
-- الكتابة الإدارية فقط.
-- ============================================================

create table app_contact (
  id text primary key default 'default',
  whatsapp_number text not null default '213555000000',
  display_phone text not null default '0555 00 00 00',
  support_email text not null default 'support@commanderkhenchela.dz',
  facebook_url text,
  instagram_url text,
  updated_at timestamptz not null default now()
);

comment on table app_contact is 'بيانات التواصل العامة (واتساب/هاتف/بريد/شبكات اجتماعية) — تُعدَّل من لوحة الإدارة، تظهر في شاشة المساعدة بتطبيق الزبون';

insert into app_contact (id) values ('default');

alter table app_contact enable row level security;

create policy "app_contact_public_read"
  on app_contact for select
  using (true);

create policy "app_contact_admin_update"
  on app_contact for update
  using (public.is_admin());

-- ============================================================
-- Storage bucket لملف الشعار — نفس نمط product-images بالضبط،
-- لكن الكتابة هنا محصورة بالإدارة فقط (وليس أي تاجر).
-- ============================================================

insert into storage.buckets (id, name, public)
values ('branding-assets', 'branding-assets', true)
on conflict (id) do nothing;

create policy "branding_assets_public_read"
  on storage.objects for select
  using (bucket_id = 'branding-assets');

create policy "branding_assets_admin_write"
  on storage.objects for insert
  with check (bucket_id = 'branding-assets' and public.is_admin());

create policy "branding_assets_admin_update"
  on storage.objects for update
  using (bucket_id = 'branding-assets' and public.is_admin());

create policy "branding_assets_admin_delete"
  on storage.objects for delete
  using (bucket_id = 'branding-assets' and public.is_admin());
