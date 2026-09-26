import '../core/constants/api_constants.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';

class SosRepository {
  final ApiService _apiService;

  SosRepository(this._apiService);

  Future<AlertModel> triggerSos({
    required double latitude,
    required double longitude,
    String triggerType = 'ONE_TAP_SOS',
    int? batteryPercentage,
    String networkStatus = 'GOOD',
  }) async {
    final Map<String, dynamic> data = {
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'trigger_type': triggerType,
      'network_status': networkStatus,
    };
    if (batteryPercentage != null) {
      data['battery_percentage'] = batteryPercentage;
    }

    final response = await _apiService.post(
      ApiConstants.sosTrigger,
      data: data,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return AlertModel.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to trigger SOS alert.');
    }
  }

  Future<void> resolveSos({
    required String alertId,
    bool isFalseAlarm = false,
  }) async {
    final response = await _apiService.post(
      ApiConstants.sosResolve,
      data: {
        'alert_id': alertId,
        'is_false_alarm': isFalseAlarm,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(response.data['error'] ?? 'Failed to resolve SOS alert.');
    }
  }
}
