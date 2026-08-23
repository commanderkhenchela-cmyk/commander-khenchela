-- ============================================================
-- إصلاح أمني: نقل WEBHOOK_SECRET من نص واضح داخل الكود (Migration
-- 20260821110000) إلى Supabase Vault — السرّ القديم كان مكتوبًا حرفيًا
-- فـ ملف SQL مرفوع لـ Git، أي مكشوف بشكل دائم فـ تاريخ المستودع لأي
-- طرف يملك صلاحية قراءته.
--
-- الحل: notify_order_webhook() تقرأ السرّ الآن من vault.decrypted_secrets
-- (تخزين مشفَّر داخل قاعدة البيانات نفسها، غير موجود إطلاقًا فـ أي ملف
-- Migration مرفوع)، بدل قيمة مكتوبة مباشرة فـ الكود.
--
-- **خطوة يدوية إجبارية بعد تطبيق هذا الـ Migration** (لا يمكن إنجازها
-- تلقائيًا — تحتاج SQL Editor فـ Supabase Dashboard مباشرة):
--
-- 1) ولّد سرًّا جديدًا عشوائيًا (السرّ القديم أصبح مكشوفًا، يجب عدم
--    إعادة استخدامه أبدًا)، ثم فـ SQL Editor:
--      select vault.create_secret('السرّ-الجديد-هنا', 'webhook_secret');
--
-- 2) حدّث نفس القيمة فـ Edge Function Secrets (نفس الأمر يلي استُعمل من
--    قبل):
--      supabase secrets set WEBHOOK_SECRET=السرّ-الجديد-هنا
--
-- 3) بدون الخطوتين أعلاه، الدالة تعمل لكن ترسل ترويسة سرّ فارغة، فتُرفض
--    الطلبات من طرف send-order-notification (يفشل بصمت — الطلب يبقى
--    يُنشأ عادي، فقط الإشعار الفوري/Push لا يصل حتى تُنجَز الخطوتان).
-- ============================================================

create or replace function public.notify_order_webhook()
returns trigger
language plpgsql
security definer set search_path = public, net, vault
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'webhook_secret'
  limit 1;

  perform net.http_post(
    url := 'https://dwmllbtvhzilwrmyurom.supabase.co/functions/v1/send-order-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', coalesce(v_secret, '')
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

comment on function public.notify_order_webhook is 'يستدعي Edge Function send-order-notification عبر pg_net عند أي INSERT/UPDATE على orders/merchants/drivers — السرّ المشترك يُقرأ من Supabase Vault (راجع تعليق هذا الـ Migration للخطوة اليدوية المطلوبة بعد التطبيق)، وليس نصًا واضحًا فـ الكود.';
