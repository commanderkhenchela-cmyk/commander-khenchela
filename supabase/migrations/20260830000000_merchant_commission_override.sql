-- ============================================================
-- Migration: Per-merchant Commission Override (PRD section 8)
--
-- العمولة الافتراضية المركزية موجودة أصلًا (settings.platform_commission
-- _rate، تُقرأ من create_order — لا شيء Hardcoded في Flutter). الناقص
-- فقط: استثناء نسبة مختلفة لتاجر معيّن (مثال من الطلب: Default=7%,
-- Merchant A=5%). لا نعيد بناء نظام العمولة — نضيف عمودًا واحدًا +
-- سطرين فـ create_order يتحقّقان منه أولًا قبل الرجوع للافتراضي.
--
-- هذه المرحلة تأتي طبيعيًا بعد Wallet (الترتيب المقترح سابقًا): حركات
-- الـ Ledger التلقائية (record_order_commission_ledger) ستعكس من الآن
-- النسبة الفعلية المستخدَمة لكل تاجر تلقائيًا، بلا أي تعديل إضافي هناك
-- — لأنها أصلًا تقرأ orders.platform_commission_amount المحسوبة هنا.
-- ============================================================

alter table merchants add column commission_rate_override numeric(5, 2);

alter table merchants add constraint merchants_commission_rate_override_check
  check (commission_rate_override is null or (commission_rate_override >= 0 and commission_rate_override <= 100));

comment on column merchants.commission_rate_override is 'نسبة عمولة خاصة بهذا التاجر تحديدًا (تتجاوز platform_commission_rate العامة). NULL = يستخدم الإعداد المركزي كالمعتاد. يُحدَّث حصرًا من طرف من يملك صلاحية settings.manage — محمي بـ protect_merchant_commission_override أدناه حتى لو سمحت RLS العامة لـ merchants بتعديلات أخرى.';

-- ============================================================
-- حماية العمود: RLS الحالية لـ merchants (merchants_update_admin) تسمح
-- لـ can_manage_stores() (admin + manager) بتعديل صف المحل عمومًا —
-- تمامًا كصلاحية تمييز المحل أو تصنيفه. لكن العمولة تحديدًا حسّاسة
-- ماليًا بنفس مستوى settings.platform_commission_rate العامة (Super
-- Admin فقط اليوم) — لذا نُقيّدها بعمود إضافي محمي، نفس نمط
-- protect_driver_status() الموجود أصلًا على drivers.status: أي محاولة
-- تعديل لهذا العمود تحديدًا من طرف لا يملك settings.manage تُرَدّ
-- تلقائيًا لقيمتها القديمة، بصمت وبأمان، بدل رفض التحديث كاملًا (حتى لا
-- يفشل تحديث آخر غير متعلّق بالعمولة يحدث فـ نفس الطلب لو أُرسِل معًا).
-- ============================================================

create function public.protect_merchant_commission_override()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.commission_rate_override is distinct from old.commission_rate_override
     and not public.has_capability('settings.manage') then
    new.commission_rate_override := old.commission_rate_override;
  end if;
  return new;
end;
$$;

create trigger merchants_protect_commission_override
  before update on merchants
  for each row execute function public.protect_merchant_commission_override();

-- ============================================================
-- create_order: نفس الجسم الحالي حرفيًا، فقط استبدال نقطة قراءة نسبة
-- العمولة (كانت سطرين، تبقى سطرين) بمنطق "تحقّق من استثناء التاجر
-- أولًا، ثم ارجع للافتراضي العام" — بقية الدالة بلا أي تغيير.
-- ============================================================

create or replace function public.create_order(
  p_merchant_id uuid,
  p_address_id uuid,
  p_items jsonb -- مثال: [{"product_id": "...", "quantity": 2}]
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_subtotal numeric(10, 2) := 0;
  v_commission_rate numeric(5, 2);
  v_platform_commission numeric(10, 2);
  v_merchant_amount numeric(10, 2);
  v_order_id uuid;
  v_item jsonb;
  v_product record;
  v_quantity integer;
  v_line_subtotal numeric(10, 2);
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإنشاء طلب';
  end if;

  if not exists (
    select 1 from merchants where id = p_merchant_id and status = 'approved'
  ) then
    raise exception 'المحل غير موجود أو غير موافَق عليه بعد';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = v_customer_id
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'لا يمكن إنشاء طلب فارغ';
  end if;

  -- إنشاء صف الطلب مبدئيًا بمبالغ صفرية، سنحدّثها بعد حساب المنتجات
  insert into orders (
    customer_id, merchant_id, address_id, status,
    subtotal, commission_rate, platform_commission_amount,
    merchant_amount, delivery_fee, total_amount
  ) values (
    v_customer_id, p_merchant_id, p_address_id, 'pending',
    0, 0, 0, 0, 0, 0
  ) returning id into v_order_id;

  -- المرور على كل منتج مطلوب، والتحقق من سعره وتوفره من الجدول الحقيقي
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, price, is_active, merchant_id into v_product
    from products
    where id = (v_item ->> 'product_id')::uuid;

    if v_product.id is null then
      raise exception 'منتج غير موجود';
    end if;

    if v_product.merchant_id <> p_merchant_id then
      raise exception 'كل منتجات الطلب يجب أن تكون من نفس المحل';
    end if;

    if not v_product.is_active then
      raise exception 'أحد المنتجات لم يعد متوفرًا حاليًا';
    end if;

    v_quantity := (v_item ->> 'quantity')::integer;
    v_line_subtotal := v_product.price * v_quantity;

    insert into order_items (order_id, product_id, quantity, unit_price, subtotal)
    values (v_order_id, v_product.id, v_quantity, v_product.price, v_line_subtotal);

    v_subtotal := v_subtotal + v_line_subtotal;
  end loop;

  -- نسبة العمولة: استثناء هذا التاجر إن وُجد (commission_rate_override)،
  -- وإلا الإعداد المركزي العام كما كان الحال قبل هذا التعديل تمامًا.
  select commission_rate_override into v_commission_rate
  from merchants where id = p_merchant_id;

  if v_commission_rate is null then
    select value::numeric into v_commission_rate
    from settings where key = 'platform_commission_rate';
  end if;

  v_platform_commission := round(v_subtotal * v_commission_rate / 100, 2);
  v_merchant_amount := v_subtotal - v_platform_commission;

  update orders set
    subtotal = v_subtotal,
    commission_rate = v_commission_rate,
    platform_commission_amount = v_platform_commission,
    merchant_amount = v_merchant_amount,
    delivery_fee = 0,
    total_amount = v_subtotal
  where id = v_order_id;

  return v_order_id;
end;
$$;

comment on function public.create_order is 'الطريقة الآمنة الوحيدة لإنشاء طلب - تحسب كل الأرقام من قاعدة البيانات، لا تثق بأي رقم من العميل. نسبة العمولة: استثناء التاجر (merchants.commission_rate_override) إن وُجد، وإلا الإعداد المركزي العام.';
