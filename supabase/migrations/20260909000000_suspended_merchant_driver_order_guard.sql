-- ============================================================
-- Migration: سدّ فجوة إنفاذ الإيقاف على تقدّم حالة orders
--
-- الوضع قبل هذه الـmigration (اكتُشف فـ مراجعة أمنية): users.is_suspended
-- (migration 20260831000000_fraud_system) يمنع فعليًا إنشاء طلب جديد
-- (create_order) واستلام طلب كموصّل (driver_claim_order) فقط — موثَّق
-- بصراحة فـ تعليق العمود نفسه أن الإنفاذ الأوسع مؤجَّل. لكن
-- validate_order_status_transition (محرّك انتقالات orders) لم يكن
-- يتحقق من is_suspended إطلاقًا: تاجر مُوقَف بعد إنشاء طلب موجود لديه
-- سلفًا يقدر رغم ذلك يؤكّده/يرفضه/يحضّره/يجهّزه للاستلام، وموصّل مُوقَف
-- بعد أن استلم طلبًا فعليًا (قبل إيقافه) يقدر يواصل تقديمه حتى delivered
-- — كلاهما "يستخدم" الحساب فعليًا رغم الإيقاف، بخلاف الهدف المعلَن
-- للعمود.
--
-- الإصلاح: نفس نمط create_order/driver_claim_order بالحرف — استثناء
-- صريح واحد يمنع فقط صاحب المحل (is_merchant_owner) أو الموصّل المعيَّن
-- (is_assigned_driver) الموقوفَين تحديدًا من أي انتقال، مع إبقاء صلاحية
-- الإدارة (actor_role admin/manager) كاملة بلا أي تأثير — الإدارة تبقى
-- قادرة دائمًا على تحريك أي طلب عالق لحسابه الخاص. لا نمنع العميل من
-- إلغاء طلبه الخاص وهو pending حتى لو كان حسابه موقوفًا (نفس الانتقال
-- المسموح به مسبقًا new.customer_id = auth.uid()) — هذا إجراء self-
-- service حميد لا يمثّل "استخدام المنصّة" فعليًا، ولا داعي لمنعه.
--
-- CREATE OR REPLACE يكفي هنا (بلا DROP FUNCTION IF EXISTS أولًا) —
-- توقيع الدالة (بلا معاملات، دالة Trigger) لم يتغيّر إطلاقًا، فقط
-- جسمها؛ خلافًا لحالة create_delivery_request (migration
-- 20260908000000) حيث تغيّر عدد المعاملات فعليًا واستلزم DROP صريح.
--
-- نطاق هذه الـmigration: جدول orders (Marketplace) فقط — الأعلى حجمًا
-- وقيمة ماليًا. نفس الفجوة موجودة بنفس البنية فـ
-- validate_delivery_request_status_transition وvalidate_ride_request_
-- status_transition (لا فحص is_suspended فـ فرع is_assigned_driver فـ
-- كليهما) — تُركت عمدًا لهذه الـmigration لتبقى محدودة الأثر ومركَّزة،
-- تُذكَر بوضوح كمتابعة مقترحة منفصلة، لا تُدَّعى منجَزة هنا.
-- ============================================================

create or replace function public.validate_order_status_transition()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor_role text;
  actor_suspended boolean;
  is_merchant_owner boolean;
  is_assigned_driver boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  -- Edge Functions الموثوقة (Service Role) تتجاوز هذا الفحص
  if auth.role() = 'service_role' then
    return new;
  end if;

  select role, coalesce(is_suspended, false)
    into actor_role, actor_suspended
  from users where id = auth.uid();

  is_merchant_owner := exists (
    select 1 from merchants m
    where m.id = new.merchant_id and m.owner_user_id = auth.uid()
  );

  is_assigned_driver := exists (
    select 1 from drivers d
    where d.id = old.driver_id and d.user_id = auth.uid()
  );

  -- الإصلاح الفعلي: تاجر أو موصّل موقوف يُمنَع من أي تقدّم بحالة طلب،
  -- بغضّ النظر عن أي شرط آخر أدناه. الإدارة (actor_role admin/manager)
  -- غير متأثرة إطلاقًا، والعميل يبقى قادرًا على إلغاء طلبه الخاص.
  if actor_suspended and (is_merchant_owner or is_assigned_driver) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if old.status in ('delivered', 'cancelled', 'rejected') then
    raise exception 'لا يمكن تغيير حالة طلب في حالة نهائية (%)', old.status;
  end if;

  if old.status = 'pending' and new.status = 'confirmed' and is_merchant_owner then
    return new;
  elsif old.status = 'pending' and new.status = 'rejected' and is_merchant_owner then
    return new;
  elsif old.status = 'pending' and new.status = 'cancelled'
        and (new.customer_id = auth.uid() or actor_role = 'admin') then
    return new;
  elsif old.status = 'confirmed' and new.status = 'preparing' and is_merchant_owner then
    return new;
  elsif old.status = 'confirmed' and new.status = 'cancelled' and actor_role = 'admin' then
    return new;
  elsif old.status = 'preparing' and new.status = 'ready_for_pickup' and is_merchant_owner then
    return new;
  elsif old.status = 'preparing' and new.status = 'cancelled' and actor_role = 'admin' then
    return new;
  elsif old.status = 'ready_for_pickup' and new.status = 'picked_up'
        and (actor_role = 'admin' or is_assigned_driver) then
    return new;
  elsif old.status = 'picked_up' and new.status = 'out_for_delivery'
        and (actor_role = 'admin' or is_assigned_driver) then
    return new;
  elsif old.status = 'out_for_delivery' and new.status = 'delivered'
        and (actor_role = 'admin' or is_assigned_driver) then
    return new;
  else
    raise exception 'انتقال حالة غير مسموح: من % إلى %', old.status, new.status;
  end if;
end;
$$;

comment on function public.validate_order_status_transition is 'محرّك انتقالات orders — نفس النسخة الأصلية (migration 20260822010000) بإضافة فحص is_suspended واحد لصاحب المحل/الموصّل المعيَّن قبل أي شيء آخر. الإدارة والعميل (إلغاء طلبه الخاص) غير متأثرين.';
