import 'package:flutter/material.dart';

/// تصميم بسيط وواضح — نفس هوية بقية المشروع (نفس الأحمر بالضبط، طلب
/// صريح: التمييز البصري لتطبيق الموصّل يكون عبر أيقونة التطبيق نفسها
/// (رمز طاكسي + دراجة بدل الحقيبة — راجع الأيقونات فـ android/app/src/
/// main/res/mipmap-*) لا عبر لون مختلف — نفس اللون فـ كل التطبيقات
/// أوضح وأقل تشويشًا من تعدّد الألوان.
/// لا وضع داكن ولا هوية قابلة للتخصيص في هذه المرحلة (عمدًا، تفاديًا
/// للتعقيد — تطبيق الموصّل أداة عمل بسيطة، وليس واجهة تسويقية).
class AppTheme {
  AppTheme._();

  // أحمر العلامة التجارية — نفس اللون بالضبط المُستخدَم فـ customer_app
  // وadmin/merchant-dashboard (مُستخرَج مباشرة من بكسلات الشعار الرسمي).
  static const Color primary = Color(0xFFD90115);
  static const Color background = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  // برتقالي/كهرماني — لا أحمر، حتى لا يتشابه بصريًا مع [primary] الأحمر
  // (نفس القرار المطبَّق فـ customer_app/lib/theme/app_theme.dart).
  static const Color error = Color(0xFFB26A00);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 16, color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }
}
