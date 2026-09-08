import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/loading_elevated_button.dart';
import '../widgets/request_intro_header.dart';
import '../widgets/step_card.dart';
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
  final _destinationController = TextEditingController();

  // 'receive' = العميل يريد استلام غرض (السلوك الأصلي). 'send' = العميل
  // يملك الغرض ويريد إيصاله لمكان/شخص آخر — راجع تعليق migration
  // 20260908000000_delivery_request_send_receive لمعنى كل حقل فـ كل حالة.
  String _requestType = 'receive';

  String? _addressId;
  String? _addressSummary;
  bool _isLoadingAddress = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isSignedIn => AuthService.isSignedIn;
  bool get _isSend => _requestType == 'send';

  @override
  void initState() {
    super.initState();
    if (_isSignedIn) _loadAddress();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _destinationController.dispose();
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
          'p_request_type': _requestType,
          if (_isSend) 'p_destination_text': _destinationController.text.trim(),
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
      case 'حسابك موقوف، يرجى التواصل مع الإدارة':
        return l10n.accountSuspendedError;
      case 'العنوان غير صالح أو لا يخصك':
        return l10n.orderInvalidAddressError;
      case 'صف ما تريد طلبه أولًا':
        return l10n.deliveryRequestEmptyDescriptionError;
      case 'حدّد وجهة التسليم أولًا':
        return l10n.deliveryRequestEmptyDestinationError;
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
        _descriptionController.text.trim().isNotEmpty &&
        (!_isSend || _destinationController.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestAnythingTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RequestIntroHeader(
              icon: Icons.local_shipping_outlined,
              text: l10n.requestAnythingIntro,
            ),
            const SizedBox(height: 20),
            // اختيار الاتجاه أولًا — يغيّر معنى الخطوات التالية بالكامل
            // (راجع تعليق migration 20260908000000 لمعنى كل حقل فـ كل حالة).
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'receive',
                  label: Text(l10n.deliveryRequestTypeReceive),
                  icon: const Icon(Icons.call_received_rounded),
                ),
                ButtonSegment(
                  value: 'send',
                  label: Text(l10n.deliveryRequestTypeSend),
                  icon: const Icon(Icons.call_made_rounded),
                ),
              ],
              selected: {_requestType},
              onSelectionChanged: (selection) =>
                  setState(() => _requestType = selection.first),
            ),
            const SizedBox(height: 16),
            StepCard(
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
            StepCard(
              stepNumber: 2,
              title: _isSend
                  ? l10n.deliveryRequestPickupLabel
                  : l10n.deliveryAddressLabel,
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
            if (_isSend) ...[
              const SizedBox(height: 12),
              StepCard(
                stepNumber: 3,
                title: l10n.deliveryRequestDestinationLabel,
                isDone: _destinationController.text.trim().isNotEmpty,
                child: TextField(
                  controller: _destinationController,
                  maxLines: 3,
                  maxLength: 200,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.deliveryRequestDestinationHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            StepCard(
              stepNumber: _isSend ? 4 : 3,
              title: l10n.deliveryRequestDescriptionLabel,
              isDone: _descriptionController.text.trim().isNotEmpty,
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _isSend
                      ? l10n.deliveryRequestSendDescriptionHint
                      : l10n.deliveryRequestDescriptionHint,
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
