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
-- الإصلاح ثلاث خطوات:
-- (1) لكل owner_user_id مكرَّر، نختار "الصفّ الحقيقي" الذي يُبقى عليه —
--     بالأولوية: له طلبات فعلية، ثم له منتجات، ثم الحالة الأفضل
--     (approved > pending > rejected)، ثم الأحدث. هذا يضمن أننا لا
--     نحذف أبدًا صفًا فيه بيانات فعلية استُخدمت.
-- (2) نحذف منتجات الصفوف "الخاسرة" فقط (لا طلبات ولا صور محل مرتبطة
--     بها أصلًا حسب شرط الاختيار أعلاه) — صور المنتجات تُحذف تلقائيًا
--     معها (product_images بها on delete cascade). ساعات العمل
--     (merchant_business_hours) بها on delete cascade على مستوى الجدول
--     أصلًا فلا حاجة لحذفها يدويًا.
-- (3) حارس أمان صريح إضافي في شرط الحذف نفسه: لا يُحذف أي صفّ محل عليه
--     أي طلب فعلي إطلاقًا، مهما حدث — بيانات الطلبات لا تُحذف تلقائيًا
--     أبدًا في هذا المشروع.
-- بعدها: قيد unique يمنع تكرار المشكلة نهائيًا على مستوى قاعدة البيانات.
-- ============================================================

with ranked as (
  select
    id,
    row_number() over (
      partition by owner_user_id
      order by
        (exists (select 1 from orders o where o.merchant_id = merchants.id)) desc,
        (exists (select 1 from products p where p.merchant_id = merchants.id)) desc,
        case status
          when 'approved' then 0
          when 'pending' then 1
          else 2
        end,
        created_at desc
    ) as rn
  from merchants
),
losers as (
  select id from ranked where rn > 1
)
delete from products
where merchant_id in (select id from losers);

delete from merchants m
using (
  select
    id,
    row_number() over (
      partition by owner_user_id
      order by
        (exists (select 1 from orders o where o.merchant_id = merchants.id)) desc,
        (exists (select 1 from products p where p.merchant_id = merchants.id)) desc,
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
  and ranked.rn > 1
  -- حارس أمان: مهما حدث، لا يُحذف صفّ عليه طلبات فعلية.
  and not exists (select 1 from orders o where o.merchant_id = m.id);

alter table merchants
  add constraint merchants_owner_user_id_key unique (owner_user_id);

comment on constraint merchants_owner_user_id_key on merchants is 'محل واحد فقط لكل مستخدم مالك — يمنع الخلل الذي كان يعيد التاجر لصفحة "أنشئ محلك" إلى الأبد عند وجود أكثر من صفّ لنفس owner_user_id.';
