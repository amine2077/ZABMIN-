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

  Completer<List<Map<String, dynamic>>>? _historyCompleter;
  Completer<List<Map<String, dynamic>>>? _connectionsCompleter;
  Completer<Map<String, dynamic>>? _killResultCompleter;

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

            final msgType = parsed['type'] as String?;

            if (msgType == 'history') {
              final rows = (parsed['data'] as List<dynamic>?)
                      ?.map((r) => Map<String, dynamic>.from(r as Map))
                      .toList() ??
                  [];
              if (_historyCompleter != null && !_historyCompleter!.isCompleted) {
                _historyCompleter!.complete(rows);
              }
              return;
            }

            if (msgType == 'process_connections') {
              final conns = (parsed['connections'] as List<dynamic>?)
                      ?.map((c) => Map<String, dynamic>.from(c as Map))
                      .toList() ??
                  [];
              if (_connectionsCompleter != null &&
                  !_connectionsCompleter!.isCompleted) {
                _connectionsCompleter!.complete(conns);
              }
              return;
            }

            if (msgType == 'kill_result') {
              if (_killResultCompleter != null &&
                  !_killResultCompleter!.isCompleted) {
                _killResultCompleter!.complete(parsed);
              }
              return;
            }

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

  void sendMessage(String json) {
    _channel?.sink.add(json);
  }

  void killProcess(int pid) {
    sendMessage(jsonEncode({'type': 'kill_process', 'pid': pid}));
  }

  Future<Map<String, dynamic>> waitForKillResult() {
    _killResultCompleter = Completer<Map<String, dynamic>>();
    return _killResultCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'success': false, 'error': 'Timeout'},
    );
  }

  Future<List<Map<String, dynamic>>> fetchConnections(int pid) {
    _connectionsCompleter = Completer<List<Map<String, dynamic>>>();
    sendMessage(jsonEncode({'type': 'get_process_connections', 'pid': pid}));
    return _connectionsCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => [],
    );
  }

  Future<List<Map<String, dynamic>>> fetchHistory(int minutes) {
    _historyCompleter = Completer<List<Map<String, dynamic>>>();
    sendMessage(
        jsonEncode({'type': 'get_history', 'duration_minutes': minutes}));
    return _historyCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => [],
    );
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
