import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../repositories/sos_repository.dart';
import 'auth_provider.dart';

class SosState {
  final AlertModel? activeAlert;
  final bool isLoading;
  final String? errorMessage;
  final int elapsedSeconds;

  const SosState({
    this.activeAlert,
    this.isLoading = false,
    this.errorMessage,
    this.elapsedSeconds = 0,
  });

  bool get isActive => activeAlert != null;

  SosState copyWith({
    AlertModel? activeAlert,
    bool? isLoading,
    String? errorMessage,
    int? elapsedSeconds,
    bool clearActiveAlert = false,
  }) {
    return SosState(
      activeAlert: clearActiveAlert ? null : (activeAlert ?? this.activeAlert),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

final sosRepositoryProvider = Provider<SosRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return SosRepository(apiService);
});

class SosNotifier extends StateNotifier<SosState> {
  final SosRepository _repository;
  Timer? _timer;

  SosNotifier(this._repository) : super(const SosState());

  Future<void> triggerAlert({
    required double latitude,
    required double longitude,
    int? batteryPercentage,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final alert = await _repository.triggerSos(
        latitude: latitude,
        longitude: longitude,
        batteryPercentage: batteryPercentage,
      );
      state = state.copyWith(
        activeAlert: alert,
        isLoading: false,
        elapsedSeconds: 0,
      );
      _startTimer();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> resolveAlert({bool isFalseAlarm = false}) async {
    final alertId = state.activeAlert?.alertId;
    if (alertId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.resolveSos(alertId: alertId, isFalseAlarm: isFalseAlarm);
      _stopTimer();
      state = state.copyWith(
        isLoading: false,
        clearActiveAlert: true,
        elapsedSeconds: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void setActiveAlertDirectly(AlertModel alert) {
    _stopTimer();
    state = state.copyWith(
      activeAlert: alert,
      isLoading: false,
      elapsedSeconds: 0,
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final sosProvider = StateNotifierProvider<SosNotifier, SosState>((ref) {
  final repository = ref.watch(sosRepositoryProvider);
  return SosNotifier(repository);
});
