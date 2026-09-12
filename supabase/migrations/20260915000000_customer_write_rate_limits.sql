-- ============================================================
-- Migration: حدود معدّل الطلبات (Rate Limiting) — P2
--
-- لا يوجد أي حدّ حاليًا على معدّل إنشاء الطلبات من طرف العميل — ثغرة
-- حقيقية (خطأ فـ التطبيق يكرّر الإرسال، ضغط مزدوج على الزر، أو إساءة
-- استخدام متعمَّدة) قد تُنشئ عشرات الصفوف فـ ثوانٍ. الحماية هنا دفاعية
-- بحتة (Trigger على مستوى القاعدة، لا يعتمد على التطبيق أبدًا) ولا
-- تُغيّر أي سلوك طبيعي — عميل حقيقي لا يرسل 5 طلبات رحلة فـ نفس
-- الدقيقتين مثلًا.
--
-- دالة عامة واحدة تُستخدَم عبر كل الجداول (بدل تكرارها 5 مرّات) —
-- تقرأ اسم الجدول من TG_TABLE_NAME والحدّين من معاملات الـ Trigger
-- (TG_ARGV)، وتفترض عمود customer_id + created_at موجودَين (صحيح فـ
-- الجداول الخمسة أدناه، تحقّقتُ من كل واحد قبل الإضافة).
-- ============================================================

create function public.enforce_customer_write_rate_limit()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_max_count int := tg_argv[0]::int;
  v_window_seconds int := tg_argv[1]::int;
  v_count int;
begin
  -- Edge Functions الموثوقة (Service Role) تتجاوز هذا الفحص — نفس نمط
  -- كل دوال validate_*_status_transition الموجودة أصلًا.
  if auth.role() = 'service_role' then
    return new;
  end if;

  execute format(
    'select count(*) from %I where customer_id = $1 and created_at > now() - make_interval(secs => $2)',
    tg_table_name
  )
  into v_count
  using new.customer_id, v_window_seconds;

  if v_count >= v_max_count then
    raise exception 'عدد كبير من الطلبات فـ وقت قصير — يرجى الانتظار قليلًا قبل المحاولة مجددًا';
  end if;

  return new;
end;
$$;

comment on function public.enforce_customer_write_rate_limit is 'حدّ دفاعي عام على معدّل إنشاء صفوف جديدة لكل عميل — TG_ARGV[0]=الحدّ الأقصى، TG_ARGV[1]=مدة النافذة بالثواني. مُرفَق كـ BEFORE INSERT على orders/ride_requests/delivery_requests/craftsman_requests/reviews/driver_reviews (راجع migration 20260915000000).';

-- الطلبات الفعلية (سلة/توصيل) — حدّ أوسع قليلًا (نفس العميل قد يُنشئ
-- عدّة طلبات صغيرة متتالية بشكل طبيعي أكثر من رحلة/طلب حرفي).
create trigger orders_rate_limit
  before insert on orders
  for each row execute function public.enforce_customer_write_rate_limit(8, 120);

create trigger ride_requests_rate_limit
  before insert on ride_requests
  for each row execute function public.enforce_customer_write_rate_limit(5, 120);

create trigger delivery_requests_rate_limit
  before insert on delivery_requests
  for each row execute function public.enforce_customer_write_rate_limit(5, 120);

create trigger craftsman_requests_rate_limit
  before insert on craftsman_requests
  for each row execute function public.enforce_customer_write_rate_limit(5, 120);

create trigger reviews_rate_limit
  before insert on reviews
  for each row execute function public.enforce_customer_write_rate_limit(10, 120);

create trigger driver_reviews_rate_limit
  before insert on driver_reviews
  for each row execute function public.enforce_customer_write_rate_limit(10, 120);
