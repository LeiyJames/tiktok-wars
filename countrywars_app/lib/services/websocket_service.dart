// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

typedef EventCallback = void Function(Map<String, dynamic> data);

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String _serverUrl = '';
  bool _connected = false;
  final List<EventCallback> _listeners = [];

  bool get connected => _connected;

  void setUrl(String url) {
    _serverUrl = url.replaceFirst('http', 'ws').replaceFirst('https', 'wss');
    if (!_serverUrl.endsWith('/ws')) {
      _serverUrl = '${_serverUrl.trimRight()}/ws';
    }
  }

  void addListener2(EventCallback cb) => _listeners.add(cb);
  void removeListener2(EventCallback cb) => _listeners.remove(cb);

  void connect() {
    if (_serverUrl.isEmpty) return;
    _reconnectTimer?.cancel();
    try {
      final uri = Uri.parse(_serverUrl);
      _channel = WebSocketChannel.connect(uri);
      _connected = true;
      notifyListeners();

      _channel!.stream.listen(
        (msg) {
          try {
            final data = json.decode(msg as String) as Map<String, dynamic>;
            for (final cb in List.from(_listeners)) {
              cb(data);
            }
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (_) {
          _connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _connected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
