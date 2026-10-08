import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../widgets/common.dart';

/// Pops `true` when an address was saved.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _line1 = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController(text: 'Bengaluru');
  final _pincode = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.addAddress({
        'label': _label.text.trim(),
        'line1': _line1.text.trim(),
        'area': _area.text.trim(),
        'city': _city.text.trim(),
        'pincode': _pincode.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {String? Function(String?)? validator, TextInputType? kb}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: kb,
        validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add address')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _field(_label, 'Label (Home, Parents…)'),
          _field(_line1, 'Flat / house no., street'),
          _field(_area, 'Area / locality'),
          _field(_city, 'City'),
          _field(
            _pincode,
            'Pincode',
            kb: TextInputType.number,
            validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : '6-digit pincode',
          ),
          const SizedBox(height: 8),
          GradientButton(label: 'Save address', icon: Icons.check_rounded, busy: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}
