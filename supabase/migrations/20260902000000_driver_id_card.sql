-- ============================================================
-- Migration: بطاقة تعريف الموصّل (PRD section 12)
--
-- فجوة حقيقية موثَّقة سابقًا فـ الـ Audit: حتى نظام الدراجات الحالي
-- (المرحلة 1، شغّال فعليًا) لا يملك أي عمود لوثيقة — الموافقة تتم اليوم
-- على الاسم/الهاتف فقط، بلا أي تحقّق هوية. هذه المرحلة تُغلق هذه الفجوة
-- تحديدًا (لا علاقة لها بالطاكسي المستقبلي — نفس المتطلَّب الأساسي
-- لموصّل الدراجة الموجود فعلًا).
--
-- bucket خاص (public=false) — على عكس merchant-images/product-images
-- العامَّين: بطاقة التعريف بيانات حسّاسة (نفس ملاحظة Security
-- Dependencies من REQUIREMENTS GAP ANALYSIS سابقًا). id_card_path
-- يخزّن مسار الملف داخل الـ bucket فقط (لا رابطًا عامًا — لا يوجد رابط
-- عام أصلًا لأن الـ bucket خاص)، تُولَّد رابط مؤقّت (Signed URL) عند
-- الحاجة فقط من طرف صاحب الوثيقة أو الإدارة.
-- ============================================================

alter table drivers add column id_card_path text;

comment on column drivers.id_card_path is 'مسار صورة بطاقة التعريف داخل bucket خاص (driver-documents) — وليس رابطًا عامًا. NULL = لم يرفع الموصّل وثيقته بعد (لن يحدث لموصّلين جدد بعد هذه المرحلة، لأن الرفع أصبح إلزاميًا فـ التسجيل؛ يبقى NULL فقط للموصّلين المسجَّلين قبلها).';

insert into storage.buckets (id, name, public, file_size_limit)
values ('driver-documents', 'driver-documents', false, 5242880) -- 5 ميغابايت
on conflict (id) do nothing;

-- القراءة: صاحب الوثيقة نفسه، أو الإدارة (نفس نطاق can_manage_stores()
-- المستخدَم أصلًا فـ drivers_select_admin) — لا قراءة عامة إطلاقًا.
create policy "driver_documents_select_own"
  on storage.objects for select
  using (
    bucket_id = 'driver-documents'
    and exists (
      select 1 from drivers d
      where d.user_id = auth.uid()
        and (storage.foldername(name))[1] = d.id::text
    )
  );

create policy "driver_documents_select_admin"
  on storage.objects for select
  using (bucket_id = 'driver-documents' and public.can_manage_stores());

-- الرفع: الموصّل يرفع فقط داخل مجلد باسم معرّف حسابه هو (نفس نمط
-- merchant_images_bucket_merchant_upload بالضبط) — لا صلاحية تعديل أو
-- حذف (وثيقة مُرسَلة للمراجعة لا يُفترَض تبديلها بصمت بعد الإرسال؛
-- تعديلها الحقيقي يحتاج تواصلًا مع الإدارة، ليس ميزة ذاتية).
create policy "driver_documents_insert_own"
  on storage.objects for insert
  with check (
    bucket_id = 'driver-documents'
    and exists (
      select 1 from drivers d
      where d.user_id = auth.uid()
        and (storage.foldername(name))[1] = d.id::text
    )
  );
