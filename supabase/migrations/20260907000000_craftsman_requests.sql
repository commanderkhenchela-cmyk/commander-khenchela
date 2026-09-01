-- ============================================================
-- Migration: "حرفيون" (Craftsmen) — بنية أساسية V1: مطابقة عمدًا لبداية
-- التوصيل نفسها فـ هذا المشروع.
--
-- سبب الاختلاف الجوهري عن delivery_requests/ride_requests: كلتاهما
-- بُنيتا فوق طرف رابع جاهز أصلًا وله جدول/تسجيل/موافقة/تطبيق كامل
-- (drivers، driver_app) — إعادة استخدامه كان الخيار الرخيص والآمن.
-- لا يوجد أي مكافئ لذلك للحرفيين اليوم (لا جدول craftsmen، لا تسجيل،
-- لا تطبيق) — بناء طرف جديد كامل (حساب + موافقة + تطبيق موصّل مستقل)
-- الليلة كان سيعني إما (أ) تخمين قرار منتج حقيقي (شكل عمل الحرفي:
-- تسعير بالساعة أم بالمهمة؟ تصنيفات مفتوحة أم مغلقة؟) بلا تفويض، أو
-- (ب) تطبيق Flutter جديد كامل من الصفر — نطاق أكبر بكثير مما تسمح به
-- ليلة عمل واحدة بجودة حقيقية.
--
-- الحل المعتمَد: **نفس قرار V1 الموثَّق فعليًا لهذا المشروع نفسه** —
-- راجع تعليق migration 20260822010000_drivers: "التوصيل كان يدويًا
-- بالكامل عبر الإدارة" قبل أن يُبنى driver_app كمرحلة لاحقة منفصلة.
-- هنا مطابقة حرفية لنفس الفلسفة: العميل يرسل طلبًا (تصنيف + وصف +
-- عنوان)، والإدارة (لوحة admin-dashboard، ليست تطبيقًا جديدًا) تربط
-- الطلب يدويًا بحرفي حقيقي (اسم + هاتف كنص حرّ الآن — لا حساب/تسجيل
-- حرفي بعد) وتتابعه حتى الإتمام. تسعير العمل نفسه (يد عاملة + مواد)
-- خارج المنصّة بالكامل، يُتَّفق عليه مباشرة بين العميل والحرفي — نفس
-- مبدأ "التسوية النقدية خارج التطبيق" فـ delivery_requests بالضبط،
-- هنا حتى بلا رسم توصيل يُحسَب (لا شيء تنقله المنصّة فعليًا).
--
-- ترقية لاحقة طبيعية (غير مبنية الليلة): جدول craftsmen حقيقي +
-- موافقة الإدارة + مجمّع مثل delivery_requests بمجرّد اتخاذ قرارات
-- المنتج المذكورة أعلاه.
-- ============================================================

create table craftsman_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references users (id),
  address_id uuid not null references addresses (id),
  craft_type text not null check (craft_type in (
    'plumber', 'electrician', 'painter', 'carpenter', 'locksmith', 'ac_technician', 'general'
  )),
  description text not null check (trim(description) <> ''),
  status text not null default 'pending' check (status in (
    'pending', 'assigned', 'completed', 'cancelled'
  )),
  -- لا حساب حرفي بعد (راجع التعليق أعلاه) — الإدارة تكتب بيانات التواصل
  -- كنص حرّ وقت الربط اليدوي، لا مرجعًا لجدول.
  assigned_craftsman_name text,
  assigned_craftsman_phone text,
  admin_notes text,
  created_at timestamptz not null default now(),
  assigned_at timestamptz,
  completed_at timestamptz
);

comment on table craftsman_requests is '"حرفيون" V1 — مطابقة الحل اليدوي الذي بدأ به التوصيل فـ هذا المشروع (راجع migration 20260822010000_drivers). لا جدول حرفيين بعد، الإدارة تربط الطلب يدويًا ببيانات تواصل حرّة عبر admin_assign_craftsman_request.';

create index craftsman_requests_customer_id_idx on craftsman_requests (customer_id);
create index craftsman_requests_status_idx on craftsman_requests (status);

-- ============================================================
-- محرّك الانتقالات
-- ============================================================
create function public.validate_craftsman_request_status_transition()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor_role text;
begin
  if new.status = old.status then
    return new;
  end if;

  if auth.role() = 'service_role' then
    return new;
  end if;

  select role into actor_role from users where id = auth.uid();

  if old.status in ('completed', 'cancelled') then
    raise exception 'لا يمكن تغيير حالة طلب فـ حالة نهائية (%)', old.status;
  end if;

  if old.status = 'pending' and new.status = 'assigned' and actor_role in ('admin', 'manager') then
    return new;
  elsif old.status = 'assigned' and new.status = 'completed' and actor_role in ('admin', 'manager') then
    return new;
  elsif old.status in ('pending', 'assigned') and new.status = 'cancelled'
        and (new.customer_id = auth.uid() or actor_role in ('admin', 'manager')) then
    return new;
  else
    raise exception 'انتقال حالة غير مسموح: من % إلى %', old.status, new.status;
  end if;
end;
$$;

create trigger craftsman_requests_validate_status_transition
  before update on craftsman_requests
  for each row execute function public.validate_craftsman_request_status_transition();

-- ============================================================
-- الأمان (RLS) — لا سياسة "مجمّع" هنا (لا طرف حرفي يتصفّح شيئًا بعد).
-- ============================================================
alter table craftsman_requests enable row level security;

create policy "craftsman_requests_select_own_customer"
  on craftsman_requests for select
  using (customer_id = auth.uid());

create policy "craftsman_requests_select_admin"
  on craftsman_requests for select
  using (public.can_manage_stores());

create policy "craftsman_requests_update_customer"
  on craftsman_requests for update
  using (customer_id = auth.uid());

create policy "craftsman_requests_update_admin"
  on craftsman_requests for update
  using (public.can_manage_stores());

-- ============================================================
-- إنشاء الطلب — نفس هيكل create_delivery_request بالضبط.
-- ============================================================
create function public.create_craftsman_request(
  p_address_id uuid,
  p_craft_type text,
  p_description text
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_request_id uuid;
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإنشاء طلب';
  end if;

  if exists (select 1 from users where id = v_customer_id and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = v_customer_id
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  if p_craft_type not in (
    'plumber', 'electrician', 'painter', 'carpenter', 'locksmith', 'ac_technician', 'general'
  ) then
    raise exception 'تصنيف الحرفة غير صالح';
  end if;

  if trim(coalesce(p_description, '')) = '' then
    raise exception 'صف ما تريد طلبه أولًا';
  end if;

  insert into craftsman_requests (customer_id, address_id, craft_type, description, status)
  values (v_customer_id, p_address_id, p_craft_type, trim(p_description), 'pending')
  returning id into v_request_id;

  return v_request_id;
end;
$$;

-- ============================================================
-- ربط الإدارة بحرفي يدويًا — أشبه بـ admin_override_delivery_fee فـ
-- كونها إجراء إداريًا صرفًا، لا RPC مكافئ للعميل/الحرفي.
-- ============================================================
create function public.admin_assign_craftsman_request(
  p_request_id uuid,
  p_craftsman_name text,
  p_craftsman_phone text,
  p_notes text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_manage_stores() then
    raise exception 'لا تملك صلاحية هذا الإجراء';
  end if;

  if trim(coalesce(p_craftsman_name, '')) = '' or trim(coalesce(p_craftsman_phone, '')) = '' then
    raise exception 'اسم الحرفي وهاتفه مطلوبان';
  end if;

  update craftsman_requests
  set status = 'assigned',
      assigned_craftsman_name = trim(p_craftsman_name),
      assigned_craftsman_phone = trim(p_craftsman_phone),
      admin_notes = nullif(trim(coalesce(p_notes, '')), ''),
      assigned_at = now()
  where id = p_request_id
    and status = 'pending';

  if not found then
    raise exception 'لا يمكن ربط هذا الطلب فـ حالته الحالية';
  end if;
end;
$$;

create function public.admin_complete_craftsman_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_manage_stores() then
    raise exception 'لا تملك صلاحية هذا الإجراء';
  end if;

  update craftsman_requests
  set status = 'completed',
      completed_at = now()
  where id = p_request_id
    and status = 'assigned';

  if not found then
    raise exception 'لا يمكن إتمام هذا الطلب فـ حالته الحالية';
  end if;
end;
$$;

-- ============================================================
-- الشبكة العامة الموجودة أصلًا — إعادة استخدام حرفي.
-- ============================================================
create trigger craftsman_requests_notify_webhook
  after insert or update on craftsman_requests
  for each row execute function public.notify_order_webhook();

create trigger log_craftsman_requests_admin_activity
  after insert or update or delete on craftsman_requests
  for each row execute function public.log_admin_activity();

alter publication supabase_realtime add table craftsman_requests;

-- ============================================================
-- تفعيل خدمة "حرفيون" (services.slug='craftsmen').
-- ============================================================
update services set enabled = true where slug = 'craftsmen';
