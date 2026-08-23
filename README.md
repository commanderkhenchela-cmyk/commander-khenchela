# Commander Khenchela

منصة Marketplace محلية تبدأ من ولاية خنشلة (الجزائر)، وقابلة للتوسع مستقبلًا إلى باقي الولايات الجزائرية.

تسمح المنصة للعملاء بتصفح المحلات والمنتجات، إنشاء طلبية، واختيار التوصيل والدفع عند الاستلام (COD).

## حالة المشروع

✅ التطبيقات الأربعة (تطبيق الزبون، تطبيق الموصّل، لوحة التاجر، لوحة الإدارة)
مبنية بالكامل ومربوطة بقاعدة بيانات حقيقية (Supabase) — لا بيانات وهمية،
كل شاشة تقرأ/تكتب فعليًا. دورة الطلب الكاملة تعمل من طرف لطرف: تصفّح →
طلب → موافقة التاجر → تعيين موصّل → تسليم → تقييم، بإشعارات فورية (Web
Push + Firebase) وتحديث لحظي (Realtime) لحالة الطلب.

مؤجَّل عمدًا (قرارات معمارية سابقة، راجع [`docs/architecture-decisions.md`](./docs/architecture-decisions.md)):
`apps/web` (الموقع العام)، سيارات الأجرة/الكورسة، بوابة دفع إلكتروني، تحقّق SMS OTP حقيقي.

المرحلة القادمة: اختبار شامل حيّ (Full Testing + Debugging) على الأجهزة الحقيقية.

## البنية التقنية (Technology Stack)

| الجزء | التقنية |
|---|---|
| Customer Mobile App | Flutter (Dart) — Android أولًا، iOS مدعوم من البنية منذ البداية |
| Marketplace Web | Next.js + TypeScript |
| Merchant Dashboard | Next.js + TypeScript |
| Admin Dashboard | Next.js + TypeScript |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) |
| Push Notifications | Firebase Cloud Messaging |
| Web Hosting | Vercel |
| DNS / SSL / CDN | Cloudflare |

## هيكل المستودع (Monorepo)

```
commander-khenchela/
├── apps/
│   ├── customer_app/          # تطبيق العميل (Flutter)
│   ├── driver_app/            # تطبيق موصّلي التوصيل بالدراجات (Flutter)
│   ├── web/                   # الموقع الرئيسي (Next.js)
│   ├── merchant-dashboard/    # لوحة تحكم التجار (Next.js)
│   └── admin-dashboard/       # لوحة تحكم الإدارة (Next.js)
├── supabase/
│   ├── migrations/            # ملفات إنشاء/تعديل قاعدة البيانات
│   └── functions/             # Edge Functions
└── docs/                      # التوثيق والقرارات المعمارية
```

## نموذج العمل — V1

- Marketplace متعدد التجار، لكن الطلب الواحد من تاجر واحد فقط.
- الدفع: COD (الدفع عند الاستلام) فقط — بدون بوابة دفع إلكتروني.
- التوصيل: عبر موصّلين حقيقيين على دراجات (`apps/driver_app`)، مع بقاء صلاحية تجاوز كاملة للإدارة في أي لحظة. سيارات الأجرة (الكورسة) مرحلة قادمة منفصلة.

## التوثيق

راجع مجلد [`docs/`](./docs) لتفاصيل القرارات المعمارية، مخطط قاعدة البيانات، وسياسات الأمان (RLS).
