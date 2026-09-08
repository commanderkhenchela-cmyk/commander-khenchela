-- ============================================================
-- Migration: "اطلب أي شيء" — إضافة اتجاهَين صريحَين: إرسال/استقبال
--
-- الوضع قبل هذه الـmigration: delivery_requests كانت تدعم فعليًا
-- "استقبال" فقط — عنوان واحد (address_id) يمثّل أين يستلم العميل،
-- والوصف يشرح ماذا وأين يجده الموصّل (صيدلية، مكتب بريد...).
--
-- "إرسال طلبية" مطلوب الآن: العميل يملك غرضًا فعليًا عنده ويريد
-- إيصاله لمكان/شخص آخر. الفرق الجوهري عن "استقبال": الوجهة هنا ليست
-- بالضرورة عنوانًا محفوظًا فـ addresses (المستلِم غالبًا ليس مستخدمًا
-- مسجَّلًا فـ التطبيق أصلًا) — فتُكتَب كنص حرّ (اسم/عنوان/هاتف المستلِم)،
-- تمامًا كما وُصِف الشيء نفسه فـ عمود description أصلًا. address_id
-- يبقى عمودًا واحدًا فـ الحالتين، لكن معناه يختلف حسب request_type:
--   - receive (الافتراضي، السلوك القديم بلا تغيير): address_id = أين
--     يستلم العميل الشيء (الوجهة النهائية).
--   - send: address_id = من أين يُستلَم الغرض فعليًا (عنوان العميل
--     نفسه غالبًا)، وdestination_text (الجديد) = إلى أين/لمن يُسلَّم.
--
-- رسم التوصيل: يبقى محسوبًا بالضبط كما كان (المسافة من موقع الموصّل
-- الحيّ وقت القبول إلى address_id فقط) فـ الحالتين — لا نحاول تسعير
-- "الرحلة الكاملة" شاملةً destination_text النصّي فـ وضع send، لأنه
-- بلا إحداثيات إطلاقًا (نص حرّ لا يمكن قياس مسافة منه). هذا تبسيط
-- مقصود وصادق: الرسم يمثّل "وصول الموصّل إليك لاستلام الغرض"، والرحلة
-- النهائية للمستلِم جزء من الخدمة يقدّمها الموصّل دون تسعير منفصل لها
-- فـ V1 — نفس فلسفة "لا نضمن دقّة كل تفصيل، لكن لا نمنع الخدمة أبدًا".
-- ============================================================

alter table delivery_requests
  add column request_type text not null default 'receive'
  check (request_type in ('send', 'receive'));

alter table delivery_requests add column destination_text text;

alter table delivery_requests add constraint delivery_requests_send_needs_destination
  check (
    request_type = 'receive'
    or (request_type = 'send' and destination_text is not null and trim(destination_text) <> '')
  );

comment on column delivery_requests.request_type is 'send = العميل يملك الغرض ويريد إيصاله لمكان آخر (address_id = من أين يُستلَم، destination_text = إلى أين). receive = العميل يريد استلام غرض (address_id = أين يستلمه، السلوك الأصلي قبل هذه الـmigration).';
comment on column delivery_requests.destination_text is 'نص حرّ يصف وجهة التسليم (اسم/عنوان/هاتف المستلِم) — يُستخدَم فقط فـ request_type=send، لأن المستلِم غالبًا ليس مستخدمًا مسجَّلًا بعنوان محفوظ فـ addresses.';

-- ============================================================
-- تحديث create_delivery_request — إضافة p_request_type وp_destination_text
-- (بمعاملَين افتراضيَّين، فلا يكسر أي استدعاء قديم لو بقي أحدهما ناقصًا).
-- CREATE OR REPLACE لا يكفي وحده هنا لأن عدد المعاملات يتغيّر — Postgres
-- يعتبرها دالة جديدة منفصلة (Overload) بدل استبدال القديمة فعليًا، فيُحذَف
-- التوقيع القديم صراحةً أولًا لتفادي وجود نسختين غامضتين معًا.
-- ============================================================
drop function if exists public.create_delivery_request(uuid, text);

create function public.create_delivery_request(
  p_address_id uuid,
  p_description text,
  p_request_type text default 'receive',
  p_destination_text text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_request_id uuid;
begin
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإنشاء طلب';
  end if;

  if exists (select 1 from users where id = v_customer_id and is_suspended) then
    raise exception 'حسابك موقوف، يرجى التواصل مع الإدارة';
  end if;

  if not exists (
    select 1 from addresses where id = p_address_id and user_id = v_customer_id
  ) then
    raise exception 'العنوان غير صالح أو لا يخصك';
  end if;

  if trim(coalesce(p_description, '')) = '' then
    raise exception 'صف ما تريد طلبه أولًا';
  end if;

  if p_request_type not in ('send', 'receive') then
    raise exception 'نوع الطلب غير صالح';
  end if;

  if p_request_type = 'send' and trim(coalesce(p_destination_text, '')) = '' then
    raise exception 'حدّد وجهة التسليم أولًا';
  end if;

  insert into delivery_requests (
    customer_id, address_id, description, status, request_type, destination_text
  )
  values (
    v_customer_id, p_address_id, trim(p_description), 'pending', p_request_type,
    case when p_request_type = 'send' then trim(p_destination_text) else null end
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.create_delivery_request is 'ينشئ طلب "اطلب أي شيء" (إرسال أو استقبال) بحالة pending، بلا أي رسوم توصيل محسوبة بعد — تُحسَب فقط عند القبول (driver_accept_delivery_request)، لأن نقطة انطلاق الموصّل غير معروفة قبل ذلك.';

-- ============================================================
-- تصحيح الاسم المعروض للخدمة: كانت "التوصيل" منذ الإنشاء الأولي، لكن
-- هذا الاسم محجوز الآن لخدمة مستقبلية منفصلة تمامًا (شاحنات الشحن/شاحنات
-- المياه، slug جديد خاص بها حين تُبنى). slug='delivery' الداخلي يبقى
-- كما هو بلا أي تغيير (غير مرئي للمستخدم، ويستخدمه الكود فـ أكثر من
-- مكان) — فقط الاسم المعروض للعميل يتغيّر.
-- ============================================================
update services set name = 'اطلب أي شيء' where slug = 'delivery';
