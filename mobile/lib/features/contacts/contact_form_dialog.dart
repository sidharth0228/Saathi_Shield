import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/emergency_contact_model.dart';
import '../../providers/contacts_provider.dart';

class ContactFormDialog extends ConsumerStatefulWidget {
  final EmergencyContactModel? contact;
  final int defaultPriority;

  const ContactFormDialog({
    Key? key,
    this.contact,
    required this.defaultPriority,
  }) : super(key: key);

  @override
  ConsumerState<ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends ConsumerState<ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _notifySms = true;
  bool _notifyEmail = true;
  bool _notifyPush = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      final c = widget.contact!;
      _nameController.text = c.name;
      _relationshipController.text = c.relationship;
      _phoneController.text = c.phone;
      _emailController.text = c.email ?? '';
      _notifySms = c.notifySms;
      _notifyEmail = c.notifyEmail;
      _notifyPush = c.notifyPush;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final newContact = EmergencyContactModel(
      id: widget.contact?.id,
      name: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      notifySms: _notifySms,
      notifyEmail: _notifyEmail,
      notifyPush: _notifyPush,
      priority: widget.contact?.priority ?? widget.defaultPriority,
    );

    bool success = false;
    if (widget.contact != null) {
      success = await ref.read(contactsProvider.notifier).updateContact(newContact);
    } else {
      success = await ref.read(contactsProvider.notifier).addContact(newContact);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        final error = ref.read(contactsProvider).errorMessage ?? 'An error occurred';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Contact' : 'Add Emergency Contact'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter relationship' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Emergency Notification Channels',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Send SMS Alert'),
                value: _notifySms,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _notifySms = val;
                    });
                  }
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Send Email Alert'),
                value: _notifyEmail,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _notifyEmail = val;
                    });
                  }
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Send Push Notification'),
                value: _notifyPush,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _notifyPush = val;
                    });
                  }
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 40),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
