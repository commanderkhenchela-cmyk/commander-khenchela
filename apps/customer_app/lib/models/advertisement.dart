/// إعلان فيديو، مطابق لجدول advertisements. تواريخ البداية/النهاية
/// اختيارية (null = بلا سقف زمني من تلك الجهة) — راجع isCurrentlyActive.
class Advertisement {
  final String id;
  final String title;
  final String? description;
  final String advertiserName;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? linkUrl;
  final DateTime? startDate;
  final DateTime? endDate;

  const Advertisement({
    required this.id,
    required this.title,
    this.description,
    required this.advertiserName,
    required this.videoUrl,
    this.thumbnailUrl,
    this.linkUrl,
    this.startDate,
    this.endDate,
  });

  /// is_active يُفلتَر أصلًا في الاستعلام (RLS تسمح فقط بقراءة النشط) —
  /// هذا يتحقق إضافيًا من نطاق التاريخ (إن وُجد) على الجهاز، لأن
  /// PostgREST لا يُبسِّط شرط "بلا سقف زمني" (null) بسهولة في استعلام
  /// واحد. راجع تعليق migration 20260821040000_advertisements.sql.
  bool get isCurrentlyActive {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!.add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }

  factory Advertisement.fromMap(Map<String, dynamic> map) {
    return Advertisement(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      advertiserName: map['advertiser_name'] as String,
      videoUrl: map['video_url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      linkUrl: map['link_url'] as String?,
      startDate: map['start_date'] == null
          ? null
          : DateTime.tryParse(map['start_date'] as String),
      endDate: map['end_date'] == null
          ? null
          : DateTime.tryParse(map['end_date'] as String),
    );
  }
}
