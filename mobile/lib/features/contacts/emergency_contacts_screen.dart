import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/emergency_contact_model.dart';
import '../../providers/contacts_provider.dart';
import 'contact_form_dialog.dart';

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends ConsumerState<EmergencyContactsScreen> {
  void _openContactDialog([EmergencyContactModel? contact, int defaultPriority = 1]) {
    showDialog(
      context: context,
      builder: (context) => ContactFormDialog(
        contact: contact,
        defaultPriority: defaultPriority,
      ),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(contact != null
                ? 'Contact updated successfully.'
                : 'Contact added successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  void _deleteContact(EmergencyContactModel contact) {
    if (contact.id == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        final success = await ref.read(contactsProvider.notifier).deleteContact(contact.id!);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contact removed.'),
                backgroundColor: AppTheme.successColor,
              ),
            );
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
    });
  }

  void _onReorder(List<EmergencyContactModel> contacts, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final List<EmergencyContactModel> newList = List.from(contacts);
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);

    // Call notifier to update list priorities
    ref.read(contactsProvider.notifier).updatePriorities(newList);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsProvider);
    final contacts = state.contacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openContactDialog(null, contacts.length + 1),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.contact_phone_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Emergency Contacts',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add trusted contacts who will be immediately notified if you trigger an SOS alert.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E1E1E)
                              : Colors.blue.shade50,
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.blue.shade300
                                    : AppTheme.primaryBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Drag and drop contacts to change priority. Priority 1 (top) is the highest level of emergency routing.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.blue.shade100
                                        : AppTheme.primaryBlueDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ReorderableListView.builder(
                            itemCount: contacts.length,
                            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80),
                            onReorder: (oldIndex, newIndex) => _onReorder(contacts, oldIndex, newIndex),
                            itemBuilder: (context, index) {
                              final contact = contacts[index];
                              return Card(
                                key: ValueKey(contact.id ?? contact.phone),
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                                    child: Text(
                                      '${contact.priority}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          contact.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          contact.relationship,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(contact.phone),
                                        ],
                                      ),
                                      if (contact.email != null && contact.email!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.email, size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                contact.email!,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _ChannelTag(
                                            icon: Icons.sms_outlined,
                                            label: 'SMS',
                                            isActive: contact.notifySms,
                                          ),
                                          const SizedBox(width: 8),
                                          _ChannelTag(
                                            icon: Icons.email_outlined,
                                            label: 'Email',
                                            isActive: contact.notifyEmail,
                                          ),
                                          const SizedBox(width: 8),
                                          _ChannelTag(
                                            icon: Icons.notifications_none_outlined,
                                            label: 'Push',
                                            isActive: contact.notifyPush,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _openContactDialog(contact, contact.priority),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                        onPressed: () => _deleteContact(contact),
                                      ),
                                      const Icon(Icons.drag_handle, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (state.isSaving)
                      Container(
                        color: Colors.black.withOpacity(0.15),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _ChannelTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _ChannelTag({
    Key? key,
    required this.icon,
    required this.label,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.successColor.withOpacity(0.15)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isActive ? AppTheme.successColor : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? AppTheme.successColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
