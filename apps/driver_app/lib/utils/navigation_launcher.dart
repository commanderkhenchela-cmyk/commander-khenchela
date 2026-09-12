import 'package:url_launcher/url_launcher.dart';

/// يفتح تطبيق الخرائط المثبَّت على الهاتف (Google Maps فـ الغالب) بتوجيه
/// حيّ (turn-by-turn) نحو نقطة الاستلام/التسليم — بدل بناء خريطة داخل
/// التطبيق نفسها (تجربة أضعف بكثير: بلا توجيه صوتي، بلا حركة مرور حيّة).
/// نفس الأسلوب الذي تعتمده كل تطبيقات التوصيل الاحترافية (Yassir
/// وغيرها) — لا تُعيد اختراع محرّك ملاحة، فقط تُسلِّم الإحداثيات لواحد
/// جاهز وموثوق أصلًا على جهاز الموصّل.
///
/// lat/lng قد تكون غائبة (العميل لم يستخدم "موقعي الحالي" عند إدخال
/// عنوانه — راجع تعليق migration 20260901000000_delivery_fee_engine) —
/// فـ هذه الحالة نستعمل بحثًا نصّيًا بعنوان الوجهة بدل التوجيه الدقيق،
/// أفضل من تعطيل الميزة كليًا.
Future<bool> openNavigation({
  required double? lat,
  required double? lng,
  String? fallbackAddressText,
}) async {
  final Uri uri;
  if (lat != null && lng != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
  } else if (fallbackAddressText != null && fallbackAddressText.trim().isNotEmpty) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fallbackAddressText)}',
    );
  } else {
    return false;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
