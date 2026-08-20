import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/cart_service.dart';
import 'address_list_screen.dart';
import 'login_screen.dart';
import 'order_confirmation_screen.dart';

/// شاشة إتمام الطلب — 3 خطوات واضحة: تسجيل الدخول، العنوان، ثم التأكيد.
/// الدفع دائمًا COD في V1 (لا خيار آخر، فلا داعي لعرضه كقرار).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _addressId;
  String? _addressSummary;
  bool _isLoadingAddress = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isSignedIn => AuthService.isSignedIn;

  @override
  void initState() {
    super.initState();
    if (_isSignedIn) _loadAddress();
  }

  /// يحمّل العنوان الافتراضي (أو أول عنوان إن لم يوجد افتراضي بعد)،
  /// حتى لا يُجبَر العميل على اختيار عنوان في كل مرة إن كان عنده واحد فقط.
  Future<void> _loadAddress() async {
    setState(() => _isLoadingAddress = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final addresses = await Supabase.instance.client
          .from('addresses')
          .select('id, address_text, communes(name)')
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      final existing = (addresses as List).isEmpty ? null : addresses.first;

      if (existing != null) {
        _applyAddress(existing);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _applyAddress(Map<String, dynamic> row) {
    setState(() {
      _addressId = row['id'] as String;
      final communeName =
          (row['communes'] as Map<String, dynamic>)['name'] as String;
      _addressSummary = '$communeName — ${row['address_text']}';
    });
  }

  Future<void> _goToLogin() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (mounted) {
      setState(() {});
      if (_isSignedIn) _loadAddress();
    }
  }

  Future<void> _goToAddress() async {
    final addressId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AddressListScreen()),
    );
    if (addressId == null || !mounted) return;

    final row = await Supabase.instance.client
        .from('addresses')
        .select('id, address_text, communes(name)')
        .eq('id', addressId)
        .single();

    if (mounted) _applyAddress(row);
  }

  Future<void> _confirmOrder(CartService cart) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final orderId = await Supabase.instance.client.rpc(
        'create_order',
        params: {
          'p_merchant_id': cart.merchantId,
          'p_address_id': _addressId,
          'p_items': cart.items
              .map(
                (item) => {
                  'product_id': item.productId,
                  'quantity': item.quantity,
                },
              )
              .toList(),
        },
      );

      cart.clear();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(orderId: orderId as String),
        ),
      );
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'تعذّر إرسال الطلب. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartService>();
    final canConfirm = _isSignedIn && _addressId != null && !cart.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StepCard(
              stepNumber: 1,
              title: 'تسجيل الدخول',
              isDone: _isSignedIn,
              child: _isSignedIn
                  ? const Text('✅ مسجَّل الدخول')
                  : ElevatedButton(
                      onPressed: _goToLogin,
                      child: const Text('تسجيل الدخول / إنشاء حساب'),
                    ),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 2,
              title: 'عنوان التوصيل',
              isDone: _addressId != null,
              child: !_isSignedIn
                  ? Text(
                      'سجّل الدخول أولاً',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black45,
                      ),
                    )
                  : _isLoadingAddress
                  ? const Center(child: CircularProgressIndicator())
                  : _addressId != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('✅ $_addressSummary'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _goToAddress,
                          child: const Text('تغيير العنوان'),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: _goToAddress,
                      child: const Text('اختيار عنوان التوصيل'),
                    ),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 3,
              title: 'المراجعة والتأكيد',
              isDone: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...cart.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.productName} × ${item.quantity}'),
                          Text('${item.subtotal.toStringAsFixed(0)} دج'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع'),
                      Text(
                        '${cart.subtotal.toStringAsFixed(0)} دج',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'رسوم التوصيل تُحدَّد لاحقًا من الإدارة',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('الدفع: عند الاستلام (COD)'),
                    ],
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: canConfirm && !_isSubmitting
                  ? () => _confirmOrder(cart)
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('تأكيد الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final bool isDone;
  final Widget child;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.isDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDone
                      ? theme.colorScheme.primary
                      : Colors.black26,
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
