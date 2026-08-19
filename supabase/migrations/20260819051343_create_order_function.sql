-- ============================================================
-- Migration: دالة create_order — الطريقة الآمنة الوحيدة لإنشاء طلب
-- ============================================================
-- تستقبل: معرّف المحل، معرّف العنوان، وقائمة المنتجات المطلوبة (بدون أسعار!)
-- تحسب: كل الأرقام المالية بنفسها من قاعدة البيانات الحقيقية.
-- تُنفَّذ كـ "معاملة واحدة" (Transaction): إما ينجح كل شيء، أو لا يُحفظ شيء.
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

  -- جلب نسبة العمولة الحالية من settings (لا يستطيع أي عميل قراءتها مباشرة)
  select value::numeric into v_commission_rate
  from settings where key = 'platform_commission_rate';

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

comment on function public.create_order is 'الطريقة الآمنة الوحيدة لإنشاء طلب - تحسب كل الأرقام من قاعدة البيانات، لا تثق بأي رقم من العميل';
