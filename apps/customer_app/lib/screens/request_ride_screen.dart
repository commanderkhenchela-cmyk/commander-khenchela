import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/loading_elevated_button.dart';
import 'address_list_screen.dart';
import 'login_screen.dart';
import 'ride_detail_screen.dart';

/// شاشة طلب رحلة Taxi — نفس هيكل RequestAnythingScreen (تسجيل الدخول ثم
/// التفاصيل)، لكن بعنوانَين (انطلاق/وجهة) بدل عنوان واحد + وصف. لا
/// معاينة أجرة هنا قبل الإرسال (V1: لا RPC معاينة مخصَّصة بعد) — لكن
/// بخلاف "اطلب أي شيء"، الأجرة الحقيقية تظهر فورًا فـ RideDetailScreen
/// مباشرة بعد الإرسال (create_ride_request يحسبها فورًا، الطرفان
/// معروفان سلفًا) بدل انتظار قبول موصّل — راجع تعليق migration
/// 20260906000000.
class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({super.key});

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  String? _pickupAddressId;
  String? _pickupSummary;
  String? _dropoffAddressId;
  String? _dropoffSummary;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isSignedIn => AuthService.isSignedIn;

  Future<void> _goToLogin() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _pickAddress({required bool isPickup}) async {
    final addressId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AddressListScreen()),
    );
    if (addressId == null || !mounted) return;

    final row = await Supabase.instance.client
        .from('addresses')
        .select('id, address_text, communes(name)')
        .eq('id', addressId)
        .single();

    final communeName =
        (row['communes'] as Map<String, dynamic>)['name'] as String;
    final summary = '$communeName — ${row['address_text']}';

    setState(() {
      if (isPickup) {
        _pickupAddressId = row['id'] as String;
        _pickupSummary = summary;
      } else {
        _dropoffAddressId = row['id'] as String;
        _dropoffSummary = summary;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final requestId = await Supabase.instance.client.rpc(
        'create_ride_request',
        params: {
          'p_pickup_address_id': _pickupAddressId,
          'p_dropoff_address_id': _dropoffAddressId,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(rideId: requestId as String),
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
      case 'يجب تسجيل الدخول لطلب رحلة':
        return l10n.orderNotSignedInError;
      case 'عنوان الانطلاق غير صالح أو لا يخصك':
      case 'عنوان الوجهة غير صالح أو لا يخصك':
        return l10n.orderInvalidAddressError;
      case 'نقطتا الانطلاق والوجهة يجب أن تكونا مختلفتين':
        return l10n.ridePickupDropoffSameError;
      default:
        return l10n.orderSubmitError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canSubmit = _isSignedIn &&
        _pickupAddressId != null &&
        _dropoffAddressId != null &&
        _pickupAddressId != _dropoffAddressId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestRideTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.requestRideIntro,
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
              title: l10n.ridePickupLabel,
              isDone: _pickupAddressId != null,
              child: !_isSignedIn
                  ? Text(
                      l10n.loginFirstMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black45,
                      ),
                    )
                  : _pickupAddressId != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('✅ $_pickupSummary'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _pickAddress(isPickup: true),
                          child: Text(l10n.changeAddressAction),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () => _pickAddress(isPickup: true),
                      child: Text(l10n.selectPickupAddressAction),
                    ),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 3,
              title: l10n.rideDropoffLabel,
              isDone: _dropoffAddressId != null,
              child: !_isSignedIn
                  ? Text(
                      l10n.loginFirstMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black45,
                      ),
                    )
                  : _dropoffAddressId != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('✅ $_dropoffSummary'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _pickAddress(isPickup: false),
                          child: Text(l10n.changeAddressAction),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () => _pickAddress(isPickup: false),
                      child: Text(l10n.selectDropoffAddressAction),
                    ),
            ),
            if (_pickupAddressId != null &&
                _dropoffAddressId != null &&
                _pickupAddressId == _dropoffAddressId) ...[
              const SizedBox(height: 12),
              Text(
                l10n.ridePickupDropoffSameError,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
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
              child: Text(l10n.submitRideRequestAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// نفس _StepCard المتكرِّرة فـ checkout_screen.dart/
/// request_anything_screen.dart بالحرف.
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
