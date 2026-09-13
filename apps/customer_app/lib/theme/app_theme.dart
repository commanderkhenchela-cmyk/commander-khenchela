import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// تصميم موحّد للتطبيق: بسيط، واضح، ألوان بتباين جيد، أزرار كبيرة
/// مناسبة لكل الأعمار (راجع قسم "Customer Experience" في وثيقة المتطلبات).
///
/// الألوان الافتراضية أدناه تُستخدم فقط قبل تحميل هوية التطبيق الحقيقية
/// من قاعدة البيانات (BrandingService) — بعدها تُبنى الثيم فعليًا من
/// الألوان التي يضبطها الأدمن من لوحة الإدارة (أنظر [light] بمعامِلاتها).
///
/// نظام التصميم "المرحلة 1" (طباعة/انتقال/أزرار/بطاقات/حقول موحَّدة عبر
/// [ThemeData] مركزيًا) — لا تعديل لأي شاشة، كل شيء يرث تلقائيًا عبر
/// Theme.of(context). التفاصيل والمبرِّرات لكل بند موثَّقة أسفل كل واحد.
class AppTheme {
  AppTheme._();

  // أحمر العلامة التجارية — مُستخرَج مباشرة من بكسلات الشعار الرسمي
  // (راجع migration 20260914000000_app_branding_identity_correction).
  // ثابت عمدًا (لا تغيير) — طلب المستخدم صراحةً الإبقاء عليه كهوية
  // تجارية، والتطوير في جودة التنفيذ لا في اللون.
  static const Color primary = Color(0xFFD90115);
  static const Color primaryDark = Color(0xFF8E000E);
  static const Color background = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  // برتقالي/كهرماني — لا أحمر، حتى لا يتشابه بصريًا مع [primary] الأحمر
  // الآن (زر عادي مقابل زر خطر). نفس قيمة AppColorsX.warning تمامًا
  // (design_tokens.dart) عمدًا — لون واحد لمفهوم واحد، بدل قيمتين
  // منفصلتين للمعنى نفسه. "خطر حقيقي بصرف النظر عن العلامة" (كشارة
  // "مغلق الآن") يبقى عبر AppColorsX.danger المنفصلة، غير المتأثرة هنا.
  static const Color error = Color(0xFFB26A00);

  /// طباعة Cairo عبر [GoogleFonts] — تُطبَّق على *كل* شرائح [TextTheme]
  /// (حتى غير المخصَّصة أدناه، كالمستخدَمة ضمنًا في عشرات الشاشات)، ثم
  /// نُعيد فرض أحجام/أوزان/ألوان الشرائح الأربع المخصَّصة أصلًا فوقها
  /// بالحرف — تغيير الخط فقط، لا أي تغيير حجم أو تباعد قائم.
  static TextTheme _textTheme(TextTheme base, Color titleColor) {
    return GoogleFonts.cairoTextTheme(base).copyWith(
      headlineMedium: GoogleFonts.cairo(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: titleColor,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
      bodyLarge: GoogleFonts.cairo(fontSize: 18, color: titleColor),
      bodyMedium: GoogleFonts.cairo(fontSize: 16, color: titleColor),
    );
  }

  /// انتقال صفحات "Material Motion" (Shared Axis أفقي) عبر
  /// package:animations — يستبدل انتقال المنصّة الافتراضي لكل
  /// Navigator.push(MaterialPageRoute(...)) الموجود فعليًا فـ التطبيق،
  /// بلا أي تعديل لأي شاشة (الثيم وحده كافٍ). نفس المنطق لكل المنصّات
  /// (اتساق Android/iOS بدل انتقالين مختلفين).
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.macOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.linux: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.windows: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
        },
      );

  /// بطاقات مسطَّحة بحدّ رفيع بدل ظل Material الافتراضي — نفس اتجاه
  /// "Flat-Modern" المعتمَد فـ تطبيقات مرجعية إقليمية كبرى، يطبَّق تلقائيًا
  /// على كل Card فـ التطبيق (بطاقات المحلات/المنتجات/الطلبات...).
  static CardThemeData _cardTheme(Color borderColor) {
    return CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: borderColor),
      ),
    );
  }

  /// حقول إدخال موحَّدة — خلفية معبَّأة خفيفة وحدود مدوَّرة، تُطبَّق على
  /// كل TextField/TextFormField لا يفرض تنسيقه الخاص صراحةً.
  static InputDecorationTheme _inputDecorationTheme(
    Color fillColor,
    Color borderColor,
    Color focusColor,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
    );
  }

  /// أزرار Outlined/Text متّسقة بصريًا مع ElevatedButton الحالي — عائلة
  /// أزرار واحدة الشكل (نصف قطر وحجم لمس موحَّدين) بدل كل واحد بأسلوبه
  /// الافتراضي المتباين.
  static OutlinedButtonThemeData _outlinedButtonTheme(Color seed) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: seed,
        side: BorderSide(color: seed),
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color seed) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: seed,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }

  static ThemeData light({Color? primaryColor, Color? errorColor}) {
    final seed = primaryColor ?? primary;
    final err = errorColor ?? error;
    final base = ThemeData(useMaterial3: true);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        error: err,
      ),
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(base.textTheme, textPrimary),
      pageTransitionsTheme: _pageTransitionsTheme,
      cardTheme: _cardTheme(Colors.black.withValues(alpha: 0.08)),
      inputDecorationTheme: _inputDecorationTheme(
        Colors.black.withValues(alpha: 0.03),
        Colors.black.withValues(alpha: 0.12),
        seed,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(seed),
      textButtonTheme: _textButtonTheme(seed),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56), // زر كبير، سهل اللمس
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          elevation: 1,
          shadowColor: seed.withValues(alpha: 0.35),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
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
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);

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
      textTheme: _textTheme(base.textTheme, _darkTextPrimary),
      pageTransitionsTheme: _pageTransitionsTheme,
      cardTheme: _cardTheme(Colors.white.withValues(alpha: 0.08)),
      inputDecorationTheme: _inputDecorationTheme(
        Colors.white.withValues(alpha: 0.04),
        Colors.white.withValues(alpha: 0.14),
        seed,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(seed),
      textButtonTheme: _textButtonTheme(seed),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
          ),
          elevation: 1,
          shadowColor: seed.withValues(alpha: 0.45),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
        ),
      ),
      cardColor: const Color(0xFF1E1E1E),
    );
  }
}
