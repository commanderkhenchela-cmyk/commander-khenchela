import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/address.dart';
import 'address_form_screen.dart';

/// شاشة "عناويني" — تعرض كل عناوين العميل المحفوظة.
/// عند فتحها من "إتمام الطلب": الضغط على عنوان يختاره ويرجع به مباشرة.
/// عند فتحها من "حسابي": نفس الشاشة تُستخدم للإدارة (تعديل/حذف/تعيين
/// كافتراضي) بدون الحاجة لشاشة منفصلة.
class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  late Future<List<DeliveryAddress>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _fetchAddresses();
  }

  Future<List<DeliveryAddress>> _fetchAddresses() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client
        .from('addresses')
        .select(
          'id, commune_id, address_text, phone, is_default, communes(name)',
        )
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => DeliveryAddress.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _refresh() {
    setState(() {
      _addressesFuture = _fetchAddresses();
    });
  }

  Future<void> _addOrEdit({DeliveryAddress? address}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(existingAddress: address),
      ),
    );
    if (result != null) _refresh();
  }

  Future<void> _makeDefault(DeliveryAddress address) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;

    try {
      await client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
      await client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', address.id);
    } catch (_) {
      // لو فشل الطلب الثاني بعد نجاح الأول (مثلاً انقطاع شبكة لحظي)، لا
      // يبقى العميل بدون أي عنوان افتراضي بصمت — نعرض خطأ واضحًا،
      // و_refresh() أدناه يعكس الحالة الفعلية في قاعدة البيانات بأي حال.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).setDefaultAddressError),
        ),
      );
    }

    _refresh();
  }

  Future<void> _delete(DeliveryAddress address) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAddressTitle),
        content: Text(l10n.deleteAddressConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.goBackAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('addresses')
          .delete()
          .eq('id', address.id);
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.deleteAddressError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addressesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: Text(l10n.newAddressAction),
      ),
      body: FutureBuilder<List<DeliveryAddress>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(l10n.addressesLoadError));
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.noAddressesMessage, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: addresses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(address.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                address.communeName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (address.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  l10n.defaultBadge,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(address.addressText),
                        const SizedBox(height: 2),
                        Text(
                          address.phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _addOrEdit(address: address),
                              child: Text(l10n.editAction),
                            ),
                            if (!address.isDefault)
                              TextButton(
                                onPressed: () => _makeDefault(address),
                                child: Text(l10n.setAsDefaultAction),
                              ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: () => _delete(address),
                              tooltip: l10n.deleteAction,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
