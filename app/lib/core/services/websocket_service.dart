import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/system_metrics.dart';

const int _kMaxRetriesBeforeCheck = 3;

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  SystemMetrics? _latest;
  final List<SystemMetrics> _history = [];
  String _connectionStatus = 'disconnected';
  String? _agentError;
  int _connectAttempts = 0;
  final ValueNotifier<SystemMetrics?> metricsNotifier = ValueNotifier(null);

  int _nextRequestId = 1;
  final Map<int, Completer<List<Map<String, dynamic>>>> _pendingHistory = {};
  final Map<int, Completer<List<Map<String, dynamic>>>> _pendingConnections =
      {};
  final Map<int, Completer<Map<String, dynamic>>> _pendingKillByPid = {};
  final Map<int, Completer<Map<String, dynamic>>> _pendingPriority = {};

  SystemMetrics? get latest => _latest;
  List<SystemMetrics> get history => List.unmodifiable(_history);
  String get connectionStatus => _connectionStatus;
  String? get agentError => _agentError;

  WebSocketService() {
    connect();
  }

  String? _findAgentDir() {
    try {
      String searchPath = Directory(
        Platform.script.resolve('.').toFilePath(),
      ).path;
      while (true) {
        final parent = Directory(searchPath).parent.path;
        if (parent == searchPath) break;
        final segments = Uri.directory(searchPath).pathSegments;
        final dirName = segments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (dirName == 'app') {
          final candidate = Directory('$parent/agent');
          if (candidate.existsSync()) return candidate.path;
          break;
        }
        searchPath = parent;
      }
    } catch (_) {}
    return null;
  }

  String? _checkAgentStatusFile() {
    try {
      final agentDir = _findAgentDir();
      if (agentDir == null) return null;
      final file = File('$agentDir/agent_status.json');
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (data['ok'] == true) return null;
      return data['reason'] as String? ?? 'Unknown agent error';
    } catch (_) {
      return null;
    }
  }

  void connect() {
    if (_agentError != null) return;

    _reconnectTimer?.cancel();
    _connectionStatus = 'connecting';
    notifyListeners();

    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8765'));

      _subscription = _channel!.stream.listen(
        (dynamic data) {
          _connectionStatus = 'connected';
          _connectAttempts = 0;
          _agentError = null;
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final msgType = parsed['type'] as String?;
            final requestId = parsed['request_id'] as int?;

            if (msgType == 'history') {
              final rows =
                  (parsed['data'] as List<dynamic>?)
                      ?.map((r) => Map<String, dynamic>.from(r as Map))
                      .toList() ??
                  [];
              if (requestId != null && _pendingHistory.containsKey(requestId)) {
                final c = _pendingHistory.remove(requestId)!;
                if (!c.isCompleted) c.complete(rows);
              }
              return;
            }

            if (msgType == 'process_connections') {
              final conns =
                  (parsed['connections'] as List<dynamic>?)
                      ?.map((c) => Map<String, dynamic>.from(c as Map))
                      .toList() ??
                  [];
              if (requestId != null &&
                  _pendingConnections.containsKey(requestId)) {
                final c = _pendingConnections.remove(requestId)!;
                if (!c.isCompleted) c.complete(conns);
              }
              return;
            }

            if (msgType == 'priority_info' || msgType == 'priority_result') {
              final pid = parsed['pid'] as int?;
              if (pid != null && _pendingPriority.containsKey(pid)) {
                final c = _pendingPriority.remove(pid)!;
                if (!c.isCompleted) c.complete(parsed);
              }
              return;
            }

            if (msgType == 'kill_result') {
              final pid = parsed['pid'] as int?;
              if (pid != null && _pendingKillByPid.containsKey(pid)) {
                final c = _pendingKillByPid.remove(pid)!;
                if (!c.isCompleted) c.complete(parsed);
              }
              return;
            }

            final metrics = SystemMetrics.fromJson(parsed);
            assert(
              metrics.version == kZabminProtocolVersion,
              'Zabmin protocol version mismatch: agent sent v${metrics.version}, '
              'app expects v$kZabminProtocolVersion. Update the agent or app to match.',
            );
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

  int _allocRequestId() => _nextRequestId++;

  void sendMessage(String json) {
    _channel?.sink.add(json);
  }

  void killProcess(int pid) {
    final rid = _allocRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingKillByPid[pid] = completer;
    sendMessage(
      jsonEncode({'type': 'kill_process', 'pid': pid, 'request_id': rid}),
    );
    Future.delayed(const Duration(seconds: 5), () {
      final c = _pendingKillByPid.remove(pid);
      if (c != null && !c.isCompleted) {
        c.complete({'success': false, 'error': 'Timeout'});
      }
    });
  }

  Future<Map<String, dynamic>> waitForKillResult(int pid) {
    final completer = _pendingKillByPid[pid];
    if (completer != null) {
      return completer.future;
    }
    return Future.value({'success': false, 'error': 'No pending kill'});
  }

  Future<List<Map<String, dynamic>>> fetchConnections(int pid) {
    final rid = _allocRequestId();
    final completer = Completer<List<Map<String, dynamic>>>();
    _pendingConnections[rid] = completer;
    sendMessage(
      jsonEncode({
        'type': 'get_process_connections',
        'pid': pid,
        'request_id': rid,
      }),
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingConnections.remove(rid);
        return [];
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchHistory(int minutes) {
    final rid = _allocRequestId();
    final completer = Completer<List<Map<String, dynamic>>>();
    _pendingHistory[rid] = completer;
    sendMessage(
      jsonEncode({
        'type': 'get_history',
        'duration_minutes': minutes,
        'request_id': rid,
      }),
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingHistory.remove(rid);
        return [];
      },
    );
  }

  void setPriority(int pid, int priority) {
    final rid = _allocRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingPriority[pid] = completer;
    sendMessage(
      jsonEncode({
        'type': 'set_priority',
        'pid': pid,
        'priority': priority,
        'request_id': rid,
      }),
    );
    Future.delayed(const Duration(seconds: 5), () {
      final c = _pendingPriority.remove(pid);
      if (c != null && !c.isCompleted) {
        c.complete({'success': false, 'error': 'Timeout'});
      }
    });
  }

  Future<Map<String, dynamic>> fetchPriority(int pid) {
    final rid = _allocRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingPriority[pid] = completer;
    sendMessage(
      jsonEncode({'type': 'get_priority', 'pid': pid, 'request_id': rid}),
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingPriority.remove(pid);
        return {'priority': null, 'error': 'Timeout'};
      },
    );
  }

  Future<Map<String, dynamic>> waitForPriorityResult(int pid) {
    final completer = _pendingPriority[pid];
    if (completer != null) {
      return completer.future;
    }
    return Future.value({'success': false, 'error': 'No pending op'});
  }

  void _failAllPending() {
    for (final entry in _pendingHistory.entries) {
      if (!entry.value.isCompleted) entry.value.complete([]);
    }
    _pendingHistory.clear();
    for (final entry in _pendingConnections.entries) {
      if (!entry.value.isCompleted) entry.value.complete([]);
    }
    _pendingConnections.clear();
    for (final entry in _pendingKillByPid.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete({'success': false, 'error': 'Disconnected'});
      }
    }
    _pendingKillByPid.clear();
    for (final entry in _pendingPriority.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete({'priority': null, 'error': 'Disconnected'});
      }
    }
    _pendingPriority.clear();
  }

  void _handleDisconnect() {
    _connectionStatus = 'disconnected';
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _failAllPending();
    notifyListeners();

    _connectAttempts++;
    if (_connectAttempts >= _kMaxRetriesBeforeCheck) {
      final error = _checkAgentStatusFile();
      if (error != null) {
        _agentError = error;
        notifyListeners();
        return;
      }
    }
    _scheduleReconnect();
  }

  void retryConnection() {
    _agentError = null;
    _connectAttempts = 0;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _failAllPending();
    notifyListeners();
    connect();
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
    _failAllPending();
    metricsNotifier.dispose();
    super.dispose();
  }
}
