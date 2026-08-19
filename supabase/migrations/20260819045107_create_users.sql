-- ============================================================
-- Migration: جدول users
-- الملف الشخصي لكل مستخدم (عميل/تاجر/إداري)، مرتبط بحساب الدخول
-- المُدار من طرف Supabase Auth (جدول auth.users الخاص والمحمي).
-- ============================================================

create table users (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('customer', 'merchant', 'admin')),
  full_name text not null,
  phone text,
  created_at timestamptz not null default now()
);

comment on table users is 'الملف الشخصي لكل مستخدم، مرتبط تلقائيًا بحساب الدخول في auth.users';

-- ============================================================
-- Trigger: عند إنشاء حساب دخول جديد (auth.users)، ينشئ تلقائيًا
-- صفًا موافقًا في public.users بنفس المعرّف (id).
-- هذا يضمن أن كل مستخدم له ملف شخصي دائمًا، بدون خطوة يدوية.
-- ============================================================
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, role, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'role', 'customer'),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- الأمان (RLS)
-- ============================================================
alter table users enable row level security;

-- Policy: كل مستخدم يقرأ فقط ملفه الشخصي الخاص (ليس ملفات الآخرين)
create policy "users_select_own"
  on users for select
  using (auth.uid() = id);

-- Policy: كل مستخدم يعدّل فقط ملفه الشخصي الخاص
create policy "users_update_own"
  on users for update
  using (auth.uid() = id);

-- ملاحظة: لا توجد Policy لـ INSERT (الإنشاء يتم فقط عبر الـ Trigger أعلاه)
-- ولا لـ DELETE (لا يُسمح لأي مستخدم بحذف حسابه بنفسه عبر التطبيق مباشرة).
--
-- لوحة تحكم Admin ستحتاج لاحقًا رؤية كل المستخدمين (وليس فقط "نفسه") —
-- هذا لن يمر عبر RLS العادي، بل عبر Edge Function خاصة تستخدم صلاحية
-- Service Role (سرية، على السيرفر فقط، لا تصل أبدًا لأي تطبيق عميل).
-- سنشرح هذا بالتفصيل في PHASE 12 — Security.
