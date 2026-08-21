-- ============================================================
-- Migration: تقييمات المحلات (Reviews) — نجمة (1-5) + تعليق اختياري.
-- كان "Rating" أحد عناصر بطاقة المحل المطلوبة أصلًا في مواصفات الصفحة
-- الرئيسية، استُبعد وقتها صراحةً لعدم وجود نموذج بيانات حقيقي. بُني
-- الآن على أساس "طلب موثَّق" (Verified Purchase): تقييم واحد فقط لكل
-- طلب، ولا يُسمح به إلا لصاحب الطلب نفسه وبعد تسليمه فعليًا — لا مجال
-- لتقييمات وهمية أو مكرَّرة.
-- ============================================================

create table reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders (id) on delete cascade,
  customer_id uuid not null references users (id) on delete cascade,
  merchant_id uuid not null references merchants (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

comment on table reviews is 'تقييم واحد لكل طلب (unique على order_id) — يمنع بنيويًا أي تقييم مكرَّر أو غير مرتبط بطلب حقيقي مُسلَّم فعلًا (راجع policy الإدخال أدناه).';

create index reviews_merchant_id_idx on reviews (merchant_id);
create index reviews_customer_id_idx on reviews (customer_id);

alter table reviews enable row level security;

-- القراءة عامة (تظهر التقييمات وملخّصها لأي زائر، مثل بقية بيانات المحل).
create policy "reviews_select_public"
  on reviews for select
  using (true);

-- الإدخال: العميل صاحب الطلب فقط، وفقط لطلب مُسلَّم فعلًا (status =
-- 'delivered')، وmerchant_id يجب أن يطابق محل الطلب نفسه — لا مجال
-- لتقييم محل عبر طلب لا يخصّه.
create policy "reviews_insert_own_delivered_order"
  on reviews for insert
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from orders o
      where o.id = order_id
        and o.customer_id = auth.uid()
        and o.status = 'delivered'
        and o.merchant_id = reviews.merchant_id
    )
  );

-- لا update/delete للعميل عمدًا في V1 (لا تعديل تقييم بعد إرساله) — فقط
-- الإدارة (عبر Table Editor مباشرة حاليًا، لا واجهة إدارة مخصَّصة بعد)
-- تقدر تحذف تقييمًا مسيئًا.
create policy "reviews_delete_admin"
  on reviews for delete
  using (public.can_manage_stores());

-- ---------- ملخّص التقييم على المحل نفسه (rating_avg/rating_count) ----------
-- محسوبان تلقائيًا، وليسا مُدخَلَين مباشرين — يُحدَّثان فقط عبر Trigger
-- أدناه، ومحميان من التعديل المباشر (نفس نمط orders_count/views_count).

alter table merchants add column if not exists rating_avg numeric(3, 2) not null default 0;
alter table merchants add column if not exists rating_count integer not null default 0;

comment on column merchants.rating_avg is 'متوسّط التقييم (0-5)، محسوب تلقائيًا من جدول reviews — لا يُعدَّل مباشرة أبدًا.';
comment on column merchants.rating_count is 'عدد التقييمات — 0 يعني "لا تقييمات بعد"، تُخفي الواجهات شارة التقييم كليًا في هذه الحالة بدل عرض 0.0 وهميًا.';

create function public.refresh_merchant_rating()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_merchant_id uuid := coalesce(new.merchant_id, old.merchant_id);
begin
  update merchants m
  set rating_avg = coalesce(
        (select round(avg(rating)::numeric, 2) from reviews where merchant_id = v_merchant_id),
        0
      ),
      rating_count = (select count(*) from reviews where merchant_id = v_merchant_id)
  where m.id = v_merchant_id;
  return null;
end;
$$;

comment on function public.refresh_merchant_rating is 'يعيد حساب rating_avg/rating_count لمحل واحد بعد أي إضافة أو حذف تقييم — الطريقة الوحيدة التي يتغيّر بها هذان العمودان.';

create trigger reviews_refresh_merchant_rating
  after insert or delete on reviews
  for each row execute function public.refresh_merchant_rating();

-- حماية العمودين من التعديل المباشر عبر سياسة merchants_update_own
-- الحالية (نفس الثغرة المحتملة التي أُغلقت سابقًا لـ orders_count/
-- views_count).
create or replace function public.protect_merchant_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_manage_stores() then
    if new.status is distinct from old.status then
      new.status := old.status;
    end if;
    if new.category_id is distinct from old.category_id then
      new.category_id := old.category_id;
    end if;
    if new.is_featured is distinct from old.is_featured then
      new.is_featured := old.is_featured;
    end if;
    if new.orders_count is distinct from old.orders_count then
      new.orders_count := old.orders_count;
    end if;
    if new.views_count is distinct from old.views_count then
      new.views_count := old.views_count;
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
