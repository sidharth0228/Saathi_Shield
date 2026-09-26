import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_response_model.dart';
import '../repositories/community_repository.dart';
import 'auth_provider.dart';

class CommunityState {
  final bool isAvailable;
  final double currentLat;
  final double currentLng;
  final List<Map<String, dynamic>> nearbyAlerts;
  final AlertResponseModel? activeDispatch;
  final bool isLoading;
  final String? errorMessage;

  const CommunityState({
    this.isAvailable = false,
    this.currentLat = 28.6140, // Start slightly offset from Delhi victim default (28.6139, 77.2090)
    this.currentLng = 77.2080,
    this.nearbyAlerts = const [],
    this.activeDispatch,
    this.isLoading = false,
    this.errorMessage,
  });

  CommunityState copyWith({
    bool? isAvailable,
    double? currentLat,
    double? currentLng,
    List<Map<String, dynamic>>? nearbyAlerts,
    AlertResponseModel? activeDispatch,
    bool? isLoading,
    String? errorMessage,
    bool clearDispatch = false,
  }) {
    return CommunityState(
      isAvailable: isAvailable ?? this.isAvailable,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      nearbyAlerts: nearbyAlerts ?? this.nearbyAlerts,
      activeDispatch: clearDispatch ? null : (activeDispatch ?? this.activeDispatch),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CommunityRepository(apiService);
});

class CommunityNotifier extends StateNotifier<CommunityState> {
  final CommunityRepository _repository;
  Timer? _locationPingTimer;
  Timer? _simulationTimer;

  CommunityNotifier(this._repository) : super(const CommunityState());

  Future<void> toggleAvailability(bool available) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateResponderLocation(
        latitude: state.currentLat,
        longitude: state.currentLng,
        isAvailable: available,
      );
      state = state.copyWith(isAvailable: available, isLoading: false);
      if (available) {
        _startLocationPings();
        fetchNearbyAlerts();
      } else {
        _stopLocationPings();
        state = state.copyWith(nearbyAlerts: const []);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> fetchNearbyAlerts() async {
    try {
      final alerts = await _repository.getNearbyAlerts(
        latitude: state.currentLat,
        longitude: state.currentLng,
      );
      state = state.copyWith(nearbyAlerts: alerts);
    } catch (e) {
      // Ignore background fetch errors
    }
  }

  Future<bool> acceptEmergency(String alertId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dispatch = await _repository.acceptAlert(alertId);
      state = state.copyWith(activeDispatch: dispatch, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> updateStatus(String newStatus, {double? lat, double? lng}) async {
    final dispatch = state.activeDispatch;
    if (dispatch == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updated = await _repository.updateDispatchStatus(
        responseId: dispatch.id,
        status: newStatus,
        latitude: lat ?? state.currentLat,
        longitude: lng ?? state.currentLng,
      );

      if (newStatus == 'COMPLETED' || newStatus == 'CANCELLED') {
        _stopSimulation();
        state = state.copyWith(
          activeDispatch: null,
          clearDispatch: true,
          isLoading: false,
        );
        fetchNearbyAlerts();
      } else {
        state = state.copyWith(activeDispatch: updated, isLoading: false);
        if (newStatus == 'EN_ROUTE') {
          _startSimulationMovement();
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void _startLocationPings() {
    _locationPingTimer?.cancel();
    _locationPingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (state.isAvailable && state.activeDispatch == null) {
        _repository.updateResponderLocation(
          latitude: state.currentLat,
          longitude: state.currentLng,
          isAvailable: true,
        );
        fetchNearbyAlerts();
      }
    });
  }

  void _stopLocationPings() {
    _locationPingTimer?.cancel();
    _locationPingTimer = null;
  }

  void _startSimulationMovement() {
    _stopSimulation();
    // Simulate coordinates movement towards the victim (New Delhi default center)
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final dispatch = state.activeDispatch;
      if (dispatch == null || dispatch.status != 'EN_ROUTE') {
        timer.cancel();
        return;
      }

      final double victimLat = 28.6139;
      final double victimLng = 77.2090;

      final double dLat = victimLat - state.currentLat;
      final double dLng = victimLng - state.currentLng;

      // Take 25% steps towards victim
      final double nextLat = state.currentLat + (dLat * 0.25);
      final double nextLng = state.currentLng + (dLng * 0.25);

      final bool arrived = dLat.abs() < 0.0002 && dLng.abs() < 0.0002;

      state = state.copyWith(currentLat: nextLat, currentLng: nextLng);

      if (arrived) {
        timer.cancel();
        updateStatus('ARRIVED', lat: victimLat, lng: victimLng);
      } else {
        try {
          final updated = await _repository.updateDispatchStatus(
            responseId: dispatch.id,
            status: 'EN_ROUTE',
            latitude: nextLat,
            longitude: nextLng,
          );
          state = state.copyWith(activeDispatch: updated);
        } catch (e) {
          // Ignore network errors in simulation ticks
        }
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    _stopLocationPings();
    _stopSimulation();
    super.dispose();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final communityProvider = StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
  final repository = ref.watch(communityRepositoryProvider);
  return CommunityNotifier(repository);
});
