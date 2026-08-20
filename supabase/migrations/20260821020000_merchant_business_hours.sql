-- ============================================================
-- Migration: ساعات عمل المحلات — أساس قسم "مفتوح الآن"
--
-- تصميم: جدول مستقل (صف واحد لكل يوم من أيام الأسبوع لكل محل)، وليس
-- عمود JSON واحد — نفس فلسفة بقية المشروع (order_items,
-- order_status_history...): بيانات مبنية بشكل علائقي واضح بدل نص
-- JSON غير مفحوص. day_of_week: 0=الأحد ... 6=السبت (نفس ترقيم
-- DateTime.weekday في Dart بعد تحويل بسيط، محسوب في كود التطبيق).
--
-- من يملأ هذه البيانات؟ التاجر نفسه من لوحة تحكمه (Merchant Dashboard)
-- — هو الوحيد الذي يعرف ساعات عمله فعليًا، وليس الإدارة. الإدارة تملك
-- صلاحية Override كاملة (is_admin()) عند الحاجة فقط.
--
-- مهم: عدم وجود أي صف ليوم معيّن يعني "لا نعرف" (حالة غير محدَّدة) وليس
-- "مغلق" — لا نريد وصم محل بـ"مغلق" ظلمًا لمجرد أنه لم يملأ النموذج
-- بعد. حساب "مفتوح الآن" فعليًا يتم في كود التطبيق (Dart)، وهذا الجدول
-- يوفّر فقط البيانات الخام.
-- ============================================================

create table merchant_business_hours (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references merchants (id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  open_time time,
  close_time time,
  is_closed boolean not null default false,
  unique (merchant_id, day_of_week)
);

comment on table merchant_business_hours is 'ساعات عمل كل محل حسب يوم الأسبوع (0=الأحد...6=السبت). يملؤها التاجر من لوحة تحكمه. عدم وجود صف ليوم = حالة غير معروفة، وليست "مغلق".';
comment on column merchant_business_hours.is_closed is 'يوم عطلة أسبوعية ثابتة لهذا المحل (مثلاً الجمعة) — مختلف عن عدم وجود صف أصلًا (غير معروف)';

create index merchant_business_hours_merchant_id_idx on merchant_business_hours (merchant_id);

alter table merchant_business_hours enable row level security;

-- القراءة: أي شخص يقرأ ساعات عمل أي محل مُوافَق عليه (تمامًا كنفس شرط
-- ظهور المحل نفسه للعميل) — لازمة لعرض شارة "مفتوح الآن" في التطبيق.
create policy "merchant_business_hours_select_public"
  on merchant_business_hours for select
  using (
    exists (
      select 1 from merchants m
      where m.id = merchant_business_hours.merchant_id and m.status = 'approved'
    )
  );

-- التاجر يرى ساعات محله دائمًا (حتى لو لم يُوافَق عليه بعد)
create policy "merchant_business_hours_select_own"
  on merchant_business_hours for select
  using (
    exists (
      select 1 from merchants m
      where m.id = merchant_business_hours.merchant_id and m.owner_user_id = auth.uid()
    )
  );

-- التاجر يكتب/يعدّل/يحذف ساعات محله الخاص فقط
create policy "merchant_business_hours_all_own"
  on merchant_business_hours for all
  using (
    exists (
      select 1 from merchants m
      where m.id = merchant_business_hours.merchant_id and m.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from merchants m
      where m.id = merchant_business_hours.merchant_id and m.owner_user_id = auth.uid()
    )
  );

-- الإدارة: صلاحية كاملة (تعديل/حذف احترازي عند الحاجة فقط)
create policy "merchant_business_hours_admin_all"
  on merchant_business_hours for all
  using (public.is_admin())
  with check (public.is_admin());
