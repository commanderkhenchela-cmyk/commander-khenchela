-- ============================================================
-- Migration: Storage bucket لصور المنتجات (PHASE 7 تحسين)
--
-- يستبدل هذا "رابط صورة يُلصَق يدويًا" (الحل المؤقت الذي وثّقناه كحدّ
-- معروف في لوحة التاجر) برفع ملف حقيقي من جهاز التاجر عبر Supabase
-- Storage — بدون أي تغيير على شكل البيانات (product_images.image_url
-- يبقى رابطًا نصيًا كما هو، فقط مصدره الآن رفع حقيقي بدل لصق يدوي).
--
-- تنظيم الملفات: كل صورة تُخزَّن تحت مجلد باسم معرّف المحل نفسه
-- ({merchant_id}/...)، وهذا ما تتحقق منه Policies الرفع/الحذف أدناه —
-- تاجر لا يستطيع الكتابة إلا داخل مجلده الخاص.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- القراءة عامة (نفس منطق قراءة المنتجات نفسها: صور علنية لأي زائر)
create policy "product_images_bucket_public_read"
  on storage.objects for select
  using (bucket_id = 'product-images');

-- الرفع: فقط داخل مجلد يطابق معرّف محل يملكه المستخدم الحالي
create policy "product_images_bucket_merchant_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images'
    and exists (
      select 1 from merchants m
      where m.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = m.id::text
    )
  );

-- الحذف: نفس الشرط، حتى يستطيع التاجر استبدال صورة منتج
create policy "product_images_bucket_merchant_delete"
  on storage.objects for delete
  using (
    bucket_id = 'product-images'
    and exists (
      select 1 from merchants m
      where m.owner_user_id = auth.uid()
        and (storage.foldername(name))[1] = m.id::text
    )
  );
