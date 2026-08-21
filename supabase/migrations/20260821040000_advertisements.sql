-- ============================================================
-- Migration: نظام إعلانات الفيديو (Video Advertising Board)
--
-- جدول واحد، ديناميكي بالكامل من لوحة الإدارة — لا شيء Hardcoded في
-- تطبيق العميل. تواريخ البداية/النهاية اختيارية (null = بلا سقف زمني)؛
-- الفلترة الفعلية بالتاريخ تتم في كود التطبيق (نفس نمط "بحث المحلات"
-- المستخدَم سابقًا: قراءة عامة لكل النشط، وفلترة إضافية على الجهاز عند
-- الحاجة) بدل استعلامات OR/NULL معقّدة في PostgREST.
--
-- عدّادات الإحصائيات (views/starts/completions/clicks) لا تُكتب أبدًا
-- بتحديث مباشر من العميل — لو سمحنا بذلك، أي شخص يقدر يزوّر أو يخرّب
-- أرقام أي إعلان بنداء مباشر لواجهة Supabase. بدلها: دالة RPC واحدة
-- محكومة (security definer) تتحقق من اسم الإحصائية المسموح بها فقط
-- وتزيدها +1 بشكل ذرّي — نفس فلسفة admin_set_delivery_fee (Phase 8).
-- ============================================================

create table advertisements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  advertiser_name text not null,
  video_url text not null,
  thumbnail_url text,
  link_url text,
  start_date date,
  end_date date,
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  views_count integer not null default 0,
  video_starts_count integer not null default 0,
  video_completions_count integer not null default 0,
  clicks_count integer not null default 0,
  created_at timestamptz not null default now()
);

comment on table advertisements is 'لوحة إعلانات الفيديو الاختيارية أعلى الصفحة الرئيسية لتطبيق العميل — تُدار بالكامل من لوحة الإدارة. عدّادات الإحصائيات تُكتب فقط عبر increment_ad_stat()، أبدًا بتحديث مباشر.';
comment on column advertisements.start_date is 'null = بلا تاريخ بداية محدَّد (نشط فورًا إن كان is_active)';
comment on column advertisements.end_date is 'null = بلا تاريخ انتهاء محدَّد (لا ينتهي تلقائيًا)';

create index advertisements_sort_order_idx on advertisements (sort_order);
create index advertisements_is_active_idx on advertisements (is_active) where is_active = true;

alter table advertisements enable row level security;

-- القراءة العامة تقتصر على is_active فقط — فلترة التاريخ الدقيقة تتم
-- في كود التطبيق (راجع تعليق الملف أعلاه).
create policy "advertisements_select_public"
  on advertisements for select
  using (is_active = true);

create policy "advertisements_admin_all"
  on advertisements for all
  using (public.is_admin())
  with check (public.is_admin());

create trigger log_advertisements_admin_activity
  after insert or update or delete on advertisements
  for each row execute function public.log_admin_activity();

-- ---------- دالة الإحصائيات الآمنة الوحيدة المسموح بها من العميل ----------

create function public.increment_ad_stat(p_ad_id uuid, p_stat text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if p_stat not in ('view', 'video_start', 'video_completion', 'click') then
    raise exception 'إحصائية غير معروفة: %', p_stat;
  end if;

  if p_stat = 'view' then
    update advertisements set views_count = views_count + 1 where id = p_ad_id;
  elsif p_stat = 'video_start' then
    update advertisements set video_starts_count = video_starts_count + 1 where id = p_ad_id;
  elsif p_stat = 'video_completion' then
    update advertisements set video_completions_count = video_completions_count + 1 where id = p_ad_id;
  elsif p_stat = 'click' then
    update advertisements set clicks_count = clicks_count + 1 where id = p_ad_id;
  end if;
end;
$$;

comment on function public.increment_ad_stat is 'الطريقة الوحيدة المسموح بها لتحديث عدّادات إحصائيات الإعلان من تطبيق العميل — تمنع أي تلاعب مباشر بالأرقام عبر update مباشر على الجدول (لا Policy لـ update عام أصلًا).';

-- ============================================================
-- Storage bucket لملفات الإعلانات (فيديو + صورة مصغّرة) — نفس نمط
-- branding-assets: قراءة عامة، كتابة للإدارة فقط.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit)
values ('ad-media', 'ad-media', true, 52428800) -- 50 ميغابايت حد أقصى للفيديو
on conflict (id) do nothing;

create policy "ad_media_public_read"
  on storage.objects for select
  using (bucket_id = 'ad-media');

create policy "ad_media_admin_write"
  on storage.objects for insert
  with check (bucket_id = 'ad-media' and public.is_admin());

create policy "ad_media_admin_update"
  on storage.objects for update
  using (bucket_id = 'ad-media' and public.is_admin());

create policy "ad_media_admin_delete"
  on storage.objects for delete
  using (bucket_id = 'ad-media' and public.is_admin());
