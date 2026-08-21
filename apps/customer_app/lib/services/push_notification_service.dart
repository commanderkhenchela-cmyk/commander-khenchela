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
      debugPrint('[Push] Firebase.initializeApp نجحت');

      final settings = await FirebaseMessaging.instance.requestPermission();
      debugPrint('[Push] إذن الإشعارات: ${settings.authorizationStatus}');

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
    } catch (e, st) {
      // Firebase غير مربوط بعد أو فشل التهيئة لأي سبب — تجاهل بهدوء، راجع
      // تعليق الصف أعلاه. الطباعة هنا مؤقتة للتشخيص فقط أثناء تفعيل
      // PHASE 11 لأول مرة — راجع نتيجتها ثم يمكن حذفها لاحقًا.
      debugPrint('[Push] فشلت تهيئة Firebase: $e');
      debugPrint('[Push] $st');
    }
  }

  static Future<void> _saveTokenIfSignedIn() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[Push] لا يوجد مستخدم مسجَّل دخوله — تخطّي حفظ التوكن');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[Push] التوكن الناتج من getToken(): $token');
      if (token == null) return;

      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('[Push] تم حفظ التوكن في قاعدة البيانات بنجاح');
    } catch (e, st) {
      // فشل حفظ التوكن (لا إنترنت مثلًا) لا يجب أن يزعج المستخدم بأي
      // شكل — ستُعاد المحاولة تلقائيًا عند أي تغيّر لاحق في حالة الدخول
      // أو تجدد التوكن. الطباعة هنا مؤقتة للتشخيص، راجع تعليق initialize.
      debugPrint('[Push] فشل حفظ التوكن: $e');
      debugPrint('[Push] $st');
    }
  }

  /// تشخيص يدوي مؤقت (PHASE 11): يعيد تنفيذ نفس خطوات تسجيل التوكن
  /// خطوة بخطوة، ويُرجع نصًا يلخّص أين توقّفت العملية بالضبط — لعرضه
  /// مباشرة في الواجهة (SnackBar/Dialog) بدل الاعتماد على سجلّات
  /// الطرفية التي قد تُغرقها سجلّات أندرويد الأخرى. يُستدعى من زر تشخيص
  /// مؤقت في شاشة "حسابي" — يُحذف الزر وهذه الدالة بعد إيجاد السبب.
  static Future<String> diagnoseAndReport() async {
    final lines = <String>[];

    try {
      if (!_initialized) {
        await Firebase.initializeApp();
        _initialized = true;
      }
      lines.add('✅ Firebase.initializeApp نجحت');
    } catch (e) {
      lines.add('❌ فشلت Firebase.initializeApp: $e');
      return lines.join('\n');
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      lines.add('✅ إذن الإشعارات: ${settings.authorizationStatus}');
    } catch (e) {
      lines.add('❌ فشل طلب الإذن: $e');
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      lines.add('⚠️ لا يوجد مستخدم مسجَّل دخوله حاليًا');
      return lines.join('\n');
    }
    lines.add('✅ مستخدم مسجَّل الدخول: $userId');

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
      lines.add(
        token == null
            ? '❌ getToken() أرجعت null (لا توكن)'
            : '✅ توكن: ${token.substring(0, 20)}...',
      );
    } catch (e) {
      lines.add('❌ فشل getToken(): $e');
      return lines.join('\n');
    }

    if (token == null) return lines.join('\n');

    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
      lines.add('✅ تم حفظ التوكن في قاعدة البيانات');
    } catch (e) {
      lines.add('❌ فشل حفظ التوكن في قاعدة البيانات: $e');
    }

    return lines.join('\n');
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
