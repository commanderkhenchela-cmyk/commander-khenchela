import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../widgets/loading_elevated_button.dart';
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

  // معاينة رسم التوصيل قبل التأكيد (راجع migration
  // 20260901000000_delivery_fee_engine) — للعرض فقط، create_order يعيد
  // الحساب بنفسه من الصفر على السيرفر عند التأكيد الفعلي.
  double? _deliveryFee;
  String? _deliveryFeeMethod;
  bool _isLoadingFee = false;

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
    _loadDeliveryFeePreview();
  }

  /// معاينة رسم التوصيل — لا تُستخدَم نتيجتها كمُدخَل لإنشاء الطلب
  /// إطلاقًا (create_order يحسبها بنفسه من الصفر)، هذه فقط لعرضها
  /// للعميل قبل التأكيد. فشلها (شبكة، إعداد ناقص) لا يمنع إتمام الطلب
  /// أبدًا — يبقى النص القديم "تُحدَّد لاحقًا" ظاهرًا كما كان تمامًا.
  Future<void> _loadDeliveryFeePreview() async {
    final merchantId = context.read<CartService>().merchantId;
    if (_addressId == null || merchantId == null) return;

    setState(() {
      _isLoadingFee = true;
      _deliveryFee = null;
      _deliveryFeeMethod = null;
    });

    try {
      final result = await Supabase.instance.client.rpc(
        'preview_delivery_fee',
        params: {'p_merchant_id': merchantId, 'p_address_id': _addressId},
      );
      final row = (result as List).first as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _deliveryFee = (row['fee'] as num).toDouble();
        _deliveryFeeMethod = row['method_used'] as String;
      });
    } catch (_) {
      // صامت عمدًا — راجع تعليق الدالة أعلاه.
    } finally {
      if (mounted) setState(() => _isLoadingFee = false);
    }
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
      setState(() => _errorMessage = _friendlyOrderError(e.message));
    } catch (e) {
      setState(
        () => _errorMessage = AppLocalizations.of(context).orderSubmitError,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// يحوّل رسالة خطأ RPC `create_order` (نص عربي ثابت من السيرفر، راجع
  /// migration create_order_function) إلى رسالة مترجَمة حسب لغة التطبيق
  /// الحالية، بدل عرض النص الخام كما هو دائمًا بالعربية بغضّ النظر عن
  /// لغة الواجهة — وبدل الثقة الكاملة أن كل خطأ قادم من القاعدة سيكون
  /// نصًّا معروفًا وصديقًا؛ أي رسالة غير متوقَّعة (خطأ قيد لم يُغطَّ هنا،
  /// أو أي تفصيل تقني آخر) تُستبدَل برسالة عامة مترجَمة بدل عرضها كما هي.
  String _friendlyOrderError(String message) {
    final l10n = AppLocalizations.of(context);
    switch (message) {
      case 'يجب تسجيل الدخول لإنشاء طلب':
        return l10n.orderNotSignedInError;
      case 'المحل غير موجود أو غير موافَق عليه بعد':
        return l10n.orderMerchantNotApprovedError;
      case 'العنوان غير صالح أو لا يخصك':
        return l10n.orderInvalidAddressError;
      case 'لا يمكن إنشاء طلب فارغ':
        return l10n.orderEmptyCartError;
      case 'منتج غير موجود':
        return l10n.orderProductNotFoundError;
      case 'كل منتجات الطلب يجب أن تكون من نفس المحل':
        return l10n.orderMixedMerchantsError;
      case 'أحد المنتجات لم يعد متوفرًا حاليًا':
        return l10n.orderProductUnavailableError;
      default:
        return l10n.orderSubmitError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cart = context.watch<CartService>();
    final canConfirm = _isSignedIn && _addressId != null && !cart.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StepCard(
              stepNumber: 1,
              title: l10n.loginStepTitle,
              isDone: _isSignedIn,
              child: _isSignedIn
                  ? Text(l10n.signedInLabel)
                  : ElevatedButton(
                      onPressed: _goToLogin,
                      child: Text(l10n.loginOrSignupAction),
                    ),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 2,
              title: l10n.deliveryAddressLabel,
              isDone: _addressId != null,
              child: !_isSignedIn
                  ? Text(
                      l10n.loginFirstMessage,
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
                          child: Text(l10n.changeAddressAction),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: _goToAddress,
                      child: Text(l10n.selectDeliveryAddressAction),
                    ),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 3,
              title: l10n.reviewConfirmStepTitle,
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
                          Text(
                            l10n.currencyAmount(
                              item.subtotal.toStringAsFixed(0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Builder(
                    builder: (context) {
                      final hasRealFee = _deliveryFeeMethod != null &&
                          _deliveryFeeMethod != 'unconfigured' &&
                          _deliveryFee != null;
                      final total = cart.subtotal + (hasRealFee ? _deliveryFee! : 0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasRealFee) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.deliveryFeeLabel),
                                Text(
                                  l10n.currencyAmount(_deliveryFee!.toStringAsFixed(0)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.checkoutTotalLabel),
                              Text(
                                l10n.currencyAmount(total.toStringAsFixed(0)),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (!hasRealFee) ...[
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingFee
                                  ? l10n.estimatingDeliveryFeeMessage
                                  : l10n.deliveryFeeTbdMessage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.paymentCodLabel),
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
            LoadingElevatedButton(
              isLoading: _isSubmitting,
              onPressed: canConfirm ? () => _confirmOrder(cart) : null,
              child: Text(l10n.confirmOrderAction),
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
