import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant.dart';
import '../services/favorites_controller.dart';
import '../widgets/merchant_card.dart';
import 'merchant_products_screen.dart';

/// شاشة "مفضّلتي" — قائمة كل المحلات التي أضافها العميل من زر القلب في
/// بطاقة المحل (FavoriteButton). القائمة الفعلية تُعاد جلبها من الخادم
/// كل مرة تتغيّر فيها مجموعة المعرِّفات في FavoritesController (سواء من
/// هذه الشاشة نفسها أو من أي شاشة أخرى مفتوحة)، عبر مقارنة بسيطة بمفتاح
/// نصي مُرتَّب — لا نعيد الجلب على كل rebuild عادي.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<List<Merchant>>? _future;
  String _lastKey = '';

  Future<List<Merchant>> _fetch(Set<String> ids) async {
    if (ids.isEmpty) return [];

    const columns =
        'id, store_name, phone, communes(name), latitude, longitude, '
        'logo_url, cover_url, '
        'merchant_business_hours(day_of_week, open_time, close_time, is_closed)';

    final data = await Supabase.instance.client
        .from('merchants')
        .select(columns)
        .inFilter('id', ids.toList());

    final merchants = (data as List)
        .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
        .toList();
    merchants.sort((a, b) => a.storeName.compareTo(b.storeName));
    return merchants;
  }

  void _openMerchant(Merchant merchant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantProductsScreen(
          merchantId: merchant.id,
          storeName: merchant.storeName,
          logoUrl: merchant.logoUrl,
          coverUrl: merchant.coverUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<FavoritesController>().favoriteMerchantIds;
    final key = (ids.toList()..sort()).join(',');
    if (key != _lastKey) {
      _lastKey = key;
      _future = _fetch(ids);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('مفضّلتي')),
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: FutureBuilder<List<Merchant>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _CenterMessage(
                icon: Icons.wifi_off_rounded,
                message: 'تعذّر تحميل المفضّلة. تحقق من اتصالك بالإنترنت.',
              );
            }

            final merchants = snapshot.data ?? [];

            if (merchants.isEmpty) {
              return const _CenterMessage(
                icon: Icons.favorite_border_rounded,
                message:
                    'لا توجد محلات في المفضّلة بعد.\n'
                    'اضغط أيقونة القلب بجانب أي محل لإضافته هنا.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: merchants.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return MerchantCard(
                  merchant: merchant,
                  onTap: () => _openMerchant(merchant),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CenterMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
