/// نموذج إشعار داخل التطبيق — نفس نموذج تطبيق الزبون حرفيًا، مطابق
/// لجدول notifications. تُنشأ فقط من طرف السيرفر (Edge Function عند
/// تسجيل/اعتماد/رفض حساب الموصّل — راجع شبكة الإشعارات في المرحلة 0).
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      isRead: map['is_read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
