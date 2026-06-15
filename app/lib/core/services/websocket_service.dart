import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/system_metrics.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  SystemMetrics? _latest;
  final List<SystemMetrics> _history = [];
  String _connectionStatus = 'disconnected';
  final ValueNotifier<SystemMetrics?> metricsNotifier = ValueNotifier(null);

  SystemMetrics? get latest => _latest;
  List<SystemMetrics> get history => List.unmodifiable(_history);
  String get connectionStatus => _connectionStatus;

  WebSocketService() {
    connect();
  }

  void connect() {
    _reconnectTimer?.cancel();
    _connectionStatus = 'connecting';
    notifyListeners();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8765'),
      );

      _subscription = _channel!.stream.listen(
        (dynamic data) {
          _connectionStatus = 'connected';
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final metrics = SystemMetrics.fromJson(parsed);
            _latest = metrics;
            _history.add(metrics);
            if (_history.length > 60) {
              _history.removeAt(0);
            }
            metricsNotifier.value = metrics;
            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing metrics: $e');
          }
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _connectionStatus = 'disconnected';
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    metricsNotifier.dispose();
    super.dispose();
  }
}
