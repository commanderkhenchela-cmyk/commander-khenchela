import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/favorites_controller.dart';

/// زر قلب لإضافة/إزالة محل من "مفضّلتي" — يُستخدم داخل MerchantCard.
/// المستخدم غير المسجَّل يُنقَل لتسجيل الدخول عند الضغط بدل تجاهل
/// الضغطة بصمت أو إخفاء الزر (يبقى الزر ظاهرًا دائمًا، متّسقًا في كل
/// البطاقات، سواء كان المستخدم مسجَّلًا أم لا).
class FavoriteButton extends StatelessWidget {
  final String merchantId;

  const FavoriteButton({super.key, required this.merchantId});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final isFavorite = favorites.isFavorite(merchantId);
    final theme = Theme.of(context);

    return IconButton(
      onPressed: () {
        if (!AuthService.isSignedIn) {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
          return;
        }
        favorites.toggle(merchantId);
      },
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      ),
      color: isFavorite
          ? Colors.redAccent
          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
      tooltip: isFavorite
          ? AppLocalizations.of(context).removeFavoriteTooltip
          : AppLocalizations.of(context).addFavoriteTooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}
