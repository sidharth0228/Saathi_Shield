import '../models/alert_response_model.dart';
import '../services/api_service.dart';

class CommunityRepository {
  final ApiService _apiService;

  CommunityRepository(this._apiService);

  Future<void> updateResponderLocation({
    required double latitude,
    required double longitude,
    required bool isAvailable,
    bool privacyShareLocation = true,
  }) async {
    final response = await _apiService.post(
      'community/responder/location/',
      data: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'is_available': isAvailable,
        'privacy_share_location': privacyShareLocation,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['error'] ?? 'Failed to update responder profile.');
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyAlerts({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiService.get(
      'community/alerts/nearby/',
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to retrieve nearby alerts.');
    }
  }

  Future<AlertResponseModel> acceptAlert(String alertId) async {
    final response = await _apiService.post('community/alerts/$alertId/accept/');
    if (response.statusCode == 200) {
      return AlertResponseModel.fromJson(response.data['details']);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to accept alert request.');
    }
  }

  Future<AlertResponseModel> updateDispatchStatus({
    required String responseId,
    required String status,
    double? latitude,
    double? longitude,
  }) async {
    final Map<String, dynamic> data = {
      'response_id': responseId,
      'status': status,
    };
    if (latitude != null && longitude != null) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }

    final response = await _apiService.post(
      'community/alerts/status/',
      data: data,
    );

    if (response.statusCode == 200) {
      return AlertResponseModel.fromJson(response.data['details']);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to update dispatch status.');
    }
  }
}
