import '../models/travel_session_model.dart';
import '../services/api_service.dart';

class TravelRepository {
  final ApiService _apiService;

  TravelRepository(this._apiService);

  Future<TravelSessionModel> startTravelSession({
    required String sourceAddress,
    required double sourceLat,
    required double sourceLng,
    required String destAddress,
    required double destLat,
    required double destLng,
    required int expectedDurationMinutes,
  }) async {
    final response = await _apiService.post(
      'travel/start/',
      data: {
        'source_address': sourceAddress,
        'source_lat': sourceLat.toString(),
        'source_lng': sourceLng.toString(),
        'dest_address': destAddress,
        'dest_lat': destLat.toString(),
        'dest_lng': destLng.toString(),
        'expected_duration_minutes': expectedDurationMinutes,
      },
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return TravelSessionModel.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to start travel session.');
    }
  }

  Future<Map<String, dynamic>> pingLocation({
    required String sessionId,
    required double currentLat,
    required double currentLng,
    double speedMps = 0.0,
  }) async {
    final response = await _apiService.post(
      'travel/ping/',
      data: {
        'session_id': sessionId,
        'current_lat': currentLat,
        'current_lng': currentLng,
        'speed_mps': speedMps,
      },
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception(response.data['error'] ?? 'Failed to ping travel location.');
    }
  }

  Future<String> endTravelSession(String sessionId) async {
    final response = await _apiService.post(
      'travel/end/',
      data: {
        'session_id': sessionId,
      },
    );

    if (response.statusCode == 200) {
      return response.data['message'] ?? 'Travel session completed.';
    } else {
      throw Exception(response.data['error'] ?? 'Failed to end travel session.');
    }
  }
}
