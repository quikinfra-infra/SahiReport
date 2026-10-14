// lib/features/owner/settings/screens/edit_profile_screen.dart
// ─────────────────────────────────────────────────────────────
// Editable owner profile: name, company, GSTIN, phone.
// Saves via authProvider.notifier.updateProfile(...) which updates
// the owners row and refreshes in-memory state.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final owner = ref.read(authProvider).owner;
    _nameCtrl = TextEditingController(text: owner?.fullName ?? '');
    _companyCtrl = TextEditingController(text: owner?.companyName ?? '');
    _gstinCtrl = TextEditingController(text: owner?.gstin ?? '');
    _phoneCtrl = TextEditingController(text: owner?.phone ?? '');
    _addressCtrl = TextEditingController(text: owner?.addressLine ?? '');
    _cityCtrl = TextEditingController(text: owner?.city ?? '');
    _stateCtrl = TextEditingController(text: owner?.state ?? '');
    _pincodeCtrl = TextEditingController(text: owner?.pincode ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _gstinCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authProvider).owner;

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Email (read-only — changing it is an auth flow)
            _ReadOnlyField(label: 'Email', value: owner?.email ?? '—'),
            const SizedBox(height: 16),

            const _Label('Full Name'),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your name'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
            const SizedBox(height: 16),

            const _Label('Company Name'),
            TextFormField(
              controller: _companyCtrl,
              textCapitalization: TextCapitalization.words,
              decoration:
              const InputDecoration(hintText: 'Company (optional)'),
            ),
            const SizedBox(height: 16),

            const _Label('GSTIN'),
            TextFormField(
              controller: _gstinCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              decoration: const InputDecoration(
                hintText: '15-character GSTIN (optional)',
                counterText: '',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // optional
                final re = RegExp(
                    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                return re.hasMatch(t.toUpperCase())
                    ? null
                    : 'Enter a valid 15-character GSTIN';
              },
            ),
            const SizedBox(height: 16),

            const _Label('Phone'),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration:
              const InputDecoration(hintText: 'Phone number (optional)'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // optional
                final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length >= 10
                    ? null
                    : 'Enter a valid phone number';
              },
            ),
            const SizedBox(height: 16),

            const _Label('Billing Address'),
            TextFormField(
              controller: _addressCtrl,
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Address line (optional)'),
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('City'),
                      TextFormField(
                        controller: _cityCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                        const InputDecoration(hintText: 'City'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pincode'),
                      TextFormField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Pincode',
                          counterText: '',
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          return t.length == 6
                              ? null
                              : 'Enter a valid 6-digit pincode';
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const _Label('State'),
            TextFormField(
              controller: _stateCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'State'),
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
        fullName: _nameCtrl.text.trim(),
        companyName: _companyCtrl.text.trim().isEmpty
            ? null
            : _companyCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim().isEmpty
            ? null
            : _gstinCtrl.text.trim().toUpperCase(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        addressLine: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty
            ? null
            : _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty
            ? null
            : _stateCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim().isEmpty
            ? null
            : _pincodeCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save profile. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.grayDark)),
  );
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.grayBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.grayBorder, width: 0.5),
    ),
    child: Row(
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, color: AppTheme.grayText)),
        Expanded(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.navyDark)),
        ),
        const Icon(Icons.lock_outline, size: 14, color: AppTheme.grayText),
      ],
    ),
  );
}
