/// خدمة أعلى مستوى (تسوّق/مطاعم/طاكسي/توصيل/حرفيون) — مطابق لجدول
/// services. راجع migration 20260824000000_services.sql لسياق التصميم
/// الكامل: enabled يضبطه الأدمن، لكنه لا يعني وحده أن الخدمة "جاهزة
/// فعليًا" — راجع BuiltServices في home_screen.dart.
class AppService {
  final String id;
  final String slug;
  final String name;
  final String icon;
  final String? description;

  const AppService({
    required this.id,
    required this.slug,
    required this.name,
    required this.icon,
    this.description,
  });

  factory AppService.fromMap(Map<String, dynamic> map) {
    return AppService(
      id: map['id'] as String,
      slug: map['slug'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      description: map['description'] as String?,
    );
  }
}
