-- ============================================================
-- Migration: تقييمات السائقين (Driver Reviews) — فجوة رابعة مع Yassir
-- (بعد رقم اللوحة/ETA/اختيار نقطة على الخريطة). نفس فلسفة تقييمات
-- المحلات (20260821120000_reviews.sql) بالحرف، لكن هنا على "رحلة
-- مكتملة فعليًا" (ride_requests.status = 'completed') بدل "طلب
-- مُسلَّم" — تقييم واحد فقط لكل رحلة، ولا يُسمح به إلا لصاحب الرحلة
-- نفسه وبعد اكتمالها فعليًا.
--
-- فرق جوهري واحد عن reviews: بخلاف المحل (كيان عام يتصفّحه أي زائر)،
-- drivers ليس كيانًا عامًا فـ هذا المشروع أصلًا — RLS drivers_select_*
-- الحالية تحصر رؤية صفّ الموصّل على الموصّل نفسه/الإدارة/عميل رحلته
-- الحالية فقط أثناء accepted/in_progress (راجع migration
-- 20260911000000). فالقراءة هنا محصورة بنفس المنطق (صاحب التقييم
-- نفسه/الموصّل المعنيّ/الإدارة) — لا سياسة قراءة عامة كـ
-- reviews_select_public. ملخّص rating_avg/rating_count المضاف على
-- drivers يبقى مرئيًا فقط ضمن نفس قيود drivers الحالية، بلا أي توسيع
-- جديد لرؤية صفّ الموصّل نفسه.
-- ============================================================

create table driver_reviews (
  id uuid primary key default gen_random_uuid(),
  ride_request_id uuid not null unique references ride_requests (id) on delete cascade,
  customer_id uuid not null references users (id) on delete cascade,
  driver_id uuid not null references drivers (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

comment on table driver_reviews is 'تقييم واحد لكل رحلة (unique على ride_request_id) — يمنع بنيويًا أي تقييم مكرَّر أو غير مرتبط برحلة Taxi مكتملة فعلًا (راجع policy الإدخال أدناه)، نفس قيد reviews.order_id بالحرف.';

create index driver_reviews_driver_id_idx on driver_reviews (driver_id);
create index driver_reviews_customer_id_idx on driver_reviews (customer_id);

alter table driver_reviews enable row level security;

-- القراءة: صاحب التقييم نفسه، أو الموصّل المعنيّ (يرى تقييماته)، أو
-- الإدارة — لا قراءة عامة (راجع تعليق الملف أعلاه لسبب الفرق عن
-- reviews_select_public).
create policy "driver_reviews_select_own_customer"
  on driver_reviews for select
  using (customer_id = auth.uid());

create policy "driver_reviews_select_driver_own"
  on driver_reviews for select
  using (
    exists (select 1 from drivers d where d.id = driver_reviews.driver_id and d.user_id = auth.uid())
  );

create policy "driver_reviews_select_admin"
  on driver_reviews for select
  using (public.can_manage_stores());

-- الإدخال: العميل صاحب الرحلة فقط، وفقط لرحلة مكتملة فعلًا
-- (status = 'completed')، وdriver_id يجب أن يطابق موصّل الرحلة نفسه —
-- نفس بنية reviews_insert_own_delivered_order بالحرف.
create policy "driver_reviews_insert_own_completed_ride"
  on driver_reviews for insert
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from ride_requests r
      where r.id = ride_request_id
        and r.customer_id = auth.uid()
        and r.status = 'completed'
        and r.driver_id = driver_reviews.driver_id
    )
  );

-- لا update/delete للعميل عمدًا في V1 (لا تعديل تقييم بعد إرساله) —
-- فقط الإدارة تقدر تحذف تقييمًا مسيئًا، نفس reviews_delete_admin.
create policy "driver_reviews_delete_admin"
  on driver_reviews for delete
  using (public.can_manage_stores());

-- ---------- ملخّص التقييم على السائق نفسه (rating_avg/rating_count) ----------
-- محسوبان تلقائيًا، وليسا مُدخَلَين مباشرين — يُحدَّثان فقط عبر Trigger
-- أدناه، ومحميان من التعديل المباشر عبر protect_driver_status (نفس
-- نمط merchants.rating_avg/rating_count وprotect_merchant_status).

alter table drivers add column if not exists rating_avg numeric(3, 2) not null default 0;
alter table drivers add column if not exists rating_count integer not null default 0;

comment on column drivers.rating_avg is 'متوسّط التقييم (0-5)، محسوب تلقائيًا من جدول driver_reviews — لا يُعدَّل مباشرة أبدًا.';
comment on column drivers.rating_count is 'عدد التقييمات — 0 يعني "لا تقييمات بعد"، تُخفي الواجهات شارة التقييم كليًا فـ هذه الحالة بدل عرض 0.0 وهميًا.';

create function public.refresh_driver_rating()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_driver_id uuid := coalesce(new.driver_id, old.driver_id);
begin
  update drivers d
  set rating_avg = coalesce(
        (select round(avg(rating)::numeric, 2) from driver_reviews where driver_id = v_driver_id),
        0
      ),
      rating_count = (select count(*) from driver_reviews where driver_id = v_driver_id)
  where d.id = v_driver_id;
  return null;
end;
$$;

comment on function public.refresh_driver_rating is 'يعيد حساب rating_avg/rating_count لسائق واحد بعد أي إضافة أو حذف تقييم — الطريقة الوحيدة التي يتغيّر بها هذان العمودان.';

create trigger driver_reviews_refresh_driver_rating
  after insert or delete on driver_reviews
  for each row execute function public.refresh_driver_rating();

-- حماية العمودين الجديدين من التعديل المباشر — امتداد لـ
-- protect_driver_status الموجودة أصلًا (migration 20260822010000)،
-- نفس أسلوب امتداد protect_merchant_status فـ migration reviews.
create or replace function public.protect_driver_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_manage_stores() then
    if new.status is distinct from old.status then
      new.status := old.status;
    end if;
    if new.vehicle_type is distinct from old.vehicle_type then
      new.vehicle_type := old.vehicle_type;
    end if;
    if new.rating_avg is distinct from old.rating_avg then
      new.rating_avg := old.rating_avg;
    end if;
    if new.rating_count is distinct from old.rating_count then
      new.rating_count := old.rating_count;
    end if;
  end if;
  return new;
end;
$$;
