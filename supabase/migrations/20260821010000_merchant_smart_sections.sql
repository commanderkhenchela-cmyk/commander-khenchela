-- ============================================================
-- Migration: أساس الأقسام الذكية داخل صفحة تصنيف (مميزة / الأكثر
-- طلبًا / المضافة حديثًا)
--
-- تنبيه نطاق: "الأقرب إليك" و"مفتوح الآن" غير مبنيَّين هنا عمدًا — لا
-- توجد بيانات موقع جغرافي ولا ساعات عمل للمحلات بعد. هذا الملف يبني
-- فقط الأقسام الثلاثة التي لدينا بيانات حقيقية كافية لها الآن:
--   • مميزة        → عمود is_featured يدوي، يحدّده Admin فقط.
--   • الأكثر طلبًا  → عمود orders_count تلقائي، Trigger يحسبه من جدول
--                     orders الحقيقي (لا تقدير ولا بيانات وهمية).
--   • المضافة حديثًا → created_at الموجود أصلًا (ترتيب فقط، بدون عمود
--                       جديد).
-- ============================================================

alter table merchants add column is_featured boolean not null default false;
alter table merchants add column orders_count integer not null default 0;

comment on column merchants.is_featured is
  'يحدّده Admin يدويًا فقط — يظهر المحل في قسم "مميزة" داخل صفحة تصنيفه. محمي من تعديل التاجر لنفسه عبر protect_merchant_status أدناه.';
comment on column merchants.orders_count is
  'عدّاد تلقائي لعدد كل الطلبات (بكل الحالات) التي استُقبلت لهذا المحل عبر تاريخه — مؤشر "الأكثر طلبًا". يُحدَّث فقط عبر Trigger عند إنشاء طلب، ممنوع تعديله يدويًا حتى من التاجر نفسه.';

create index merchants_orders_count_idx on merchants (orders_count desc);
create index merchants_is_featured_idx on merchants (is_featured) where is_featured = true;

-- ---------- عدّاد الطلبات: يتحدَّث تلقائيًا عند كل طلب جديد ----------

create function public.increment_merchant_orders_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update merchants set orders_count = orders_count + 1 where id = new.merchant_id;
  return new;
end;
$$;

create trigger orders_increment_merchant_count
  after insert on orders
  for each row execute function public.increment_merchant_orders_count();

-- ---------- توسيع الحماية الموجودة على merchants ----------
-- protect_merchant_status كانت تحمي عمود status فقط من تعديل التاجر
-- لنفسه. الآن تحمي أيضًا category_id (كان بلا حماية منذ إضافته في
-- 20260820090000 رغم أنه من المفترض أن يكون بيد الإدارة فقط)،
-- وis_featured وorders_count الجديدين. الاسم يبقى كما هو حتى لا نحتاج
-- لإعادة إنشاء الـ Trigger المرتبط به (merchants_protect_status).
create or replace function public.protect_merchant_status()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  is_privileged boolean;
begin
  is_privileged := auth.role() = 'service_role'
    or exists (select 1 from users where id = auth.uid() and role = 'admin');

  if not is_privileged then
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
  end if;

  return new;
end;
$$;

-- ملاحظة: لا حاجة لـ Trigger سجل نشاطات جديد هنا — merchants لديها
-- بالفعل log_merchants_admin_activity (AFTER UPDATE، من
-- 20260820080000) يسجّل أي تعديل إداري على الجدول تلقائيًا، بما فيه
-- تفعيل/إلغاء is_featured.
