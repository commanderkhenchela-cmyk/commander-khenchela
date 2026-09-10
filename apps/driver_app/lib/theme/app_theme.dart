import 'package:flutter/material.dart';

/// تصميم بسيط وواضح — نفس هوية بقية المشروع، لكن بلون مختلف عمدًا
/// (طلب صريح: تطبيق الموصّل يُميَّز بصريًا عن تطبيق العميل رغم انتمائه
/// لنفس العلامة). الأحمر مخصَّص لتطبيقات العميل/المحلات (customer_app،
/// admin/merchant-dashboard)، والكحلي هنا — نفس اللون الثانوي الموجود
/// فعليًا فـ الشعار الرسمي (حقيبة/كلمة Commander)، وليس لونًا مُختلَقًا.
/// لا وضع داكن ولا هوية قابلة للتخصيص في هذه المرحلة (عمدًا، تفاديًا
/// للتعقيد — تطبيق الموصّل أداة عمل بسيطة، وليس واجهة تسويقية).
class AppTheme {
  AppTheme._();

  // كحلي العلامة التجارية — نفس اللون الثانوي فـ الشعار الرسمي (أغمق
  // قليلًا فـ الشعار نفسه #03112A، هنا أفتح شيئًا ليقرأ بوضوح كـ"أزرق
  // كحلي" فـ أزرار صغيرة، بدل الاقتراب من الأسود).
  static const Color primary = Color(0xFF0B2545);
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
