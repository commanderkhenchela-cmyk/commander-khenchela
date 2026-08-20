import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commune.dart';

const int _khenchelaWilayaId = 40;

/// شاشة إدخال/تعديل عنوان التوصيل — V1 يكتفي بعنوان واحد لكل عميل،
/// يُنشأ أو يُحدَّث هنا. البلدية تُختار هنا تحديدًا (عند الحاجة الفعلية
/// لها)، بدل خطوة منفصلة في بداية التطبيق.
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressTextController = TextEditingController();
  final _phoneController = TextEditingController();

  List<Commune> _communes = [];
  int? _selectedCommuneId;
  String? _existingAddressId;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addressTextController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      final communesData = await client
          .from('communes')
          .select('id, name')
          .eq('wilaya_id', _khenchelaWilayaId)
          .order('name');

      final communes = (communesData as List)
          .map((row) => Commune.fromMap(row as Map<String, dynamic>))
          .toList();

      final userId = client.auth.currentUser!.id;
      final existing = await client
          .from('addresses')
          .select('id, commune_id, address_text, phone')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      setState(() {
        _communes = communes;
        if (existing != null) {
          _existingAddressId = existing['id'] as String;
          _selectedCommuneId = existing['commune_id'] as int;
          _addressTextController.text = existing['address_text'] as String;
          _phoneController.text = existing['phone'] as String? ?? '';
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'تعذّر تحميل البيانات. تحقق من اتصالك.');
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
        'is_default': true,
      };

      String addressId;
      if (_existingAddressId != null) {
        await client
            .from('addresses')
            .update(row)
            .eq('id', _existingAddressId!);
        addressId = _existingAddressId!;
      } else {
        final inserted = await client
            .from('addresses')
            .insert(row)
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
      appBar: AppBar(title: const Text('عنوان التوصيل')),
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
                        decoration: const InputDecoration(
                          labelText: 'البلدية',
                        ),
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
                          final pattern = RegExp(
                            r'^(\+213|0)(5|6|7)[0-9]{8}$',
                          );
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
