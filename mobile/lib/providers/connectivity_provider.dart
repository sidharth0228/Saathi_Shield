import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import 'sos_provider.dart';
import 'travel_provider.dart';

class ConnectivityState {
  final bool isOnline;
  final bool isMocked;
  final int queueCount;
  final bool isSyncing;

  const ConnectivityState({
    this.isOnline = true,
    this.isMocked = false,
    this.queueCount = 0,
    this.isSyncing = false,
  });

  ConnectivityState copyWith({
    bool? isOnline,
    bool? isMocked,
    int? queueCount,
    bool? isSyncing,
  }) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      isMocked: isMocked ?? this.isMocked,
      queueCount: queueCount ?? this.queueCount,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final ConnectivityService _service;
  final Ref _ref;
  StreamSubscription? _subscription;

  ConnectivityNotifier(this._service, this._ref) : super(const ConnectivityState()) {
    _subscription = _service.connectivityStream.listen((online) {
      state = state.copyWith(
        isOnline: online,
        isMocked: _service.isMocked,
        queueCount: _service.getQueue().length,
      );

      if (online && _service.getQueue().isNotEmpty) {
        syncQueue();
      }
    });
  }

  void toggleNetworkMock() {
    _service.toggleNetworkMock();
    state = state.copyWith(
      isOnline: _service.isOnline,
      isMocked: _service.isMocked,
    );
  }

  void queueAction(String type, Map<String, dynamic> data) {
    _service.queueAction(type, data);
    state = state.copyWith(queueCount: _service.getQueue().length);
  }

  Future<void> syncQueue() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);

    final queue = _service.getQueue();
    final List<int> processedIndices = [];

    for (int i = 0; i < queue.length; i++) {
      final action = queue[i];
      final type = action['type'];
      final data = action['data'];

      try {
        if (type == 'TRAVEL_PING') {
          final String sessionId = data['session_id'] ?? '';
          final double lat = data['current_lat'] ?? 0.0;
          final double lng = data['current_lng'] ?? 0.0;
          
          await _ref.read(travelRepositoryProvider).pingLocation(
            sessionId: sessionId,
            currentLat: lat,
            currentLng: lng,
          );
        } else if (type == 'SOS_TRIGGER') {
          final double lat = data['latitude'] ?? 0.0;
          final double lng = data['longitude'] ?? 0.0;
          
          await _ref.read(sosProvider.notifier).triggerAlert(
            latitude: lat,
            longitude: lng,
          );
        }
        processedIndices.add(i);
      } catch (e) {
        // Halt sync on failure
        break;
      }
    }

    // Clear synchronized items
    for (int i = processedIndices.length - 1; i >= 0; i--) {
      _service.removeActionAt(processedIndices[i]);
    }

    state = state.copyWith(
      isSyncing: false,
      queueCount: _service.getQueue().length,
    );
  }

  void clearQueue() {
    _service.clearQueue();
    state = state.copyWith(queueCount: 0);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return ConnectivityNotifier(service, ref);
});
