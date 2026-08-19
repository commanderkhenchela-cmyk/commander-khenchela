-- ============================================================
-- Migration: notifications + settings (آخر جدولين في V1)
-- ============================================================

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id),
  title text not null,
  body text not null,
  type text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table notifications is 'إشعارات محفوظة لكل مستخدم، تُنشأ فقط من طرف السيرفر (Edge Functions)';

create index notifications_user_id_idx on notifications (user_id);

alter table notifications enable row level security;

-- Policy: كل مستخدم يقرأ فقط إشعاراته الخاصة
create policy "notifications_select_own"
  on notifications for select
  using (user_id = auth.uid());

-- Policy: كل مستخدم يستطيع فقط تحديد إشعاره كـ "مقروء" (لا يعدّل المحتوى)
create policy "notifications_update_own"
  on notifications for update
  using (user_id = auth.uid());

-- ملاحظة: لا Policy للإنشاء (INSERT) — الإشعارات تُنشأ فقط عبر Edge
-- Function موثوقة (Service Role) عندما يحدث حدث حقيقي (تغيير حالة طلب...)

-- ---------- settings ----------
create table settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

comment on table settings is 'إعدادات عامة قابلة للتعديل من Admin فقط، عبر Service Role';

alter table settings enable row level security;

-- ملاحظة: لا توجد أي Policy على هذا الجدول إطلاقًا —
-- يعني: ممنوع الوصول له نهائيًا من أي تطبيق عميل (حتى القراءة).
-- فقط Service Role (Edge Functions + Admin Dashboard الآمن) يصل إليه.

insert into settings (key, value) values
  ('platform_commission_rate', '10');
