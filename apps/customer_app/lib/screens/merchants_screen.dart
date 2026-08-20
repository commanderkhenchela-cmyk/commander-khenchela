import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant.dart';
import 'merchant_products_screen.dart';

/// شاشة قائمة المحلات — تظهر بعد تأكيد الولاية.
/// تجلب فقط المحلات الموافَق عليها من طرف Admin (status = approved)،
/// نفس القاعدة المطبَّقة في RLS على جدول merchants.
class MerchantsScreen extends StatefulWidget {
  final String locationName;

  const MerchantsScreen({super.key, required this.locationName});

  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen> {
  late Future<List<Merchant>> _merchantsFuture;

  @override
  void initState() {
    super.initState();
    _merchantsFuture = _fetchMerchants();
  }

  Future<List<Merchant>> _fetchMerchants() async {
    final data = await Supabase.instance.client
        .from('merchants')
        .select('id, store_name')
        .eq('status', 'approved')
        .order('store_name');

    return (data as List)
        .map((row) => Merchant.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('المحلات في ${widget.locationName}')),
      body: FutureBuilder<List<Merchant>>(
        future: _merchantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.black45,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذّر تحميل قائمة المحلات. تحقق من اتصالك بالإنترنت.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _merchantsFuture = _fetchMerchants();
                        });
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final merchants = snapshot.data ?? [];

          if (merchants.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد محلات متاحة حاليًا. عد قريبًا!',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: merchants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final merchant = merchants[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    merchant.storeName,
                    style: theme.textTheme.titleLarge,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MerchantProductsScreen(
                          merchantId: merchant.id,
                          storeName: merchant.storeName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
