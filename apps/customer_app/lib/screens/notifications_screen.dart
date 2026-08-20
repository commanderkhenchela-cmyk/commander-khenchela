import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_item.dart';

/// شاشة "إشعاراتي" — تعرض إشعارات المستخدم الحالي فقط (RLS تحميها تلقائيًا).
/// تُملأ هذه القائمة من طرف Edge Function عند تغيّر حالة الطلب (Phase 11)؛
/// قبل تفعيل تلك الدالة، ستظهر الشاشة فارغة وهذا طبيعي.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationItem>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
  }

  Future<List<NotificationItem>> _fetchNotifications() async {
    final data = await Supabase.instance.client
        .from('notifications')
        .select('id, title, body, is_read, created_at')
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => NotificationItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notification.id);

    if (mounted) {
      setState(() {
        _notificationsFuture = _fetchNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إشعاراتي')),
      body: FutureBuilder<List<NotificationItem>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.black45,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذّر تحميل الإشعارات. تحقق من اتصالك بالإنترنت.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _notificationsFuture = _fetchNotifications();
                        });
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد إشعارات بعد.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                color: notification.isRead
                    ? null
                    : theme.colorScheme.primary.withValues(alpha: 0.06),
                child: ListTile(
                  onTap: () => _markAsRead(notification),
                  leading: Icon(
                    notification.isRead
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded,
                    color: notification.isRead
                        ? Colors.black45
                        : theme.colorScheme.primary,
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(notification.body),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
