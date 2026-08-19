# Customer Mobile App

تطبيق العميل (Flutter/Dart) — Android في الإصدار الأول، وبنية جاهزة لدعم iOS لاحقًا دون إعادة كتابة الكود.

## قبل التشغيل على جهازك

1. ثبّت Flutter SDK وAndroid Studio (راجع تعليمات PHASE 6 في المحادثة).
2. افتح `lib/config/supabase_config.dart` وضع فيه `publishableKey` الحقيقي من لوحة تحكم Supabase (Settings → API). لا تضع أبدًا Service Role Key هنا.

## التشغيل

```
cd apps/customer_app
flutter pub get
flutter run
```

## الحالة الحالية

✅ هيكل المشروع + شاشة ترحيب أولى (Arabic-first, RTL) + اتصال Supabase مُهيَّأ.
🚧 باقي الشاشات (تسجيل الدخول، التصفح، السلة...) قيد البناء التدريجي.
