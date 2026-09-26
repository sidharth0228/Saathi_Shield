import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

class SosTrackingState {
  final String alertId;
  final String secureToken;
  final bool isWsConnected;
  final bool isLoading;
  final String? errorMessage;
  final LatLng? victimLocation;
  final List<LatLng> movementHistory;
  final int batteryPercentage;
  final String status;
  final int elapsedSeconds;
  final String victimName;
  final Map<String, dynamic>? medicalProfile;
  final List<Map<String, dynamic>> activeResponders;

  const SosTrackingState({
    required this.alertId,
    required this.secureToken,
    this.isWsConnected = false,
    this.isLoading = false,
    this.errorMessage,
    this.victimLocation,
    this.movementHistory = const [],
    this.batteryPercentage = 100,
    this.status = 'ACTIVE',
    this.elapsedSeconds = 0,
    this.victimName = '',
    this.medicalProfile,
    this.activeResponders = const [],
  });

  SosTrackingState copyWith({
    String? alertId,
    String? secureToken,
    bool? isWsConnected,
    bool? isLoading,
    String? errorMessage,
    LatLng? victimLocation,
    List<LatLng>? movementHistory,
    int? batteryPercentage,
    String? status,
    int? elapsedSeconds,
    String? victimName,
    Map<String, dynamic>? medicalProfile,
    List<Map<String, dynamic>>? activeResponders,
  }) {
    return SosTrackingState(
      alertId: alertId ?? this.alertId,
      secureToken: secureToken ?? this.secureToken,
      isWsConnected: isWsConnected ?? this.isWsConnected,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      victimLocation: victimLocation ?? this.victimLocation,
      movementHistory: movementHistory ?? this.movementHistory,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      victimName: victimName ?? this.victimName,
      medicalProfile: medicalProfile ?? this.medicalProfile,
      activeResponders: activeResponders ?? this.activeResponders,
    );
  }
}

class SosTrackingNotifier extends StateNotifier<SosTrackingState> {
  final ApiService _apiService;
  final WebSocketService _wsService = WebSocketService();
  Timer? _pollingTimer;
  Timer? _stopwatchTimer;
  StreamSubscription? _wsSubscription;

  SosTrackingNotifier(this._apiService, String secureToken)
      : super(SosTrackingState(alertId: '', secureToken: secureToken)) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final details = await fetchDetails(state.secureToken);

      final String alertId = details['id'] ?? '';
      final double lat = double.tryParse(details['latitude']?.toString() ?? '') ?? 28.6139;
      final double lng = double.tryParse(details['longitude']?.toString() ?? '') ?? 77.2090;
      final int battery = details['battery_percentage'] ?? 100;
      final String status = details['status'] ?? 'ACTIVE';
      final String name = details['user'] != null
          ? "${details['user']['first_name']} ${details['user']['last_name']}"
          : "Emergency User";
      final mapProfile = details['medical_profile'];

      final initialLoc = LatLng(lat, lng);

      final List<LatLng> history = [];
      if (details['location_history'] is List) {
        for (var loc in details['location_history']) {
          final hLat = double.tryParse(loc['latitude']?.toString() ?? '');
          final hLng = double.tryParse(loc['longitude']?.toString() ?? '');
          if (hLat != null && hLng != null) {
            history.add(LatLng(hLat, hLng));
          }
        }
      }
      if (history.isEmpty) {
        history.add(initialLoc);
      }

      int elapsed = 0;
      if (details['created_at'] != null) {
        final created = DateTime.tryParse(details['created_at']);
        if (created != null) {
          elapsed = DateTime.now().difference(created.toLocal()).inSeconds;
        }
      }

      state = state.copyWith(
        alertId: alertId,
        victimLocation: initialLoc,
        movementHistory: history,
        batteryPercentage: battery,
        status: status,
        elapsedSeconds: elapsed,
        victimName: name,
        medicalProfile: mapProfile,
        isLoading: false,
      );

      _startStopwatch();
      _startPollingFallback();
      _connectWebSocket();

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize tracking: ${e.toString()}',
      );
      _startPollingFallback();
    }
  }

  Future<Map<String, dynamic>> fetchDetails(String token) async {
    final response = await _apiService.get('track/$token/');
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception(response.data['error'] ?? 'Could not fetch public tracking info.');
    }
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == 'ACTIVE') {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });
  }

  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (!_wsService.isConnected && state.status == 'ACTIVE') {
        try {
          final details = await fetchDetails(state.secureToken);
          _handleTelemetryUpdate(details);
        } catch (e) {
          // Silent catch on network polling errors
        }
      }
    });
  }

  void _connectWebSocket() async {
    if (state.alertId.isEmpty) return;

    _wsSubscription?.cancel();
    await _wsService.connect(state.alertId);

    _wsSubscription = _wsService.stream.listen((message) {
      final event = message['event'];
      final data = message['data'];

      if (event == 'tracker_telemetry' && data != null) {
        _handleTelemetryUpdate(data);
      } else if (event == 'assistance_accepted' && data != null) {
        _handleAssistanceAccepted(data);
      } else if (event == 'responder_status_changed' && data != null) {
        _handleResponderStatusChanged(data);
      }
    });

    state = state.copyWith(isWsConnected: _wsService.isConnected);
  }

  void _handleAssistanceAccepted(Map<String, dynamic> data) {
    final String rId = data['responder_id'] ?? '';
    final String rName = data['responder_name'] ?? 'Responder';
    final String rPhone = data['responder_phone'] ?? '';
    final int eta = data['eta_seconds'] ?? 180;

    final List<Map<String, dynamic>> updated = List.from(state.activeResponders);
    final idx = updated.indexWhere((r) => r['responder_id'] == rId);

    final responderData = {
      'responder_id': rId,
      'responder_name': rName,
      'responder_phone': rPhone,
      'status': 'ACCEPTED',
      'latitude': null,
      'longitude': null,
      'eta_seconds': eta,
    };

    if (idx != -1) {
      updated[idx] = responderData;
    } else {
      updated.add(responderData);
    }

    state = state.copyWith(activeResponders: updated);
  }

  void _handleResponderStatusChanged(Map<String, dynamic> data) {
    final String rId = data['responder_id'] ?? '';
    final String status = data['status'] ?? 'ACCEPTED';
    final double? lat = double.tryParse(data['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(data['longitude']?.toString() ?? '');

    final List<Map<String, dynamic>> updated = List.from(state.activeResponders);
    final idx = updated.indexWhere((r) => r['responder_id'] == rId);

    if (idx != -1) {
      final current = updated[idx];
      updated[idx] = {
        ...current,
        'status': status,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (status == 'ARRIVED') 'eta_seconds': 0,
        if (status == 'COMPLETED') 'eta_seconds': 0,
      };
    } else {
      updated.add({
        'responder_id': rId,
        'responder_name': 'Responder',
        'responder_phone': '',
        'status': status,
        'latitude': lat,
        'longitude': lng,
        'eta_seconds': status == 'ARRIVED' ? 0 : 120,
      });
    }

    state = state.copyWith(activeResponders: updated);
  }

  DateTime? _lastUpdateReceived;

  void _handleTelemetryUpdate(Map<String, dynamic> data) {
    final now = DateTime.now();
    if (_lastUpdateReceived != null && now.difference(_lastUpdateReceived!).inMilliseconds < 1500) {
      return;
    }
    _lastUpdateReceived = now;

    final double? lat = double.tryParse(data['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(data['longitude']?.toString() ?? '');
    final int battery = data['battery_percentage'] ?? state.batteryPercentage;
    final String status = data['status'] ?? state.status;

    if (lat != null && lng != null) {
      final newLoc = LatLng(lat, lng);
      final lastLoc = state.victimLocation;
      List<LatLng> newHistory = List.from(state.movementHistory);
      
      if (lastLoc == null || lastLoc.latitude != lat || lastLoc.longitude != lng) {
        newHistory.add(newLoc);
      }

      state = state.copyWith(
        victimLocation: newLoc,
        movementHistory: newHistory,
        batteryPercentage: battery,
        status: status,
      );
    }
  }

  void sendTelemetry(double lat, double lng, int battery) {
    if (_wsService.isConnected) {
      _wsService.sendJson({
        "event": "location_update",
        "data": {
          "latitude": lat,
          "longitude": lng,
          "battery_percentage": battery,
        }
      });
    }
  }

  // Developer simulation helper method
  void simulateIncomingEvent(String event, Map<String, dynamic> data) {
    if (event == 'assistance_accepted') {
      _handleAssistanceAccepted(data);
    } else if (event == 'responder_status_changed') {
      _handleResponderStatusChanged(data);
    } else if (event == 'tracker_telemetry') {
      _handleTelemetryUpdate(data);
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _pollingTimer?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }
}

final sosTrackingProvider = StateNotifierProvider.family<SosTrackingNotifier, SosTrackingState, String>((ref, secureToken) {
  final apiService = ref.watch(apiServiceProvider);
  return SosTrackingNotifier(apiService, secureToken);
});
