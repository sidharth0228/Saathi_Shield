import '../core/constants/api_constants.dart';
import '../models/emergency_contact_model.dart';
import '../services/api_service.dart';

class ContactsRepository {
  final ApiService _apiService;

  ContactsRepository(this._apiService);

  Future<List<EmergencyContactModel>> getContacts() async {
    final response = await _apiService.get(ApiConstants.contacts);
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => EmergencyContactModel.fromJson(json)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to retrieve emergency contacts.');
    }
  }

  Future<EmergencyContactModel> createContact(EmergencyContactModel contact) async {
    final response = await _apiService.post(
      ApiConstants.contacts,
      data: contact.toJson(),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return EmergencyContactModel.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to create emergency contact.');
    }
  }

  Future<EmergencyContactModel> updateContact(EmergencyContactModel contact) async {
    if (contact.id == null) {
      throw Exception('Cannot update contact without an ID.');
    }
    final response = await _apiService.put(
      '${ApiConstants.contacts}${contact.id}/',
      data: contact.toJson(),
    );
    if (response.statusCode == 200) {
      return EmergencyContactModel.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to update emergency contact.');
    }
  }

  Future<void> deleteContact(String id) async {
    final response = await _apiService.delete('${ApiConstants.contacts}$id/');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Failed to delete emergency contact.');
    }
  }
}
