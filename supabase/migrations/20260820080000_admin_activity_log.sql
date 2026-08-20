-- ============================================================
-- Migration: سجل نشاطات الإدارة (Admin Activity Log)
--
-- يسجّل تلقائيًا كل إجراء إداري مؤثر (موافقة على محل، تعديل الهوية/
-- الألوان، تعديل بيانات التواصل، إضافة/تعديل تصنيف، تعديل رسوم
-- التوصيل أو الإعدادات) — من قام به، متى، وما الذي تغيّر بالضبط.
--
-- لماذا Triggers وليس استدعاءً يدويًا من كل نموذج في لوحة الإدارة؟
-- لأن التسجيل عبر Trigger لا يمكن للمستخدم تجاوزه (حتى لو استدعى
-- الجدول مباشرة عبر API خارج الواجهة) — وهذا بالضبط معنى "تطبيق
-- الأمان فعليًا على مستوى قاعدة البيانات، وليس فقط إخفاء الأزرار".
--
-- ملاحظة: تغييرات حالة الطلب (orders) لها بالفعل سجل كامل خاص بها
-- (order_status_history منذ Phase 1، يسجّل كل تغيير من أي طرف: تاجر
-- أو عميل أو إدارة). هذا السجل الجديد مخصَّص لإجراءات الإدارة على
-- بقية الجداول (المحلات، الهوية، التواصل، التصنيفات).
-- ============================================================

create table admin_activity_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references users (id),
  admin_name text not null,
  action text not null,
  table_name text not null,
  record_id text,
  changes jsonb,
  created_at timestamptz not null default now()
);

comment on table admin_activity_log is 'سجل كل إجراء إداري مؤثر — من قام به، متى، وما الذي تغيّر. يُكتب تلقائيًا فقط عبر Triggers، غير قابل للتعديل من أي تطبيق عميل';

create index admin_activity_log_created_at_idx on admin_activity_log (created_at desc);

alter table admin_activity_log enable row level security;

create policy "admin_activity_log_select_admin"
  on admin_activity_log for select
  using (public.is_admin());

-- ملاحظة: لا Policy لـ insert/update/delete — الكتابة تتم فقط عبر
-- الدالة أدناه (security definer، تعمل بصلاحية postgres، تتجاوز RLS).

create or replace function public.log_admin_activity()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_admin_name text;
  v_action text;
  v_record_id text;
  v_changes jsonb;
begin
  -- لا نسجّل إلا إجراءات أدمن حقيقي (يستثني merchant/customer الذين
  -- قد يعدّلون جداول أخرى لا علاقة لها بهذا الـ trigger أصلًا، وهذا
  -- فحص إضافي احترازي فقط).
  if not exists (select 1 from users where id = v_admin_id and role = 'admin') then
    return coalesce(new, old);
  end if;

  select full_name into v_admin_name from users where id = v_admin_id;

  if TG_OP = 'INSERT' then
    v_action := 'إنشاء';
    v_record_id := new.id::text;
    v_changes := to_jsonb(new);
  elsif TG_OP = 'UPDATE' then
    v_action := 'تعديل';
    v_record_id := new.id::text;
    v_changes := jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new));
  elsif TG_OP = 'DELETE' then
    v_action := 'حذف';
    v_record_id := old.id::text;
    v_changes := to_jsonb(old);
  end if;

  insert into admin_activity_log (admin_id, admin_name, action, table_name, record_id, changes)
  values (v_admin_id, coalesce(v_admin_name, ''), v_action, TG_TABLE_NAME, v_record_id, v_changes);

  return coalesce(new, old);
end;
$$;

create trigger log_merchants_admin_activity
  after update on merchants
  for each row execute function public.log_admin_activity();

create trigger log_app_branding_admin_activity
  after update on app_branding
  for each row execute function public.log_admin_activity();

create trigger log_app_contact_admin_activity
  after update on app_contact
  for each row execute function public.log_admin_activity();

create trigger log_categories_admin_activity
  after insert or update or delete on categories
  for each row execute function public.log_admin_activity();
