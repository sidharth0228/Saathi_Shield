import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../models/travel_session_model.dart';
import '../repositories/travel_repository.dart';
import 'auth_provider.dart';
import 'sos_provider.dart';
import 'connectivity_provider.dart';
import 'notifications_provider.dart';

class TravelState {
  final TravelSessionModel? activeSession;
  final bool isLoading;
  final String? errorMessage;
  final double currentLat;
  final double currentLng;
  final double riskScore;
  final String riskLabel; // SAFE, SUSPICIOUS, DANGEROUS
  final bool deviationDetected;
  final int routeIndex;
  final bool isDeviatedSimulation;

  const TravelState({
    this.activeSession,
    this.isLoading = false,
    this.errorMessage,
    this.currentLat = 0.0,
    this.currentLng = 0.0,
    this.riskScore = 10.0,
    this.riskLabel = 'SAFE',
    this.deviationDetected = false,
    this.routeIndex = 0,
    this.isDeviatedSimulation = false,
  });

  bool get isActive => activeSession != null;

  TravelState copyWith({
    TravelSessionModel? activeSession,
    bool? isLoading,
    String? errorMessage,
    double? currentLat,
    double? currentLng,
    double? riskScore,
    String? riskLabel,
    bool? deviationDetected,
    int? routeIndex,
    bool? isDeviatedSimulation,
    bool clearSession = false,
  }) {
    return TravelState(
      activeSession: clearSession ? null : (activeSession ?? this.activeSession),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      riskScore: riskScore ?? this.riskScore,
      riskLabel: riskLabel ?? this.riskLabel,
      deviationDetected: deviationDetected ?? this.deviationDetected,
      routeIndex: routeIndex ?? this.routeIndex,
      isDeviatedSimulation: isDeviatedSimulation ?? this.isDeviatedSimulation,
    );
  }
}

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return TravelRepository(apiService);
});

class TravelNotifier extends StateNotifier<TravelState> {
  final TravelRepository _repository;
  final Ref _ref;
  Timer? _pingTimer;

  TravelNotifier(this._repository, this._ref) : super(const TravelState());

  Future<void> startSession({
    required String sourceAddress,
    required double sourceLat,
    required double sourceLng,
    required String destAddress,
    required double destLat,
    required double destLng,
    int expectedDurationMinutes = 30,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _repository.startTravelSession(
        sourceAddress: sourceAddress,
        sourceLat: sourceLat,
        sourceLng: sourceLng,
        destAddress: destAddress,
        destLat: destLat,
        destLng: destLng,
        expectedDurationMinutes: expectedDurationMinutes,
      );
      state = state.copyWith(
        activeSession: session,
        isLoading: false,
        currentLat: sourceLat,
        currentLng: sourceLng,
        routeIndex: 0,
        deviationDetected: false,
        riskScore: 10.0,
        riskLabel: 'SAFE',
        isDeviatedSimulation: false,
      );
      _startPingTimer();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> endSession() async {
    final sessionId = state.activeSession?.id;
    if (sessionId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.endTravelSession(sessionId);
      _stopPingTimer();
      state = state.copyWith(
        isLoading: false,
        clearSession: true,
        routeIndex: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void toggleDeviationSimulation() {
    state = state.copyWith(isDeviatedSimulation: !state.isDeviatedSimulation);
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pingLocation();
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _pingLocation() async {
    final session = state.activeSession;
    if (session == null) return;

    final geojson = session.routeGeojson;
    final List<dynamic>? coordinates = geojson?['geometry']?['coordinates'];
    if (coordinates == null || coordinates.isEmpty) return;

    double nextLat = state.currentLat;
    double nextLng = state.currentLng;
    int nextIndex = state.routeIndex;

    if (state.isDeviatedSimulation) {
      // Add significant offset to cause deviation > 500m
      nextLat += 0.008;
      nextLng += 0.008;
    } else {
      nextIndex = (state.routeIndex + 1) % coordinates.length;
      final point = coordinates[nextIndex];
      nextLng = (point[0] as num).toDouble();
      nextLat = (point[1] as num).toDouble();
    }

    final connState = _ref.read(connectivityProvider);
    if (!connState.isOnline) {
      _ref.read(connectivityProvider.notifier).queueAction('TRAVEL_PING', {
        'session_id': session.id,
        'current_lat': nextLat,
        'current_lng': nextLng,
      });
      state = state.copyWith(
        currentLat: nextLat,
        currentLng: nextLng,
        routeIndex: nextIndex,
      );
      return;
    }

    try {
      final response = await _repository.pingLocation(
        sessionId: session.id,
        currentLat: nextLat,
        currentLng: nextLng,
      );

      final bool deviation = response['route_deviation_detected'] ?? false;
      final bool sosTriggered = response['sos_triggered'] ?? false;
      final double score = (response['risk_score'] as num?)?.toDouble() ?? 10.0;
      final String label = response['risk_label'] ?? 'SAFE';

      if (deviation && !state.deviationDetected) {
        _ref.read(notificationsProvider.notifier).addNotification(
          title: 'Route Deviation Warning',
          body: 'You have strayed from the safe path by 550m. Responders alert standby.',
          category: 'TRAVEL',
        );
      }

      if (sosTriggered) {
        _stopPingTimer();
        state = state.copyWith(
          clearSession: true,
          routeIndex: 0,
        );

        final alertId = response['alert_id']?.toString() ?? '';
        if (alertId.isNotEmpty) {
          // Force active state directly inside sosProvider
          final mockAlert = AlertModel(
            alertId: alertId,
            secureToken: 'deviated_auto_sos_token',
            trackingUrl: 'https://saathishield.live/track/deviated_auto_sos_token/',
            message: 'Auto SOS alert triggered via route deviation.',
          );
          _ref.read(sosProvider.notifier).setActiveAlertDirectly(mockAlert);
        }
        return;
      }

      state = state.copyWith(
        currentLat: nextLat,
        currentLng: nextLng,
        routeIndex: nextIndex,
        deviationDetected: deviation,
        riskScore: score,
        riskLabel: label,
      );
    } catch (e) {
      // Skip updates on temporary network loss
    }
  }

  @override
  void dispose() {
    _stopPingTimer();
    super.dispose();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final travelProvider = StateNotifierProvider<TravelNotifier, TravelState>((ref) {
  final repository = ref.watch(travelRepositoryProvider);
  return TravelNotifier(repository, ref);
});
