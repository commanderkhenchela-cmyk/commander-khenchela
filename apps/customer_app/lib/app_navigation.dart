import 'package:flutter/material.dart';

/// مفتاح Navigator عام للتطبيق كله — يُستخدم فقط عندما نحتاج فتح واجهة
/// (مثل SnackBar إشعار وارد) من كود لا يملك BuildContext مباشرًا، مثل
/// معالج FirebaseMessaging.onMessage (يعمل خارج شجرة الواجهة).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
