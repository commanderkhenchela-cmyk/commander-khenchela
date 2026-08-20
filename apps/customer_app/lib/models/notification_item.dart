/// نموذج إشعار داخل التطبيق، مطابق لجدول notifications.
/// تُنشأ الإشعارات فقط من طرف السيرفر (Edge Function عند تغيّر حالة الطلب)،
/// التطبيق يقرأها ويعلّمها كمقروءة فقط، لا ينشئها بنفسه.
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
