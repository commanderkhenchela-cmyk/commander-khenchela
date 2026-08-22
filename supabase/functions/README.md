# Edge Functions

كود يعمل على سيرفر Supabase (Server-side logic) — تُستخدم فقط للأعمال التي
تحتاج نداء خدمة خارجية (وليس لعمل DB بحت — ذاك يُبنى كدالة Postgres
`security definer`، مثل `create_order`، أنظر `docs/architecture-decisions.md`).

## send-order-notification (PHASE 11 + شبكة الإشعارات)

تسجّل إشعارًا داخل التطبيق دائمًا (جدول `notifications`، يظهر فورًا بغضّ
النظر عن نجاح Push الخارجي)، ثم تحاول أيضًا إرسال Firebase Cloud
Messaging إن توفّر `fcm_token`. مغطّاة حاليًا:
- `orders`: إنشاء طلب جديد → إشعار للتاجر، تغيّر حالة → إشعار للعميل
- `merchants`: تسجيل تاجر جديد → إشعار لكل الإدارة (admin/manager)،
  موافقة/رفض → إشعار للتاجر نفسه (راجع migration
  `20260822000000_notifications_network.sql`)
- `drivers`: تسجيل موصّل جديد → إشعار لكل الإدارة، موافقة/رفض → إشعار
  للموصّل نفسه (راجع migration `20260822010000_drivers.sql`)

**تنبيه تشغيلي**: بما أن كود هذه الدالة تغيّر (إضافة فرع `merchants`)،
يجب **إعادة نشرها** بنفس أمر الخطوة 3 أدناه حتى تصل التغييرات لمشروع
Supabase الفعلي — تعديل الملف هنا وحده لا يكفي.

### خطوات التفعيل (تُنفَّذ مرة واحدة، خارج الكود)

1. **إنشاء مشروع Firebase** على https://console.firebase.google.com، وتفعيل
   **Cloud Messaging** فيه.
2. **إنشاء Service Account**: Firebase Console → Project Settings → Service
   Accounts → Generate new private key. يحمَّل ملف JSON فيه 3 قيم نحتاجها:
   `project_id`, `client_email`, `private_key`.
3. **نشر هذه الدالة** عبر Supabase CLI **بدون** التحقق التلقائي من JWT
   (مفتاح anon الحديث بصيغة `sb_publishable_...` ليس JWT صالحًا لهذا
   التحقق أصلًا؛ الحماية الفعلية سرّ مشترك، راجع الخطوة 5):
   ```
   supabase functions deploy send-order-notification --no-verify-jwt
   ```
4. **ضبط الأسرار** في Supabase Dashboard → Edge Functions → Secrets:
   - `FCM_PROJECT_ID` = project_id من ملف JSON
   - `FCM_CLIENT_EMAIL` = client_email من ملف JSON
   - `FCM_PRIVATE_KEY` = private_key من ملف JSON (بكل أسطره، بما فيها
     `-----BEGIN PRIVATE KEY-----`)
   - `WEBHOOK_SECRET` = سرّ مشترك عشوائي (نفس القيمة المكتوبة في
     migration `20260821110000_order_notify_trigger.sql`)
   (`SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY` متوفّرتان تلقائيًا، لا
   حاجة لضبطهما)
5. **ربط الدالة بالجداول**: طُبِّق تلقائيًا عبر migrations
   `20260821110000_order_notify_trigger.sql` (جدول `orders`)،
   `20260822000000_notifications_network.sql` (جدول `merchants`)، و
   `20260822010000_drivers.sql` (جدول `drivers`) — كلها تعيد استخدام
   نفس دالة الـ trigger العامة. Trigger عادي يستدعي الدالة
   مباشرة عبر `pg_net` عند كل INSERT/UPDATE، **بديل** عن ميزة "Database
   Webhooks" الجاهزة في الواجهة (بعض المشاريع تفتقد schema داخليًا
   `supabase_functions` تعتمد عليه تلك الميزة، فتفشل بخطأ "schema
   supabase_functions does not exist" — خلل منصّة، لا حاجة لأي إعداد
   يدوي إضافي من الواجهة إن كنت تستخدم هذه الـ migrations).

بعد هذه الخطوات، أي تغيير في `orders` أو `merchants` أو `drivers` يستدعي
الدالة تلقائيًا — لا حاجة لأي تعديل إضافي في التطبيقات (Flutter/Next.js)،
فقط شاشة/صفحة تعرض جدول `notifications` (موجودة الآن في تطبيق الزبون،
لوحتي التاجر والإدارة، وتطبيق الموصّل).

### الجانب الآخر: تسجيل fcm_token من تطبيق Flutter

يحتاج تطبيق الزبون (وتطبيق التاجر لاحقًا) تسجيل Firebase في المشروع نفسه
(`google-services.json` لأندرويد)، طلب إذن الإشعارات، وحفظ التوكن الناتج
في `users.fcm_token` عند تسجيل الدخول. هذا الجزء منفصل تمامًا عن هذه الدالة
ويُبنى في تطبيق Flutter — راجع الحالة في `docs/architecture-decisions.md`.
