-- ============================================================
-- Migration: جدول merchants (المحلات)
-- ============================================================

create table merchants (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references users (id),
  store_name text not null,
  wilaya_id smallint not null references wilayas (id),
  commune_id integer not null references communes (id),
  address_text text,
  phone text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

comment on table merchants is 'بيانات المحلات. كل محل مرتبط بمستخدم مالك (owner_user_id) وحالة موافقة Admin';

create index merchants_owner_user_id_idx on merchants (owner_user_id);
create index merchants_status_idx on merchants (status);

-- ============================================================
-- حماية إضافية: منع التاجر من تغيير حالة الموافقة (status) بنفسه
-- حتى لو حاول إرسال تعديل عبر الواجهة أو مباشرة عبر API.
-- فقط Admin (عبر Service Role في Edge Function) يستطيع تغيير الحالة.
-- ============================================================
create function public.protect_merchant_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status and auth.role() <> 'service_role' then
    new.status := old.status;
  end if;
  return new;
end;
$$;

create trigger merchants_protect_status
  before update on merchants
  for each row execute function public.protect_merchant_status();

-- ============================================================
-- الأمان (RLS)
-- ============================================================
alter table merchants enable row level security;

-- Policy: التاجر يقرأ محله الخاص دائمًا (بأي حالة: pending/approved/rejected)
create policy "merchants_select_own"
  on merchants for select
  using (owner_user_id = auth.uid());

-- Policy: أي شخص (حتى غير مسجَّل) يقرأ فقط المحلات المُوافَق عليها
-- (هذا ما يسمح للعملاء بتصفح المحلات في التطبيق)
create policy "merchants_select_approved_public"
  on merchants for select
  using (status = 'approved');

-- Policy: مستخدم يستطيع إنشاء طلب انضمام محل خاص به فقط،
-- وبحالة 'pending' إجباريًا (لا يستطيع إدخال نفسه كـ 'approved' مباشرة)
create policy "merchants_insert_own"
  on merchants for insert
  with check (owner_user_id = auth.uid() and status = 'pending');

-- Policy: التاجر يعدّل بيانات محله الخاص (الاسم، العنوان، الهاتف)
-- تغيير status محمي بالـ Trigger أعلاه بغض النظر عن هذه الـ Policy
create policy "merchants_update_own"
  on merchants for update
  using (owner_user_id = auth.uid());
