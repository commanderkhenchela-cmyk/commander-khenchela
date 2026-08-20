# التقرير النهائي — Commander Khenchela

هذا التقرير يجاوب على كل الأسئلة التي طُلبت: أين أعدّل كل شيء، كيف أشغّل كل تطبيق، وما الذي أُنجز فعليًا في هذه الجلسة وما الذي بقي (ولماذا).

**تاريخ التقرير:** 20 أغسطس 2026
**الفرع:** `claude/commander-khenchela-setup-bfeibw`

---

## 0. ملاحظة مهمة قبل كل شيء — نقاط تعارض مع طلب اليوم

وصلتني اليوم رسالة تطلب إكمال المشروع "بالكامل" بما يشمل: تطبيق سائق (Driver)، Firebase Firestore، بناء iOS فعلي، ودعم لغتين إضافيتين (فرنسية/إنجليزية). قبل أن أنفّذ أي شيء بشكل أعمى، هذه هي النقاط التي **تتعارض مع قرارات معمارية اتخذناها أنت وأنا معًا سابقًا في هذا المشروع بالذات** (ووافقت عليها صراحة كل مرة)، فأبقيتها كما هي بدل تغييرها من دون علمك:

| ما طُلب اليوم | القرار السابق المتفق عليه | لماذا لم أغيّره |
|---|---|---|
| Firebase Firestore كقاعدة بيانات | **Supabase (PostgreSQL)** هي قاعدة البيانات الوحيدة، Firebase فقط للإشعارات (FCM) | القاعدة الحالية مبنية بالكامل ومُختبرة (RLS، دوال، جداول). تحويلها لـ Firestore يعني إعادة بناء المشروع من الصفر وتدمير كل ما اشتغل فعليًا اليوم |
| تطبيق سائق (Driver App) كامل | التوصيل يدوي بالكامل عبر Admin في V1 (قرار PHASE 1)، البنية جاهزة لإضافته لاحقًا بدون كسر شيء | كنت وافقت على هذا صراحة، وجدول `delivery_drivers` مؤجَّل عمدًا وموثَّق السبب |
| بناء نسخة iOS فعلية (ملف .ipa) | Android أولًا، "iOS-ready architecture" (بنية جاهزة، ليس بناء فعلي) | **بناء iOS يتطلب جهاز Mac وXcode وحساب Apple Developer** — لا يوجد أي منها هنا (بيئتي Linux، جهازك Windows). الكود Flutter نفسه لا يحتوي أي شيء يمنع iOS مستقبلًا (أنظر القسم 17) |
| دعم فرنسي/إنجليزي | عربي فقط (RTL) في V1 | إضافة لغتين يعني ترجمة كل نص في كل شاشة — عمل كبير مؤجَّل عمدًا سابقًا لتبسيط V1 |

**لم أفعل** أيًا من هذه الأربعة. **فعلت كل شيء آخر ممكن تنفيذه فعليًا** ضمن هذه الجلسة، مذكور بالتفصيل أدناه. إذا كنت تريد فعلًا إعادة النظر في أي من هذه الأربعة، أخبرني وسأنفّذها — لكن لن أفعل ذلك بصمت لأنها تُغيّر أساس المشروع.

---

## 1. ملخص ما أُنجز في هذه الجلسة (إضافة لما كان موجودًا)

### أ) تطبيق الزبون (Flutter) — ميزات جديدة
- **شاشة بداية (Splash Screen)** حقيقية — وأثناء بنائها اكتشفت وأصلحت **خلل تنقّل فعلي**: كانت الشاشة السابقة تحفظ "تأكيد الولاية" لكن لا أحد يقرأها، فكان المستخدم يعيد نفس خطوات الإعداد في كل فتح للتطبيق. الآن: إذا سبق للمستخدم تأكيد ولايته، ينتقل مباشرة لقائمة المحلات.
- **شاشة "المساعدة"** — أسئلة شائعة + تواصل (واتساب/اتصال/بريد).
- **تفاصيل الطلب + إلغاء ذاتي** للطلبات قيد المراجعة.
- **رفع صور حقيقي للمنتجات** (Supabase Storage) بدل روابط يدوية.
- **تصنيف المنتجات** داخل صفحة كل محل.
- **دعم عدة عناوين توصيل** (منزل/عمل...)، مع عنوان افتراضي.
- **شاشة إشعارات داخل التطبيق** (تُملأ تلقائيًا فور تفعيل Firebase).
- **دعم Web** — التطبيق نفسه يعمل الآن كموقع ويب أيضًا (`flutter build web` نجح فعليًا، أنظر القسم 18).
- تصحيح اسم التطبيق الظاهر على الشاشة الرئيسية للهاتف (كان "customer_app"، أصبح "Commander Khenchela").

### ب) لوحة تحكم التاجر ولوحة الإدارة (Next.js) — موجودتان وتعملان
مبنيتان بالكامل من جلسة سابقة اليوم، ومُختبرتان فعليًا على جهازك (تسجيل دخول، موافقة على محل، رفع منتج بصورة).

### ج) قاعدة البيانات (Supabase)
كل الجداول، RLS، الدوال، وMigrations موجودة ومُطبَّقة (أنت طبّقتها بنفسك خطوة بخطوة طوال اليوم).

### د) فحص شامل للأخطاء
شغّلت `flutter analyze` و`flutter test` على تطبيق الزبون، و`eslint`/`next build` على لوحتي التاجر والإدارة — **لا توجد أي أخطاء أو تحذيرات حاليًا** في الثلاثة.

---

## 2. الملفات الجديدة التي أُنشئت اليوم (هذه الجلسة تحديدًا)

| الملف | وظيفته |
|---|---|
| `apps/customer_app/lib/screens/splash_screen.dart` | شاشة البداية — تقرر أين يذهب المستخدم (ترحيب أو مباشرة للمحلات) |
| `apps/customer_app/lib/screens/support_screen.dart` | شاشة "المساعدة" — أسئلة شائعة وتواصل |
| `apps/customer_app/lib/config/support_config.dart` | أرقام/بريد التواصل — **عدّلها هنا فقط** |
| `apps/customer_app/lib/screens/address_list_screen.dart` | شاشة "عناويني" — قائمة كل العناوين المحفوظة |
| `apps/customer_app/lib/screens/address_form_screen.dart` | إضافة/تعديل عنوان واحد (يحلّ محل `address_screen.dart` القديم) |
| `apps/customer_app/lib/screens/order_detail_screen.dart` | تفاصيل طلب واحد + زر الإلغاء |
| `apps/customer_app/lib/models/order_detail.dart` | نموذج بيانات تفاصيل الطلب |
| `apps/customer_app/lib/screens/notifications_screen.dart` | شاشة "إشعاراتي" داخل التطبيق |
| `apps/customer_app/lib/models/notification_item.dart` | نموذج بيانات الإشعار |
| `apps/customer_app/web/*` | ملفات دعم الويب (تلقائية من Flutter) |
| `apps/merchant-dashboard/*` (مجلد كامل) | لوحة تحكم التاجر (Next.js) |
| `apps/admin-dashboard/*` (مجلد كامل) | لوحة تحكم الإدارة (Next.js) |
| `supabase/functions/send-order-notification/index.ts` | الدالة التي ترسل إشعار Firebase عند تغيّر حالة الطلب |
| `supabase/migrations/202608200*.sql` (5 ملفات) | صلاحيات الإدارة، تخزين الصور، عمود fcm_token، إصلاح خلل RLS |
| `docs/final-report.md` | هذا الملف |

## 3. الملفات المهمة التي عُدِّلت

| الملف | ماذا تغيّر |
|---|---|
| `apps/customer_app/lib/main.dart` | نقطة الدخول الآن `SplashScreen` بدل `WelcomeScreen` مباشرة |
| `apps/customer_app/lib/screens/account_screen.dart` | أُضيفت أزرار "عناويني" و"المساعدة" |
| `apps/customer_app/lib/screens/checkout_screen.dart` | يحمّل العنوان الافتراضي تلقائيًا، ويسمح باختيار عنوان آخر محفوظ |
| `apps/customer_app/lib/screens/my_orders_screen.dart` | كل طلب أصبح قابلًا للضغط لفتح تفاصيله |
| `apps/customer_app/lib/screens/merchant_products_screen.dart` | عرض صور المنتجات الحقيقية + تصنيفها |
| `apps/customer_app/lib/models/product.dart`, `address.dart` | حقول جديدة (الصورة، التصنيف، العنوان الافتراضي) |
| `apps/customer_app/android/app/src/main/AndroidManifest.xml` | اسم التطبيق على الشاشة الرئيسية |
| `apps/customer_app/ios/Runner/Info.plist` | نفس الشيء لـ iOS |
| `apps/merchant-dashboard/app/dashboard/products/product-form.tsx` | رفع صورة حقيقية بدل رابط نصي |

---

## 4. أين توجد كل شاشة (تطبيق الزبون)

المسار الأساسي: `apps/customer_app/lib/screens/`

| الشاشة | الملف |
|---|---|
| البداية (Splash) | `splash_screen.dart` |
| الترحيب | `welcome_screen.dart` |
| تأكيد الولاية | `confirm_wilaya_screen.dart` |
| قائمة المحلات | `merchants_screen.dart` |
| منتجات محل واحد | `merchant_products_screen.dart` |
| السلة | `cart_screen.dart` |
| تسجيل الدخول | `login_screen.dart` |
| إنشاء حساب | `signup_screen.dart` |
| إتمام الطلب | `checkout_screen.dart` |
| تأكيد الطلب | `order_confirmation_screen.dart` |
| قائمة عناويني | `address_list_screen.dart` |
| إضافة/تعديل عنوان | `address_form_screen.dart` |
| طلباتي | `my_orders_screen.dart` |
| تفاصيل طلب | `order_detail_screen.dart` |
| حسابي | `account_screen.dart` |
| إشعاراتي | `notifications_screen.dart` |
| المساعدة | `support_screen.dart` |

**ملاحظة عن "استرجاع كلمة المرور":** حسابات الزبائن تُنشأ برقم الهاتف وكلمة مرور فقط (بدون بريد إلكتروني حقيقي أو رسالة SMS — هذا قرار سابق لتفادي تكلفة Twilio المؤجَّلة). لذلك "استرجاع كلمة المرور تلقائيًا" غير ممكن حاليًا بدون تفعيل خدمة SMS (Twilio) أو إضافة بريد حقيقي عند التسجيل. حاليًا: إذا نسي عميل كلمة مروره، الحل الوحيد هو تغييرها يدويًا من طرفك عبر Supabase (نفس الطريقة التي غيّرنا بها كلمة مرور حساب الإدارة اليوم).

---

## 5. أين أغيّر ألوان التطبيق

`apps/customer_app/lib/theme/app_theme.dart` — اللون الأساسي الأخضر معرَّف في متغير واحد بالأعلى (`primary = Color(0xFF1B7A3D)`), غيّره وسيتغير في كل التطبيق تلقائيًا.

للوحتي التاجر والإدارة: `apps/merchant-dashboard/app/globals.css` و`apps/admin-dashboard/app/globals.css` — متغيرات `--primary` في أعلى الملف.

## 6. أين أغيّر الشعار (Logo)

حاليًا **لا يوجد ملف صورة شعار حقيقي** — الشعار مبني بالكود (أيقونة `Icons.storefront_rounded` داخل مربع أخضر) في:
- `apps/customer_app/lib/screens/welcome_screen.dart`
- `apps/customer_app/lib/screens/splash_screen.dart`

لوضع صورة شعار حقيقية: ضع ملف الصورة في `apps/customer_app/assets/`، فعّل قسم `assets:` في `pubspec.yaml` (موجود لكن معطَّل بتعليق `#`)، ثم استبدل الأيقونة بـ `Image.asset(...)` في الملفين أعلاه. هذه خطوة تحتاج ملف تصميم فعلي منك أولًا (لوغو PNG/SVG بخلفية شفافة).

أيقونة التطبيق على الهاتف (Home Screen icon): تُولَّد من نفس ملف الشعار عبر أداة `flutter_launcher_icons` (غير مثبَّتة بعد) — أخبرني إذا أردتها.

## 7. أين أغيّر اسم التطبيق

- الاسم الظاهر داخل الشاشات: `apps/customer_app/lib/main.dart` (`title:` في `MaterialApp`) و`welcome_screen.dart`/`splash_screen.dart`
- اسم التطبيق على شاشة الهاتف الرئيسية (Android): `apps/customer_app/android/app/src/main/AndroidManifest.xml` → `android:label`
- نفس الشيء لـ iOS: `apps/customer_app/ios/Runner/Info.plist` → `CFBundleDisplayName`
- عنوان تبويب المتصفح (نسخة الويب): `apps/customer_app/web/index.html` → `<title>`

## 8. أين أغيّر النصوص

كل نص عربي مكتوب مباشرة داخل الشاشة المعنية نفسها (لا يوجد ملف ترجمة مركزي حاليًا لأن اللغة عربية فقط في V1). للتعديل: افتح ملف الشاشة من القسم 4 أعلاه، وابحث عن النص بين علامتي تنصيص.

## 9. أين أغيّر أسعار التوصيل

رسوم التوصيل **ليست رقمًا ثابتًا عامًا** — قرار مقصود لأن التوصيل يدوي والمسافة تختلف من طلب لآخر. تُحدَّد **لكل طلب على حدة من لوحة الإدارة**:
`apps/admin-dashboard/app/dashboard/orders/[id]/delivery-fee-form.tsx`

نسبة عمولة المنصة (وليست رسوم التوصيل) تُعدَّل من: لوحة الإدارة ← إعدادات المنصة (`apps/admin-dashboard/app/dashboard/settings/`).

## 10. أين أغيّر البلديات والمناطق

جدول `communes` في قاعدة البيانات (Supabase)، أُدخلت فيه بلديات ولاية خنشلة الـ21 عبر:
`supabase/migrations/20260819043836_create_wilayas_and_communes.sql`

لإضافة ولاية جديدة مستقبلًا (خارج خنشلة): أضف صفوفًا جديدة في جدولي `wilayas`/`communes` عبر SQL Editor في Supabase — لا حاجة لتعديل أي كود Dart أو TypeScript، القوائم في التطبيق تُقرأ من قاعدة البيانات مباشرة.

## 11. أين أغيّر إعدادات Firebase

- مفتاح الاتصال بـ Supabase (وليس Firebase — التذكير: القاعدة الرئيسية Supabase): `apps/customer_app/lib/config/supabase_config.dart`
- إعدادات Firebase (بعد إنشائك للمشروع): ستحتاج تثبيت حزمتي `firebase_core`/`firebase_messaging` وتوليد `firebase_options.dart` عبر أداة FlutterFire — **لم يُنفَّذ بعد لأن مشروع Firebase نفسه لم يُنشأ بعد** (قرارك المؤجَّل). الأسرار الخادمية (Service Account) تُضبط في: Supabase Dashboard ← Edge Functions ← Secrets (وليس في الكود).

## 12. أين أغيّر إعدادات الإشعارات

منطق تحديد "من يُخطَر ولماذا" موجود بالكامل في: `supabase/functions/send-order-notification/index.ts` (نصوص الإشعارات العربية حسب حالة الطلب معرَّفة في `ORDER_STATUS_LABELS` بأعلى الملف). خطوات التفعيل الكاملة موثَّقة في `supabase/functions/README.md`.

## 13. أين أغيّر إعدادات Admin

- إنشاء/إدارة حسابات الإدارة: يدويًا عبر Supabase Dashboard (موثَّق في `apps/admin-dashboard/README.md`) — لا صفحة تسجيل ذاتي عمدًا (أمان)
- كل شاشات ووظائف لوحة الإدارة: `apps/admin-dashboard/app/dashboard/`
- صلاحيات قاعدة البيانات الخاصة بالإدارة: `supabase/migrations/20260820030000_admin_capabilities.sql` و`20260820040000_fix_admin_rls_recursion.sql`

---

## 14-15. كيف أشغّل تطبيق الزبون ولوحتي التاجر/الإدارة

نفس الطريقة المتبعة طوال هذه الجلسة (على جهاز Windows، عبر VS Code Terminal):

```powershell
cd "C:\Users\HP ZBook\Documents\commander-khenchela"
git pull origin claude/commander-khenchela-setup-bfeibw
```

**تطبيق الزبون (على هاتف Android متصل، أو محاكي):**
```powershell
cd apps/customer_app
flutter pub get
flutter run
```

**لوحة التاجر (متصفح):**
```powershell
cd apps/merchant-dashboard
npm install   # أول مرة فقط
npm run dev
```
افتح الرابط الذي يظهر (`localhost:3000` غالبًا).

**لوحة الإدارة (متصفح):**
```powershell
cd apps/admin-dashboard
npm install   # أول مرة فقط
npm run dev
```
كلتا اللوحتين تحتاجان ملف `.env.local` (أنشأناه سابقًا في كل مجلد يدويًا، غير مرفوع على GitHub — إذا فُقد، القيم في `.env.local.example` بنفس المجلد).

## 16. تطبيق السائق (Driver App)

**غير موجود عمدًا** — قرار V1 المتفق عليه أن التوصيل يُدار يدويًا بالكامل من طرف الإدارة (لوحة الإدارة تحتوي بالفعل على شاشة تحديث حالة التوصيل: استلام من المحل ← في الطريق ← تم التسليم). قاعدة البيانات مبنية بحيث تطبيق سائق حقيقي يمكن إضافته لاحقًا (تطبيق Flutter رابع، بنفس نمط بقية المشروع) دون أي تعديل على الجداول الحالية. أخبرني عندما تريد البدء فيه فعليًا.

## 17. كيف أبني نسخة Android (APK)

على جهازك (وليس هنا — بيئتي لا تملك Android SDK):
```powershell
cd apps/customer_app
flutter build apk --release
```
الملف الناتج: `apps/customer_app/build/app/outputs/flutter-apk/app-release.apk`

## 18. كيف أبني نسخة iOS

**لا يمكن بناء iOS فعليًا من هنا ولا من جهازك الحالي (Windows)** — Apple يشترط جهاز Mac حقيقي مع Xcode لبناء وتوقيع تطبيقات iOS، هذا قيد من Apple نفسها وليس قيدًا في هذا المشروع. الكود Dart لا يحتوي أي شيء يمنع iOS مستقبلًا — تحققت اليوم أن مجلد `ios/` موجود وجاهز في المشروع، فقط ينتظر بيئة Mac للبناء الفعلي.

بدائل عند الحاجة الفعلية لنسخة iOS:
- استئجار/استعارة جهاز Mac لبناء التطبيق مرة واحدة والرفع لـ App Store Connect
- خدمة بناء سحابية مثل Codemagic أو GitHub Actions macOS runner (تبني iOS بدون امتلاك Mac فعليًا) — تحتاج حساب Apple Developer ($99/سنة) بغض النظر عن طريقة البناء

## 19. كيف أبني نسخة الويب (Web)

جرّبتها فعليًا اليوم ونجحت:
```powershell
cd apps/customer_app
flutter build web --release
```
الملفات الناتجة في `apps/customer_app/build/web/` — مجلد جاهز للرفع على أي استضافة ثابتة (Vercel، Netlify، Cloudflare Pages...). لم يُرفع بعد لأي استضافة فعلية (يحتاج قرارًا منك: أي دومين/استضافة تريد استخدامها لموقع الزبائن، بخلاف Vercel المستخدم للوحتي التاجر والإدارة).

---

## الخلاصة

المشروع في حالة **قابلة فعليًا للعمل والاختبار** على Android والويب اليوم، مع Backend حقيقي بالكامل (لا بيانات وهمية) — كل شيء تراه في التطبيقات الثلاثة يقرأ ويكتب من نفس قاعدة بيانات Supabase الحقيقية. الأجزاء غير المكتملة (Firebase الفعلي، السائق، iOS الفعلي، لغات إضافية) إما تنتظر قرارًا/حسابًا خارجيًا منك، أو مؤجَّلة بقرار سابق متفق عليه — وكلاهما موضّح أعلاه بالسبب الدقيق.
