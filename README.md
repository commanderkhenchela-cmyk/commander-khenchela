# Commander Khenchela

منصة Marketplace محلية تبدأ من ولاية خنشلة (الجزائر)، وقابلة للتوسع مستقبلًا إلى باقي الولايات الجزائرية.

تسمح المنصة للعملاء بتصفح المحلات والمنتجات، إنشاء طلبية، واختيار التوصيل والدفع عند الاستلام (COD).

## حالة المشروع

🚧 قيد الإنشاء — PHASE 1 (Architecture).

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
- التوصيل: يدوي عبر Admin، مع بنية قاعدة بيانات تسمح مستقبلًا بإضافة تطبيق سائق توصيل بدون إعادة بناء نظام الطلبات.

## التوثيق

راجع مجلد [`docs/`](./docs) لتفاصيل القرارات المعمارية، مخطط قاعدة البيانات، وسياسات الأمان (RLS).
