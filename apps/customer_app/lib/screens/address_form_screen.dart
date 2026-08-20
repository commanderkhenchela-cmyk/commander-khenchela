import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commune.dart';
import '../models/address.dart';

const int _khenchelaWilayaId = 40;

/// شاشة إضافة عنوان جديد أو تعديل عنوان موجود (يُمرَّر عبر [existingAddress]).
/// جزء من دعم عدة عناوين — كل عنوان مستقل، ولا يوجد "العنوان الوحيد" بعد الآن.
class AddressFormScreen extends StatefulWidget {
  final DeliveryAddress? existingAddress;

  const AddressFormScreen({super.key, this.existingAddress});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressTextController;
  late final TextEditingController _phoneController;

  List<Commune> _communes = [];
  int? _selectedCommuneId;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEdit => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();
    _addressTextController = TextEditingController(
      text: widget.existingAddress?.addressText ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.existingAddress?.phone ?? '',
    );
    _selectedCommuneId = widget.existingAddress?.communeId;
    _loadCommunes();
  }

  @override
  void dispose() {
    _addressTextController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunes() async {
    try {
      final communesData = await Supabase.instance.client
          .from('communes')
          .select('id, name')
          .eq('wilaya_id', _khenchelaWilayaId)
          .order('name');

      setState(() {
        _communes = (communesData as List)
            .map((row) => Commune.fromMap(row as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'تعذّر تحميل قائمة البلديات.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommuneId == null) {
      setState(() => _errorMessage = 'اختر البلدية');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final row = {
        'user_id': userId,
        'wilaya_id': _khenchelaWilayaId,
        'commune_id': _selectedCommuneId,
        'address_text': _addressTextController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      String addressId;
      if (_isEdit) {
        await client
            .from('addresses')
            .update(row)
            .eq('id', widget.existingAddress!.id);
        addressId = widget.existingAddress!.id;
      } else {
        // أول عنوان يضيفه العميل يصبح الافتراضي تلقائيًا.
        final existing = await client
            .from('addresses')
            .select('id')
            .eq('user_id', userId);

        final inserted = await client
            .from('addresses')
            .insert({...row, 'is_default': (existing as List).isEmpty})
            .select('id')
            .single();
        addressId = inserted['id'] as String;
      }

      if (!mounted) return;
      Navigator.of(context).pop(addressId);
    } catch (e) {
      setState(() => _errorMessage = 'تعذّر حفظ العنوان. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل العنوان' : 'إضافة عنوان جديد'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCommuneId,
                        decoration: const InputDecoration(labelText: 'البلدية'),
                        items: _communes
                            .map(
                              (commune) => DropdownMenuItem(
                                value: commune.id,
                                child: Text(commune.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedCommuneId = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressTextController,
                        decoration: const InputDecoration(
                          labelText: 'العنوان بالتفصيل',
                          hintText: 'الحي، الشارع، رقم المنزل...',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل عنوانك';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف التواصل عند التوصيل',
                          hintText: '0555xxxxxx',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          final pattern = RegExp(r'^(\+213|0)(5|6|7)[0-9]{8}$');
                          if (!pattern.hasMatch(phone)) {
                            return 'أدخل رقم هاتف جزائري صحيح';
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
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('حفظ العنوان'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
