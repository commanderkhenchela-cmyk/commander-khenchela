-- ============================================================
-- Migration: تتبّع "مشاهدات" المحل — يسمح ببناء قسم "الأكثر مشاهدة"
-- الحقيقي في الصفحة الرئيسية، والذي استُبعد صراحةً سابقًا لعدم وجود
-- أي نموذج بيانات يدعمه (بدل تلفيق ترتيب وهمي).
--
-- نفس نمط عدّادات الإعلانات بالضبط (increment_ad_stat في
-- 20260821040000_advertisements.sql): عدّاد لا يُحدَّث أبدًا بـ update
-- مباشر من العميل، فقط عبر دالة RPC محكومة (increment_merchant_view).
-- ============================================================

alter table merchants add column if not exists views_count integer not null default 0;

comment on column merchants.views_count is 'عدد مرات فتح صفحة منتجات هذا المحل — يُحدَّث فقط عبر increment_merchant_view()، أبدًا بتحديث مباشر. يُستخدم في قسم "الأكثر مشاهدة" بالصفحة الرئيسية.';

-- ---------- حماية العمود من التلاعب المباشر ----------
-- سياسة merchants_update_own الحالية تسمح للتاجر بتحديث صفّ محله عبر
-- استدعاء مباشر (supabase.from('merchants').update(...)) بلا قيد على
-- الأعمدة — لولا هذا التوسيع لأصبح views_count عرضة لنفس فئة الثغرة
-- التي كانت موجودة على role/status سابقًا (تضخيم تاجر لعدد مشاهدات
-- محله بنفسه). نوسّع نفس الحارس الموجود أصلًا لـ orders_count بالضبط.
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
  end if;

  return new;
end;
$$;

-- ---------- الطريقة الآمنة الوحيدة لزيادة العدّاد ----------
create function public.increment_merchant_view(p_merchant_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update merchants
  set views_count = views_count + 1
  where id = p_merchant_id and status = 'approved';
end;
$$;

comment on function public.increment_merchant_view is 'الطريقة الوحيدة المسموح بها لزيادة عدّاد مشاهدات محل من تطبيق العميل — نفس نمط increment_ad_stat. لا تزيد العدّاد إلا للمحلات المعتمَدة.';
