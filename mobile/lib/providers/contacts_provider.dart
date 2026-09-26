import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emergency_contact_model.dart';
import '../repositories/contacts_repository.dart';
import 'auth_provider.dart';

class ContactsState {
  final List<EmergencyContactModel> contacts;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  ContactsState copyWith({
    List<EmergencyContactModel>? contacts,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ContactsRepository(apiService);
});

class ContactsNotifier extends StateNotifier<ContactsState> {
  final ContactsRepository _repository;

  ContactsNotifier(this._repository) : super(const ContactsState()) {
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getContacts();
      // Sort by priority ascending (priority 1 is highest)
      list.sort((a, b) => a.priority.compareTo(b.priority));
      state = state.copyWith(contacts: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> addContact(EmergencyContactModel contact) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final newContact = await _repository.createContact(contact);
      final updatedList = [...state.contacts, newContact]
        ..sort((a, b) => a.priority.compareTo(b.priority));
      state = state.copyWith(contacts: updatedList, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateContact(EmergencyContactModel contact) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _repository.updateContact(contact);
      final updatedList = state.contacts.map((c) => c.id == updated.id ? updated : c).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      state = state.copyWith(contacts: updatedList, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deleteContact(String id) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repository.deleteContact(id);
      final updatedList = state.contacts.where((c) => c.id != id).toList();
      state = state.copyWith(contacts: updatedList, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // Update contacts ordering/priorities locally and save to API
  Future<void> updatePriorities(List<EmergencyContactModel> reorderedList) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final List<EmergencyContactModel> updatedList = [];
      for (int i = 0; i < reorderedList.length; i++) {
        final contact = reorderedList[i];
        final expectedPriority = i + 1;
        if (contact.priority != expectedPriority) {
          final updatedContact = contact.copyWith(priority: expectedPriority);
          final savedContact = await _repository.updateContact(updatedContact);
          updatedList.add(savedContact);
        } else {
          updatedList.add(contact);
        }
      }
      updatedList.sort((a, b) => a.priority.compareTo(b.priority));
      state = state.copyWith(contacts: updatedList, isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  final repository = ref.watch(contactsRepositoryProvider);
  return ContactsNotifier(repository);
});
