import '../core/constants/api_constants.dart';
import '../models/medical_profile_model.dart';
import '../services/api_service.dart';

class MedicalRepository {
  final ApiService _apiService;

  MedicalRepository(this._apiService);

  Future<MedicalProfileModel> getMedicalProfile() async {
    final response = await _apiService.get(ApiConstants.medicalProfile);
    if (response.statusCode == 200) {
      return MedicalProfileModel.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to retrieve medical profile.');
    }
  }

  Future<MedicalProfileModel> updateMedicalProfile(MedicalProfileModel profile) async {
    final response = await _apiService.put(
      ApiConstants.medicalProfile,
      data: profile.toJson(),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MedicalProfileModel.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to update medical profile.');
    }
  }
}
