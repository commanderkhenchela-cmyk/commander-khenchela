import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/driver_service.dart';
import 'splash_screen.dart';

/// نموذج بيانات الموصّل الأولى (اسم + هاتف فقط) — نوع المركبة "دراجة"
/// ضمنيًا، بدون حقل اختيار (المرحلة 1 دراجات فقط). بعد الإرسال يُرسَل
/// الحساب بحالة "pending" إجباريًا (RLS drivers_insert_own تفرضها حتى
/// لو أُرسلت قيمة أخرى)، ثم شاشة "قيد المراجعة".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await DriverService.submitOnboarding(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;
      _goToSplash();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // سجّل مكرَّر (نفس درس merchants_owner_user_id_key) — الحساب
        // موجود بالفعل فعليًا، فقط نُعيد التوجيه بدل إظهار خطأ مربك.
        if (!mounted) return;
        _goToSplash();
        return;
      }
      setState(() => _errorMessage = 'تعذّر إرسال البيانات. حاول مرة أخرى.');
    } catch (e) {
      setState(() => _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSplash() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const SplashScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات الموصّل')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'أدخل بياناتك — سيراجعها فريق الإدارة قبل تفعيل حسابك.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const _VehicleBadge(),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخل اسمك';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (للتواصل معك أثناء التوصيل)',
                    hintText: '0555xxxxxx',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخل رقم هاتفك';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('إرسال للمراجعة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleBadge extends StatelessWidget {
  const _VehicleBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pedal_bike_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'التوصيل بالدراجة',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
