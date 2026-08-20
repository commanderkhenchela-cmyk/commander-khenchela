# Edge Functions

كود يعمل على سيرفر Supabase (Server-side logic) — تُستخدم فقط للأعمال التي
تحتاج نداء خدمة خارجية (وليس لعمل DB بحت — ذاك يُبنى كدالة Postgres
`security definer`، مثل `create_order`، أنظر `docs/architecture-decisions.md`).

## send-order-notification (PHASE 11)

ترسل إشعار Firebase Cloud Messaging + تسجّل إشعارًا داخل التطبيق (جدول
`notifications`) عند:
- إنشاء طلب جديد → إشعار للتاجر
- تغيّر حالة طلب → إشعار للعميل

### خطوات التفعيل (تُنفَّذ مرة واحدة، خارج الكود)

1. **إنشاء مشروع Firebase** على https://console.firebase.google.com، وتفعيل
   **Cloud Messaging** فيه.
2. **إنشاء Service Account**: Firebase Console → Project Settings → Service
   Accounts → Generate new private key. يحمَّل ملف JSON فيه 3 قيم نحتاجها:
   `project_id`, `client_email`, `private_key`.
3. **نشر هذه الدالة** عبر Supabase Dashboard → Edge Functions → Deploy a
   new function (أو عبر Supabase CLI: `supabase functions deploy
   send-order-notification`).
4. **ضبط الأسرار** في Supabase Dashboard → Edge Functions → Secrets:
   - `FCM_PROJECT_ID` = project_id من ملف JSON
   - `FCM_CLIENT_EMAIL` = client_email من ملف JSON
   - `FCM_PRIVATE_KEY` = private_key من ملف JSON (بكل أسطره، بما فيها
     `-----BEGIN PRIVATE KEY-----`)
   (`SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY` متوفّرتان تلقائيًا، لا
   حاجة لضبطهما)
5. **ربط الدالة بجدول orders**: Supabase Dashboard → Database → Webhooks →
   Create a new webhook:
   - Table: `orders`
   - Events: `INSERT`, `UPDATE`
   - Type: Supabase Edge Functions
   - Edge Function: `send-order-notification`

بعد هذه الخطوات، أي تغيير في جدول `orders` يستدعي الدالة تلقائيًا —
لا حاجة لأي تعديل إضافي في التطبيقات (Flutter/Next.js).

### الجانب الآخر: تسجيل fcm_token من تطبيق Flutter

يحتاج تطبيق الزبون (وتطبيق التاجر لاحقًا) تسجيل Firebase في المشروع نفسه
(`google-services.json` لأندرويد)، طلب إذن الإشعارات، وحفظ التوكن الناتج
في `users.fcm_token` عند تسجيل الدخول. هذا الجزء منفصل تمامًا عن هذه الدالة
ويُبنى في تطبيق Flutter — راجع الحالة في `docs/architecture-decisions.md`.
