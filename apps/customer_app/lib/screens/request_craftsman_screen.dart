import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/craftsman_request.dart';
import '../services/auth_service.dart';
import '../widgets/loading_elevated_button.dart';
import '../widgets/step_card.dart';
import 'address_list_screen.dart';
import 'craftsman_request_detail_screen.dart';
import 'login_screen.dart';

/// شاشة طلب "حرفيون" — نفس هيكل RequestAnythingScreen بالضبط (دخول ثم
/// عنوان ثم تفاصيل)، مع اختيار تصنيف الحرفة إضافيًا. لا معاينة سعر
/// إطلاقًا (V1: لا رسم تنقله المنصّة أصلًا — العمل يُسعَّر مباشرة بين
/// العميل والحرفي بعد الربط اليدوي، راجع تعليق migration
/// 20260907000000).
class RequestCraftsmanScreen extends StatefulWidget {
  const RequestCraftsmanScreen({super.key});

  @override
  State<RequestCraftsmanScreen> createState() =>
      _RequestCraftsmanScreenState();
}

class _RequestCraftsmanScreenState extends State<RequestCraftsmanScreen> {
  final _descriptionController = TextEditingController();

  String? _craftType;
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
        'create_craftsman_request',
        params: {
          'p_address_id': _addressId,
          'p_craft_type': _craftType,
          'p_description': _descriptionController.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              CraftsmanRequestDetailScreen(requestId: requestId as String),
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
        _craftType != null &&
        _descriptionController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestCraftsmanTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.requestCraftsmanIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
              title: l10n.craftTypeLabel,
              isDone: _craftType != null,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in CraftsmanRequest.craftTypes)
                    ChoiceChip(
                      label: Text(
                        CraftsmanRequest.craftTypeLabel(type, l10n),
                      ),
                      selected: _craftType == type,
                      onSelected: (_) => setState(() => _craftType = type),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StepCard(
              stepNumber: 3,
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
            StepCard(
              stepNumber: 4,
              title: l10n.deliveryRequestDescriptionLabel,
              isDone: _descriptionController.text.trim().isNotEmpty,
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.craftsmanDescriptionHint,
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
