-- ============================================================
-- Migration: ربط جدول orders بدالة send-order-notification مباشرة عبر
-- pg_net، بدل ميزة "Database Webhooks" الجاهزة في واجهة Supabase.
--
-- السبب: بعض مشاريع Supabase (هذا المشروع تحديدًا) تفتقد schema داخليًا
-- (supabase_functions) تعتمد عليه ميزة الـ Webhooks الجاهزة، فتفشل
-- إضافة أي webhook برسالة "schema supabase_functions does not exist" —
-- خلل منصّة، وليس خطأ في هذا المشروع. الحل: Trigger عادي يستدعي
-- pg_net.http_post مباشرة، بنفس شكل الـ payload الذي كانت سترسله ميزة
-- Webhooks أصلًا (type/table/schema/record/old_record) — دالة Edge
-- Function نفسها (send-order-notification) لم تتغيّر منطقيًا، فقط
-- طريقة استدعائها.
--
-- الحماية: بما أن الدالة نُشرت بـ --no-verify-jwt (مفتاح anon الحديث
-- بصيغة sb_publishable_ ليس JWT صالحًا لتحقّق Supabase التلقائي)، السرّ
-- المشترك WEBHOOK_SECRET (مضبوط أيضًا في Edge Functions → Secrets) هو
-- الحماية الفعلية الوحيدة — يُرسَل في ترويسة x-webhook-secret، وتتحقق
-- منه الدالة قبل تنفيذ أي شيء.
-- ============================================================

-- pg_net غير قابل لإعادة التموضع (relocatable = false) — يُثبَّت دائمًا
-- في مخطط net الخاص به تلقائيًا، بغض النظر عن أي WITH SCHEMA.
create extension if not exists pg_net;

create function public.notify_order_webhook()
returns trigger
language plpgsql
security definer set search_path = public, net
as $$
begin
  perform net.http_post(
    url := 'https://dwmllbtvhzilwrmyurom.supabase.co/functions/v1/send-order-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', 'os_RUf3hsYG6Dl42BLqwKEr5K3hHqaVRtNV5gUW2O74'
    ),
    body := jsonb_build_object(
      'type', tg_op,
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', case when tg_op = 'UPDATE' then to_jsonb(old) else null end
    )
  );
  return new;
end;
$$;

comment on function public.notify_order_webhook is 'يستدعي Edge Function send-order-notification عبر pg_net عند أي INSERT/UPDATE على orders — بديل عن ميزة Database Webhooks الجاهزة (راجع تعليق الدالة أعلاه لسبب عدم استخدامها).';

drop trigger if exists orders_notify_webhook on orders;
create trigger orders_notify_webhook
  after insert or update on orders
  for each row execute function public.notify_order_webhook();
