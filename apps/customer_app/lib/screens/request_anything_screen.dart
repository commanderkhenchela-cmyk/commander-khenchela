import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/loading_elevated_button.dart';
import 'address_list_screen.dart';
import 'delivery_request_detail_screen.dart';
import 'login_screen.dart';

/// شاشة "اطلب أي شيء" — طلب توصيل حرّ بوصف نصي، بلا تاجر ولا سلة. نفس
/// هيكل CheckoutScreen (3 خطوات: تسجيل الدخول، العنوان، ثم التفاصيل)
/// لتبقى تجربة الطلب موحّدة عبر التطبيق، لكن بلا معاينة رسم توصيل هنا
/// إطلاقًا — نقطة الانطلاق (موقع الموصّل) غير معروفة قبل قبول الطلب
/// فعليًا (راجع تعليق create_delivery_request فـ migration
/// 20260905000000)، فالرسم يظهر لأول مرة فـ DeliveryRequestDetailScreen
/// بعد القبول.
class RequestAnythingScreen extends StatefulWidget {
  const RequestAnythingScreen({super.key});

  @override
  State<RequestAnythingScreen> createState() => _RequestAnythingScreenState();
}

class _RequestAnythingScreenState extends State<RequestAnythingScreen> {
  final _descriptionController = TextEditingController();

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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

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
      if (existing != null) _applyAddress(existing);
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

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final requestId = await Supabase.instance.client.rpc(
        'create_delivery_request',
        params: {
          'p_address_id': _addressId,
          'p_description': _descriptionController.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DeliveryRequestDetailScreen(requestId: requestId as String),
        ),
      );
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.message));
    } catch (e) {
      setState(
        () => _errorMessage = AppLocalizations.of(context).orderSubmitError,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// نفس نمط _friendlyOrderError فـ checkout_screen.dart — تحويل رسائل
  /// خطأ create_delivery_request (نص عربي ثابت من السيرفر) لنص مترجَم.
  String _friendlyError(String message) {
    final l10n = AppLocalizations.of(context);
    switch (message) {
      case 'يجب تسجيل الدخول لإنشاء طلب':
        return l10n.orderNotSignedInError;
      case 'العنوان غير صالح أو لا يخصك':
        return l10n.orderInvalidAddressError;
      case 'صف ما تريد طلبه أولًا':
        return l10n.deliveryRequestEmptyDescriptionError;
      default:
        return l10n.orderSubmitError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canSubmit = _isSignedIn &&
        _addressId != null &&
        _descriptionController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestAnythingTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.requestAnythingIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
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
              title: l10n.deliveryRequestDescriptionLabel,
              isDone: _descriptionController.text.trim().isNotEmpty,
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.deliveryRequestDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
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
              onPressed: canSubmit ? _submit : null,
              child: Text(l10n.submitDeliveryRequestAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// نفس _StepCard فـ checkout_screen.dart بالحرف — لا استيراد مباشر
/// لأنها private هناك، فنسخة محلية مطابقة تمامًا.
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
