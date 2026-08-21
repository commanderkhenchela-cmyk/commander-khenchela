-- ============================================================
-- Migration: صور المحل الحقيقية (شعار + صورة غلاف) — بدل الأيقونة
-- الرمزية العامة التي تظهر في كل بطاقة محل (تعليق صريح من المستخدم على
-- الشاشة الرئيسية القديمة: البطاقات "تبدو ميتة" بدون صور حقيقية).
--
-- نفس نمط product-images بالضبط (راجع
-- 20260820060000_product_images_storage.sql): bucket عام للقراءة، رفع/
-- حذف محصور بمجلد باسم معرّف المحل نفسه، يتحقق أن صاحب الطلب فعلًا
-- يملك ذلك المحل. logo_url وcover_url كلاهما اختياري (nullable) —
-- الواجهات تعرض شكلها الاحتياطي الحالي (أيقونة) عند غيابهما، لا نضع
-- أي صورة افتراضية وهمية.
-- ============================================================

alter table merchants add column if not exists logo_url text;
alter table merchants add column if not exists cover_url text;

comment on column merchants.logo_url is 'شعار المحل — رابط عام من bucket merchant-images، يرفعه التاجر من لوحته. null = لا شعار بعد، تعرض الواجهات أيقونة احتياطية.';
comment on column merchants.cover_url is 'صورة غلاف المحل — نفس منطق logo_url.';

insert into storage.buckets (id, name, public, file_size_limit)
values ('merchant-images', 'merchant-images', true, 5242880) -- 5 ميغابايت
on conflict (id) do nothing;

create policy "merchant_images_bucket_public_read"
  on storage.objects for select
  using (bucket_id = 'merchant-images');

create policy "merchant_images_bucket_merchant_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'merchant-images'
    and exists (
      select 1 from merchants m
      where m.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = m.id::text
    )
  );

create policy "merchant_images_bucket_merchant_delete"
  on storage.objects for delete
  using (
    bucket_id = 'merchant-images'
    and exists (
      select 1 from merchants m
      where m.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = m.id::text
    )
  );
