import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/driver_service.dart';
import 'splash_screen.dart';

/// نموذج بيانات الموصّل الأولى (اسم + هاتف + نوع المركبة + صورة بطاقة
/// التعريف — إلزامية، لا تفعيل بلا وثيقة هوية). نوع المركبة يحدّد أي
/// مجمّع طلبات يراه الحساب لاحقًا (bike → orders+اطلب أي شيء، car →
/// Taxi، truck → لا مجمّع بعد، خدمة مستقبلية محجوزة الاسم فقط — راجع
/// migration 20260910000000_driver_vehicle_types) وغير قابل للتعديل
/// الذاتي بعد الإرسال. بعد الإرسال يُرسَل الحساب بحالة "pending"
/// إجباريًا (RLS drivers_insert_own تفرضها حتى لو أُرسلت قيمة أخرى)،
/// ثم شاشة "قيد المراجعة".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _vehicleType = 'bike';
  File? _idCardImage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickIdCardImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _idCardImage = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCardImage == null) {
      setState(() => _errorMessage = 'أرفق صورة بطاقة التعريف — إلزامية للمراجعة.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await DriverService.submitOnboarding(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        vehicleType: _vehicleType,
        idCardImage: _idCardImage!,
      );

      if (!mounted) return;
      _goToSplash();
    } on IdCardUploadException {
      setState(
        () => _errorMessage =
            'حُفظت بياناتك لكن تعذّر رفع صورة بطاقة التعريف — تواصل مع الإدارة لإكمال المراجعة.',
      );
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
                const SizedBox(height: 16),
                _VehicleTypeSelector(
                  value: _vehicleType,
                  onChanged: (value) => setState(() => _vehicleType = value),
                ),
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
                const SizedBox(height: 16),
                _IdCardPicker(image: _idCardImage, onPick: _pickIdCardImage),
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

/// اختيار صورة بطاقة التعريف من المعرض (لا كاميرا مباشرة فـ هذه
/// المرحلة — تفاديًا لصلاحية Camera الإضافية فـ AndroidManifest، غير
/// ضرورية إذا كانت الصورة موجودة أصلًا لدى المستخدم). يعرض معاينة
/// مصغَّرة بعد الاختيار بدل اسم الملف فقط.
class _IdCardPicker extends StatelessWidget {
  final File? image;
  final VoidCallback onPick;

  const _IdCardPicker({required this.image, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: image == null ? 100 : 160,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 6),
                  const Text('إرفاق صورة بطاقة التعريف (إلزامي)'),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(image!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'تغيير الصورة',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// اختيار نوع المركبة — يحدّد أي مجمّع طلبات يرى هذا الحساب لاحقًا
/// (راجع تعليق الملف أعلاه). غير قابل للتعديل الذاتي بعد الإرسال —
/// هذه الشاشة هي الفرصة الوحيدة لاختياره بحرّية.
class _VehicleTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _VehicleTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'نوع المركبة',
          style: theme.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'bike',
              label: Text('دراجة'),
              icon: Icon(Icons.pedal_bike_rounded),
            ),
            ButtonSegment(
              value: 'car',
              label: Text('طاكسي'),
              icon: Icon(Icons.local_taxi_outlined),
            ),
            ButtonSegment(
              value: 'truck',
              label: Text('شاحنة'),
              icon: Icon(Icons.local_shipping_outlined),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        if (value == 'bike')
          const _VehicleHint(text: 'توصيل الطلبات و"اطلب أي شيء" بالدراجة.'),
        if (value == 'car')
          const _VehicleHint(text: 'رحلات الطاكسي (نقل الركّاب).'),
        if (value == 'truck')
          const _VehicleHint(
            text:
                'خدمة التوصيل بالشاحنات قادمة قريبًا — تسجيلك الآن يحجز '
                'مكانك، لن تصلك طلبات قبل إطلاق الخدمة.',
          ),
      ],
    );
  }
}

class _VehicleHint extends StatelessWidget {
  final String text;

  const _VehicleHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 13),
      ),
    );
  }
}
