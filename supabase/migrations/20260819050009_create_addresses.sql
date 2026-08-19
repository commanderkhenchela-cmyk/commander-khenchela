-- ============================================================
-- Migration: جدول addresses (عناوين توصيل العملاء)
-- ============================================================

create table addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id),
  wilaya_id smallint not null references wilayas (id),
  commune_id integer not null references communes (id),
  address_text text not null,
  phone text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table addresses is 'عناوين توصيل العملاء. عنوان خاص، يراه فقط صاحبه';

create index addresses_user_id_idx on addresses (user_id);

-- ============================================================
-- الأمان (RLS)
-- ============================================================
alter table addresses enable row level security;

-- Policy: المستخدم يقرأ/يضيف/يعدّل/يحذف فقط عناوينه الخاصة
create policy "addresses_owner_all"
  on addresses for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
