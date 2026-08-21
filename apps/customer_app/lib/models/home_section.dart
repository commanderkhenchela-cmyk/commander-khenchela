/// أنواع أقسام الصفحة الرئيسية الثابتة — كل نوع منطقه/استعلامه مكتوب في
/// كود HomeScreen (راجع تعليق migration home_sections للتفسير الكامل
/// لفلسفة "كتالوج محدود وليس منشئ صفحات حر"). unknown تحسُّبًا لأي قيمة
/// section_key مستقبلية غير معروفة بعد لهذه النسخة من التطبيق — تُتجاهل
/// بهدوء بدل أن تُسقِط الصفحة كاملة.
enum HomeSectionKey {
  hero,
  categories,
  featured,
  nearby,
  newest,
  mostOrdered,
  unknown;

  static HomeSectionKey fromKey(String key) {
    switch (key) {
      case 'hero':
        return HomeSectionKey.hero;
      case 'categories':
        return HomeSectionKey.categories;
      case 'featured':
        return HomeSectionKey.featured;
      case 'nearby':
        return HomeSectionKey.nearby;
      case 'newest':
        return HomeSectionKey.newest;
      case 'most_ordered':
        return HomeSectionKey.mostOrdered;
      default:
        return HomeSectionKey.unknown;
    }
  }
}

/// صفّ من جدول home_sections — يتحكّم بأي أقسام الصفحة الرئيسية تظهر
/// للعميل، بأي ترتيب، وبأي عنوان (تديره لوحة الإدارة بالكامل). القسم قد
/// يكون مفعَّلًا هنا لكن لا يزال يُخفى فعليًا في HomeScreen إن لم توجد له
/// بيانات حقيقية كافية — راجع تعليق _buildSection هناك.
class HomeSection {
  final String id;
  final HomeSectionKey key;
  final String title;
  final int sortOrder;

  const HomeSection({
    required this.id,
    required this.key,
    required this.title,
    required this.sortOrder,
  });

  factory HomeSection.fromMap(Map<String, dynamic> map) {
    return HomeSection(
      id: map['id'] as String,
      key: HomeSectionKey.fromKey(map['section_key'] as String),
      title: map['title'] as String,
      sortOrder: (map['sort_order'] as num).toInt(),
    );
  }
}
