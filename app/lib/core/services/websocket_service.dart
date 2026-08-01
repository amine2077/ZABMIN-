import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/system_metrics.dart';

const int _kMaxRetriesBeforeCheck = 3;

@visibleForTesting
int backoffDelay(int attempt) {
  if (attempt <= 0) return 1;
  final delay = min(10.0, pow(2, attempt - 1).toDouble());
  final jitter = Random().nextDouble() * 0.5;
  return (delay + jitter).round();
}

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  SystemMetrics? _latest;
  final List<SystemMetrics> _history = [];
  String _connectionStatus = 'disconnected';
  String? _agentError;
  int _connectAttempts = 0;
  bool _receivedFirstMessage = false;
  final ValueNotifier<SystemMetrics?> metricsNotifier = ValueNotifier(null);

  int _nextRequestId = 1;
  final Map<int, Completer<List<Map<String, dynamic>>>> _pendingConnections =
      {};
  final Map<int, Completer<Map<String, dynamic>>> _pendingKillByPid = {};
  final Map<int, int> _killPidToRid = {};
  final Map<int, Completer<Map<String, dynamic>>> _pendingPriority = {};
  final Map<int, int> _priorityPidToRid = {};

  SystemMetrics? get latest => _latest;
  List<SystemMetrics> get history => List.unmodifiable(_history);
  String get connectionStatus => _connectionStatus;
  String? get agentError => _agentError;

  final ValueNotifier<List<ProcessInfo>> processesNotifier = ValueNotifier(
    const [],
  );
  List<ProcessInfo> _lastProcesses = const [];
  int _lastProcessTimestamp = 0;

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
    _receivedFirstMessage = false;
    notifyListeners();
    _waitForRuntimeAndConnect();
  }

  Future<Map<String, dynamic>?> _readRuntimeFile() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) return null;

    final file = File('$localAppData\\Zabmin\\runtime.json');
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _waitForRuntimeAndConnect() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));

    Map<String, dynamic>? runtimeData;
    while (DateTime.now().isBefore(deadline)) {
      runtimeData = await _readRuntimeFile();
      if (runtimeData != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (runtimeData == null) {
      final statusError = _checkAgentStatusFile();
      _agentError = statusError ?? 'Agent failed to start within 5 seconds';
      notifyListeners();
      return;
    }

    final port = runtimeData['port'] as int;
    final token = runtimeData['token'] as String;
    _doConnect(port, token);
  }

  void _doConnect(int port, String token) {
    try {
      final uri = Uri(
        scheme: 'ws',
        host: '127.0.0.1',
        port: port,
        path: '/',
        queryParameters: {'token': token},
      );
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (dynamic data) {
          _connectionStatus = 'connected';
          _connectAttempts = 0;
          _agentError = null;
          _receivedFirstMessage = true;
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final msgType = parsed['type'] as String?;
            final requestId = parsed['request_id'] as int?;

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
              final rid = parsed['request_id'] as int?;
              final pid = parsed['pid'] as int?;
              Completer<Map<String, dynamic>>? c;
              if (rid != null && _pendingPriority.containsKey(rid)) {
                c = _pendingPriority.remove(rid);
              } else if (pid != null && _priorityPidToRid.containsKey(pid)) {
                final fallbackRid = _priorityPidToRid[pid];
                if (fallbackRid != null) {
                  c = _pendingPriority.remove(fallbackRid);
                }
              }
              if (c != null && !c.isCompleted) {
                c.complete(parsed);
              }
              return;
            }

            if (msgType == 'kill_result') {
              final rid = parsed['request_id'] as int?;
              final pid = parsed['pid'] as int?;
              Completer<Map<String, dynamic>>? c;
              if (rid != null && _pendingKillByPid.containsKey(rid)) {
                c = _pendingKillByPid.remove(rid);
              } else if (pid != null && _killPidToRid.containsKey(pid)) {
                final fallbackRid = _killPidToRid[pid];
                if (fallbackRid != null) {
                  c = _pendingKillByPid.remove(fallbackRid);
                }
              }
              if (c != null && !c.isCompleted) {
                c.complete(parsed);
              }
              return;
            }

            // Unknown typed message — ignore, don't try to parse as metrics
            if (msgType != null) return;

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
            _maybeUpdateProcesses(metrics);
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
    _pendingKillByPid[rid] = completer;
    _killPidToRid[pid] = rid;
    sendMessage(
      jsonEncode({'type': 'kill_process', 'pid': pid, 'request_id': rid}),
    );
    Future.delayed(const Duration(seconds: 5), () {
      final c = _pendingKillByPid.remove(rid);
      _killPidToRid.remove(pid);
      if (c != null && !c.isCompleted) {
        c.complete({'success': false, 'error': 'Timeout'});
      }
    });
  }

  Future<Map<String, dynamic>> waitForKillResult(int pid) {
    final rid = _killPidToRid[pid];
    if (rid != null) {
      final completer = _pendingKillByPid[rid];
      if (completer != null) {
        return completer.future;
      }
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

  void _maybeUpdateProcesses(SystemMetrics metrics) {
    final procs = metrics.processes;
    if (procs.isEmpty && _lastProcesses.isEmpty) return;
    if (metrics.timestamp == _lastProcessTimestamp &&
        identical(procs, _lastProcesses)) {
      return;
    }
    if (_processSignature(procs) == _processSignature(_lastProcesses)) {
      _lastProcessTimestamp = metrics.timestamp;
      return;
    }
    _lastProcessTimestamp = metrics.timestamp;
    _lastProcesses = procs;
    processesNotifier.value = List<ProcessInfo>.unmodifiable(procs);
  }

  List<String> _processSignature(List<ProcessInfo> procs) {
    return [
      for (final p in procs)
        '${p.pid}|${p.name}|${p.status}|${p.memoryMb.toStringAsFixed(0)}|'
            '${p.cpuPercent.toStringAsFixed(1)}|${p.connections}',
    ];
  }

  void setPriority(int pid, int priority) {
    final rid = _allocRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingPriority[rid] = completer;
    _priorityPidToRid[pid] = rid;
    sendMessage(
      jsonEncode({
        'type': 'set_priority',
        'pid': pid,
        'priority': priority,
        'request_id': rid,
      }),
    );
    Future.delayed(const Duration(seconds: 5), () {
      final c = _pendingPriority.remove(rid);
      _priorityPidToRid.remove(pid);
      if (c != null && !c.isCompleted) {
        c.complete({'success': false, 'error': 'Timeout'});
      }
    });
  }

  Future<Map<String, dynamic>> fetchPriority(int pid) {
    final rid = _allocRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingPriority[rid] = completer;
    _priorityPidToRid[pid] = rid;
    sendMessage(
      jsonEncode({'type': 'get_priority', 'pid': pid, 'request_id': rid}),
    );
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingPriority.remove(rid);
        _priorityPidToRid.remove(pid);
        return {'priority': null, 'error': 'Timeout'};
      },
    );
  }

  Future<Map<String, dynamic>> waitForPriorityResult(int pid) {
    final rid = _priorityPidToRid[pid];
    if (rid != null) {
      final completer = _pendingPriority[rid];
      if (completer != null) {
        return completer.future;
      }
    }
    return Future.value({'success': false, 'error': 'No pending op'});
  }

  void _failAllPending() {
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
    _killPidToRid.clear();
    for (final entry in _pendingPriority.entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete({'priority': null, 'error': 'Disconnected'});
      }
    }
    _pendingPriority.clear();
    _priorityPidToRid.clear();
  }

  void _handleDisconnect() {
    _connectionStatus = 'disconnected';

    final closeCode = _channel?.closeCode;

    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _failAllPending();
    notifyListeners();

    if (closeCode == 4401) {
      _agentError =
          'Connection rejected: invalid or missing authentication token.';
      notifyListeners();
      return;
    }

    if (closeCode == 4403) {
      _agentError =
          'Connection rejected: forbidden (Host/Origin check failed).';
      notifyListeners();
      return;
    }

    if (!_receivedFirstMessage && closeCode == null) {
      _agentError =
          'Agent connection closed before any data was received. '
          'The agent may have crashed or rejected the connection.';
      notifyListeners();
      return;
    }

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
    final delay = backoffDelay(_connectAttempts);
    _connectionStatus = 'reconnecting';
    notifyListeners();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
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
    processesNotifier.dispose();
    super.dispose();
  }
}
