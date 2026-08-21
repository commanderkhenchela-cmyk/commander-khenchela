import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_navigation.dart';

/// إشعارات Push عبر Firebase Cloud Messaging (PHASE 11).
///
/// نشاط الإشعار الفعلي (تسجيله في جدول notifications، وإرساله عبر FCM
/// إن توفّر توكن) مبني بالكامل من طرف الخادم مسبقًا — راجع
/// supabase/functions/send-order-notification. هذه الخدمة تتكفّل فقط
/// بالجزء الذي لا يمكن إنجازه إلا من التطبيق نفسه: طلب إذن الإشعارات،
/// الحصول على توكن الجهاز، وحفظه في users.fcm_token.
///
/// لا يرمي أي استثناء أبدًا مهما حدث (نفس فلسفة BrandingService بالضبط)
/// — أهم حالة تحديدًا: **قبل ربط مشروع Firebase فعليًا** (قبل وضع ملف
/// google-services.json الحقيقي وتفعيل Gradle plugin)، ستفشل
/// Firebase.initializeApp() هنا بهدوء تمامًا، ويستمر التطبيق يعمل
/// بشكل طبيعي 100% بدون Push — فقط بدون هذه الميزة تحديدًا. الإشعارات
/// داخل التطبيق (شاشة "إشعاراتي"، مبنية على جدول notifications مباشرة)
/// تعمل دائمًا بغض النظر عن حالة Firebase.
class PushNotificationService {
  const PushNotificationService._();

  static bool _initialized = false;

  /// يُستدعى مرة واحدة من main() بعد تهيئة Supabase.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;

      await FirebaseMessaging.instance.requestPermission();

      // يحفظ التوكن فور تسجيل الدخول، ويحدّثه تلقائيًا عند تجدده أو عند
      // تغيّر حالة تسجيل الدخول — نفس نمط FavoritesController: استماع
      // مباشر لتيار Supabase Auth بدل استدعاء يدوي من كل شاشة دخول/خروج
      // (فلا يوجد مكان يمكن أن يُنسى فيه هذا الاستدعاء).
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) => _saveTokenIfSignedIn(),
      );
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => _saveTokenIfSignedIn(),
      );
      unawaited(_saveTokenIfSignedIn());

      // إشعار وارد والتطبيق مفتوح فعليًا (foreground) — نظام أندرويد لا
      // يعرض شعاره التلقائي في هذه الحالة، فنعرض بديلًا بسيطًا (SnackBar)
      // بدل أن يختفي الإشعار بصمت. الإشعار يبقى مسجَّلًا في "إشعاراتي"
      // بغض النظر عن هذا تمامًا.
      FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    } catch (_) {
      // Firebase غير مربوط بعد أو فشل التهيئة لأي سبب — تجاهل بهدوء، راجع
      // تعليق الصف أعلاه.
    }
  }

  static Future<void> _saveTokenIfSignedIn() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (_) {
      // فشل حفظ التوكن (لا إنترنت مثلًا) لا يجب أن يزعج المستخدم بأي
      // شكل — ستُعاد المحاولة تلقائيًا عند أي تغيّر لاحق في حالة الدخول
      // أو تجدد التوكن.
    }
  }

  static void _showForegroundBanner(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    final parts = [?title, ?body];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' — ')),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
