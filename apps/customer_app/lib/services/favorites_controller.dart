import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يدير مجموعة "المحلات المفضَّلة" للمستخدم الحالي — Provider مركزي
/// واحد (مسجَّل في main.dart، نفس نمط CartService/ThemeController) بدل
/// أن تجلب كل شاشة/بطاقة حالتها بنفسها؛ هذا يمنع طلب شبكة منفصل لكل
/// بطاقة محل في كل قائمة (لو كان كل زر قلب يجلب حالته بنفسه لكانت شاشة
/// فيها 10 بطاقات = 10 طلبات متكررة بلا داعٍ).
///
/// يُحمَّل تلقائيًا عند الإنشاء، ويُعاد تحميله (أو يُفرَّغ) تلقائيًا عند
/// أي تغيّر في حالة تسجيل الدخول (دخول/خروج) عبر الاستماع مباشرة لتيار
/// Supabase Auth — لا حاجة لأي استدعاء يدوي من شاشة تسجيل الدخول أو
/// الخروج، فلا يوجد مكان يمكن أن يُنسى فيه هذا الاستدعاء.
///
/// لا يرمي أي استثناء أبدًا (نفس فلسفة BrandingService/LocationService)
/// — بما في ذلك عند الإنشاء نفسه، حتى يبقى قابلًا للإنشاء بأمان في بيئة
/// اختبار لم تهيّئ Supabase إطلاقًا.
class FavoritesController extends ChangeNotifier {
  Set<String> _favoriteMerchantIds = {};
  StreamSubscription<AuthState>? _authSubscription;

  Set<String> get favoriteMerchantIds => _favoriteMerchantIds;

  bool isFavorite(String merchantId) =>
      _favoriteMerchantIds.contains(merchantId);

  FavoritesController() {
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) => _load());
      _load();
    } catch (_) {
      // Supabase غير مهيّأ بعد (مثلًا داخل اختبار widget لا يحتاج شبكة) —
      // يبقى الكنترولر خاملًا بمجموعة فارغة بدل تعطيل الاختبار كله.
    }
  }

  Future<void> _load() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _favoriteMerchantIds = {};
        notifyListeners();
        return;
      }

      final rows = await Supabase.instance.client
          .from('favorites')
          .select('merchant_id')
          .eq('user_id', userId);

      _favoriteMerchantIds = (rows as List)
          .map((row) => row['merchant_id'] as String)
          .toSet();
      notifyListeners();
    } catch (_) {
      // فشل التحميل (لا إنترنت مثلًا) → تبقى القائمة كما كانت بهدوء، بدل
      // تعطيل الشاشة بخطأ.
    }
  }

  /// إضافة/إزالة محل من المفضّلة — تحديث تفاؤلي فوري في الواجهة، مع
  /// تراجع تلقائي إن فشل الحفظ فعليًا على الخادم.
  Future<void> toggle(String merchantId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final wasFavorite = _favoriteMerchantIds.contains(merchantId);
    if (wasFavorite) {
      _favoriteMerchantIds.remove(merchantId);
    } else {
      _favoriteMerchantIds.add(merchantId);
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('merchant_id', merchantId);
      } else {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': userId,
          'merchant_id': merchantId,
        });
      }
    } catch (_) {
      if (wasFavorite) {
        _favoriteMerchantIds.add(merchantId);
      } else {
        _favoriteMerchantIds.remove(merchantId);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
