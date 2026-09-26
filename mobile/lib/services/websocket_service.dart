import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/constants/api_constants.dart';

class WebSocketService {
  WebSocket? _webSocket;
  final StreamController<Map<String, dynamic>> _streamController = StreamController<Map<String, dynamic>>.broadcast();
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  String? _currentAlertId;
  String? _currentToken;

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  bool get isConnected => _webSocket != null && _webSocket!.readyState == WebSocket.open;

  Future<void> connect(String alertId, {String? token}) async {
    _currentAlertId = alertId;
    _currentToken = token;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_currentAlertId == null) return;

    // Parse baseUrl to construct ws/wss endpoint
    final baseUri = Uri.parse(ApiConstants.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final hostPort = baseUri.port != 80 && baseUri.port != 443 ? ':${baseUri.port}' : '';
    
    var wsUrlString = '$wsScheme://${baseUri.host}$hostPort/ws/sos/$_currentAlertId/';
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      wsUrlString += '?token=$_currentToken';
    }

    try {
      _webSocket = await WebSocket.connect(wsUrlString).timeout(const Duration(seconds: 10));
      _reconnectAttempts = 0; // reset reconnect attempts on successful connection

      _webSocket!.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            _streamController.add(data);
          } catch (e) {
            // Ignore format errors
          }
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _webSocket = null;
    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      // Exponential backoff (1s, 2s, 4s, 8s, up to 30s max)
      final backoffSeconds = (1 << _reconnectAttempts).clamp(1, 30);
      _reconnectAttempts++;
      _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
        _establishConnection();
      });
    }
  }

  void sendJson(Map<String, dynamic> json) {
    if (isConnected) {
      _webSocket!.add(jsonEncode(json));
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _webSocket?.close();
    _webSocket = null;
    _currentAlertId = null;
    _currentToken = null;
  }
}
