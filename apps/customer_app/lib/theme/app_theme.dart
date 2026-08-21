import 'package:flutter/material.dart';

/// تصميم موحّد للتطبيق: بسيط، واضح، ألوان بتباين جيد، أزرار كبيرة
/// مناسبة لكل الأعمار (راجع قسم "Customer Experience" في وثيقة المتطلبات).
///
/// الألوان الافتراضية أدناه تُستخدم فقط قبل تحميل هوية التطبيق الحقيقية
/// من قاعدة البيانات (BrandingService) — بعدها تُبنى الثيم فعليًا من
/// الألوان التي يضبطها الأدمن من لوحة الإدارة (أنظر [light] بمعامِلاتها).
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1B7A3D); // أخضر هادئ، احترافي
  static const Color primaryDark = Color(0xFF0F5C2B);
  static const Color background = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color error = Color(0xFFB3261E);

  static ThemeData light({Color? primaryColor, Color? errorColor}) {
    final seed = primaryColor ?? primary;
    final err = errorColor ?? error;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        error: err,
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
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56), // زر كبير، سهل اللمس
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

  // ألوان الوضع الداكن — احترافي وحقيقي، وليس مجرَّد "عكس ألوان" الوضع
  // الفاتح: نستخدم ColorScheme.fromSeed بـ brightness: dark، وهو يبني
  // لوحة درجات سطح (surface) وخلفية داكنة متدرّجة (وليست سوداء خالصة)
  // محسوبة خصيصًا لتباين مقروء، مطابقة لمبادئ Material 3 الرسمية —
  // نفس فلسفة "لون البذرة" المستخدَمة في [light] لكن بسطوع معكوس فعليًا
  // في درجات الألوان لا في القيم الرقمية للنص/الخلفية فقط.
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkTextPrimary = Color(0xFFF2F2F2);

  static ThemeData dark({Color? primaryColor, Color? errorColor}) {
    final seed = primaryColor ?? primary;
    final err = errorColor ?? error;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        primary: seed,
        error: err,
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: _darkTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 18, color: _darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 16, color: _darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
        ),
      ),
      cardColor: const Color(0xFF1E1E1E),
    );
  }
}
