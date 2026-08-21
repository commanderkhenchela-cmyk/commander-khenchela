-- ============================================================
-- إصلاح خلل حقيقي: لا يوجد قيد unique على merchants.owner_user_id منذ
-- إنشاء الجدول — أي مستخدم يقدر ينشئ أكثر من محل (مثلًا لو أعاد فتح
-- /onboarding وأرسل النموذج مرتين، أو أعاد المحاولة بعد أي تأخّر في
-- إعادة التوجيه). النتيجة الفعلية المُلاحَظة: بمجرد وجود صفّين لنفس
-- owner_user_id، استعلام getMerchantContext() (يستخدم .maybeSingle())
-- يفشل لأنه يتوقّع صفًا واحدًا كحد أقصى فيرجع بلا محل (merchant: null)
-- — فتُعيد لوحة التاجر توجيه صاحب المحل لصفحة "أنشئ محلك" من جديد إلى
-- الأبد، حتى لو كان أحد محلَّيه (أو أكثر) موافَقًا عليه فعلًا من الإدارة.
-- هذا بالضبط ما حدث لحساب test-merchant.
--
-- الإصلاح خطوتان: (1) تنظيف الصفوف المكرَّرة الموجودة حاليًا، بالإبقاء
-- على صفّ واحد لكل owner_user_id بأولوية الحالة الأفضل ثم الأحدث،
-- (2) قيد unique يمنع تكرار المشكلة مستقبلًا نهائيًا على مستوى قاعدة
-- البيانات، بغض النظر عن أي خلل مستقبلي في واجهة التطبيق.
-- ============================================================

delete from merchants m
using (
  select
    id,
    row_number() over (
      partition by owner_user_id
      order by
        case status
          when 'approved' then 0
          when 'pending' then 1
          else 2
        end,
        created_at desc
    ) as rn
  from merchants
) ranked
where m.id = ranked.id
  and ranked.rn > 1;

alter table merchants
  add constraint merchants_owner_user_id_key unique (owner_user_id);

comment on constraint merchants_owner_user_id_key on merchants is 'محل واحد فقط لكل مستخدم مالك — يمنع الخلل الذي كان يعيد التاجر لصفحة "أنشئ محلك" إلى الأبد عند وجود أكثر من صفّ لنفس owner_user_id.';
