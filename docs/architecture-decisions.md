# قرارات الهيكلة المعمارية — PHASE 1

هذا الملف يوثّق القرارات المعمارية النهائية المتفق عليها قبل بدء أي تنفيذ فعلي.

---

## 1. هيكل المستودع (Repository Structure)

**القرار:** Monorepo — كل التطبيقات (Flutter + 3 مواقع Next.js) والبنية الخلفية (Supabase) داخل مستودع GitHub واحد.

**السبب:** المشروع في مرحلته الأولى ويُدار من طرف شخص واحد. Monorepo أسهل للتنسيق والمتابعة، ويمكن تقسيمه لاحقًا لمستودعات منفصلة بسهولة إذا كبر فريق العمل.

```
commander-khenchela/
├── apps/
│   ├── customer_app/          # تطبيق العميل (Flutter)
│   ├── web/                   # الموقع الرئيسي (Next.js)
│   ├── merchant-dashboard/    # لوحة تحكم التجار (Next.js)
│   └── admin-dashboard/       # لوحة تحكم الإدارة (Next.js)
├── supabase/
│   ├── migrations/            # ملفات إنشاء/تعديل قاعدة البيانات
│   └── functions/             # Edge Functions
└── docs/                      # التوثيق
```

---

## 2. جداول قاعدة البيانات — V1

### ✅ جداول V1 (13 جدول):

| الجدول | الوصف |
|---|---|
| `wilayas` | قائمة الولايات (لدعم التوسع المستقبلي خارج خنشلة) |
| `communes` | قائمة البلديات، كل بلدية مرتبطة بولايتها |
| `users` | كل مستخدم (عميل/تاجر/إداري)، مرتبط بحساب Supabase Auth |
| `merchants` | بيانات المحل (الاسم، الموقع، حالة الموافقة) |
| `categories` | تصنيفات المنتجات |
| `products` | المنتجات، كل منتج مرتبط بتاجر واحد |
| `product_images` | صور المنتجات (عدة صور لكل منتج) |
| `addresses` | عناوين توصيل العملاء |
| `orders` | الطلبية (تتضمن حقول العمولة والدفع، أنظر القسم 4) |
| `order_items` | تفاصيل كل طلبية |
| `order_status_history` | سجل تغييرات حالة الطلب |
| `notifications` | إشعارات محفوظة لكل مستخدم |
| `settings` | إعدادات عامة قابلة للتعديل (نسبة العمولة الافتراضية...) |

### ⏸️ جداول مؤجلة (ليست V1):

| الجدول | سبب التأجيل |
|---|---|
| `customers` | تُدمج بياناته داخل `users` — لا حاجة لجدول منفصل في V1 |
| `merchant_users` | V1 يفترض مالكًا واحدًا لكل محل. إضافته لاحقًا = جدول جديد فقط، بدون تعديل الجداول الحالية |
| `payments` | V1 هو COD فقط. يكفي حقل `payment_status` داخل `orders`. الجدول الكامل يُضاف عند دمج بوابة دفع إلكتروني حقيقية |
| `coupons` | لا يوجد نظام خصومات مطلوب في V1 |
| `rides` (سيارات الأجرة/الكورسة) | مرحلة قادمة منفصلة عن التوصيل بالدراجات (`drivers`)، بعد أن يثبت نظام التوصيل الحالي فعليًا |

**ملاحظة**: `delivery_drivers`/`deliveries` و`reviews` كانتا مُدرَجتين هنا سابقًا كجداول مؤجَّلة — بُنيتا فعليًا (`drivers` في migration `20260822010000_drivers.sql`، و`reviews` في migration `20260821120000_reviews.sql`)، فأُزيلتا من هذه القائمة.

---

## 3. دورة حياة الطلب (Order Status State Machine)

### الحالات الممكنة:
`pending` → `confirmed` / `rejected` → `preparing` → `ready_for_pickup` → `picked_up` → `out_for_delivery` → `delivered`

حالات نهائية (لا رجوع منها): `delivered`, `cancelled`, `rejected`

### جدول الانتقالات المسموحة والصلاحيات:

| من | إلى | من يملك الصلاحية |
|---|---|---|
| — | `pending` | العميل (تلقائيًا عند إرسال الطلب) |
| `pending` | `confirmed` | التاجر |
| `pending` | `rejected` | التاجر |
| `pending` | `cancelled` | العميل أو Admin |
| `confirmed` | `preparing` | التاجر |
| `confirmed` | `cancelled` | Admin فقط (حالة استثنائية) |
| `preparing` | `ready_for_pickup` | التاجر |
| `preparing` | `cancelled` | Admin فقط (حالة استثنائية) |
| `ready_for_pickup` | `picked_up` | Admin |
| `picked_up` | `out_for_delivery` | Admin |
| `out_for_delivery` | `delivered` | Admin |

**قاعدة أمان:** يُطبَّق هذا المنطق داخل Edge Function على السيرفر (وليس فقط في الواجهة)، وأي انتقال غير موجود في الجدول أعلاه يُرفض تلقائيًا. كل تغيير ناجح يُسجَّل في `order_status_history`.

**ملاحظة:** بعد موافقة التاجر (`confirmed`)، العميل لم يعد يستطيع الإلغاء بنفسه — فقط Admin، لحماية التاجر من إلغاءات عشوائية بعد بدء التجهيز.

---

## 4. حساب العمولة والدفع (Commission & Payment)

### حقول إضافية على جدول `orders`:

| الحقل | مثال | الشرح |
|---|---|---|
| `subtotal` | 3000 دج | مجموع أسعار المنتجات فقط |
| `commission_rate` | 10% | نسبة العمولة **وقت إنشاء الطلب** (Snapshot ثابت) |
| `platform_commission_amount` | 300 دج | = subtotal × commission_rate |
| `merchant_amount` | 2700 دج | = subtotal − platform_commission_amount |
| `delivery_fee` | 200 دج | منفصل تمامًا عن سعر المنتج والعمولة |
| `total_amount` | 3200 دج | = subtotal + delivery_fee (ما يدفعه العميل) |
| `payment_status` | `unpaid` / `collected` | هل تم تحصيل المبلغ من العميل (COD) |

**لماذا Snapshot؟** إذا تغيّرت نسبة العمولة الافتراضية مستقبلًا (عبر جدول `settings`)، يجب ألا تتأثر الطلبات القديمة — كل طلب يحتفظ بالنسبة التي طُبِّقت عليه وقت إنشائه، لدقة محاسبية دائمة.

---

## الحالة

📅 آخر تحديث: PHASE 1 — كل القرارات أعلاه معتمدة ومؤكدة. القادم: PHASE 2 (إنشاء الحسابات السحابية: Supabase, Firebase, Vercel, Cloudflare).
