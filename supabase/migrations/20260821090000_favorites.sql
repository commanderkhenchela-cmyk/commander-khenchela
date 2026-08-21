-- ============================================================
-- Migration: المحلات المفضَّلة (Favorites) — يسمح للعميل بحفظ المحلات
-- التي يحبّها والوصول إليها بسرعة لاحقًا (شاشة "مفضّلتي")، ويضيف زر
-- القلب الحقيقي على بطاقة المحل — كان هذا مستبعدًا سابقًا صراحةً من
-- إعادة بناء الصفحة الرئيسية لعدم وجود نموذج بيانات حقيقي يدعمه، والآن
-- بُني فعليًا بدل بقائه علامة مزيَّفة على البطاقة.
--
-- خاصة بكل مستخدم تمامًا (RLS: لا يرى/يعدّل أحد مفضّلة غيره إطلاقًا،
-- ولا حتى الإدارة — لا حاجة إدارية لرؤيتها). قيد unique يمنع تكرار نفس
-- المحل مرتين لنفس المستخدم (زر واحد يبدّل: إضافة/إزالة).
-- ============================================================

create table favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  merchant_id uuid not null references merchants (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, merchant_id)
);

comment on table favorites is 'المحلات المفضَّلة لكل عميل — خاصة تمامًا لصاحبها (RLS)، لا صلة لها بتقييم المحل العام أو أي إحصائية أخرى.';

create index favorites_user_id_idx on favorites (user_id);

alter table favorites enable row level security;

create policy "favorites_select_own"
  on favorites for select
  using (user_id = auth.uid());

create policy "favorites_insert_own"
  on favorites for insert
  with check (user_id = auth.uid());

create policy "favorites_delete_own"
  on favorites for delete
  using (user_id = auth.uid());
