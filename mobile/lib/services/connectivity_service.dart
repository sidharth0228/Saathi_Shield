import 'dart:async';

class ConnectivityService {
  bool _isOnline = true;
  bool _isMocked = false;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  
  // Stores queued action descriptors for syncing: e.g. {'type': 'TRAVEL_PING', 'data': {...}}
  final List<Map<String, dynamic>> _queue = [];

  Stream<bool> get connectivityStream => _controller.stream;

  bool get isOnline => _isOnline;
  bool get isMocked => _isMocked;

  void toggleNetworkMock() {
    _isMocked = !_isMocked;
    _isOnline = !_isMocked;
    _controller.add(_isOnline);
  }

  void forceOnline() {
    _isMocked = false;
    _isOnline = true;
    _controller.add(_isOnline);
  }

  void forceOffline() {
    _isMocked = true;
    _isOnline = false;
    _controller.add(_isOnline);
  }

  void queueAction(String type, Map<String, dynamic> data) {
    _queue.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> getQueue() {
    return List.unmodifiable(_queue);
  }

  void removeActionAt(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
    }
  }

  void clearQueue() {
    _queue.clear();
  }
}
