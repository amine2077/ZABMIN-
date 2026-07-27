import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class AgentProcessManager {
  String? _agentDir;

  AgentProcessManager() {
    _findAgentDir();
  }

  Future<Map<String, dynamic>?> readRuntimeFile() async {
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

  Future<bool> isRuntimeValid(Map<String, dynamic>? data) async {
    if (data == null) return false;
    final pid = data['pid'];
    final port = data['port'];
    final token = data['token'];
    if (pid is! int || pid <= 0) return false;
    if (port is! int || port <= 0 || port > 65535) return false;
    if (token is! String || token.length < 8) return false;
    if (!await _isPidAlive(pid)) return false;
    if (!await _isZabminAgentProcess(pid)) return false;
    return true;
  }

  Future<bool> isPidZabminAgent(int pid) async {
    return _isZabminAgentProcess(pid);
  }

  Future<bool> _isPidAlive(int pid) async {
    try {
      final result = await Process.run('tasklist', [
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ], runInShell: true);
      return (result.stdout as String).toLowerCase().contains('"$pid"');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isZabminAgentProcess(int pid) async {
    try {
      final result = await Process.run('tasklist', [
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ], runInShell: true);
      final stdout = (result.stdout as String).toLowerCase();
      if (stdout.contains('python')) return true;
    } catch (_) {}

    try {
      final result = await Process.run('wmic', [
        'process',
        'where',
        'ProcessId=$pid',
        'get',
        'Name,CommandLine',
        '/format:csv',
      ], runInShell: true);
      final output = (result.stdout as String).toLowerCase();
      return output.contains('python') &&
          (output.contains('agent.py') || output.contains('zabmin-agent'));
    } catch (_) {
      return false;
    }
  }

  Future<bool> startAgent() async {
    _findAgentDir();
    try {
      if (_agentDir == null) return false;
      final vbs = File('$_agentDir\\run_agent.vbs');
      if (await vbs.exists()) {
        await Process.start('wscript', [
          vbs.path,
        ], mode: ProcessStartMode.detached);
        debugPrint('[Zabmin] Agent started (hidden)');
        return true;
      } else {
        debugPrint('[Zabmin] run_agent.vbs not found at ${vbs.path}');
        return false;
      }
    } catch (e) {
      debugPrint('[Zabmin] Failed to start agent: $e');
      return false;
    }
  }

  Future<bool> stopAgent(
    Map<String, dynamic>? runtimeData,
    void Function(String message) sendMessage,
  ) async {
    if (runtimeData == null) {
      await deleteRuntimeFile();
      return false;
    }
    final pid = runtimeData['pid'] as int?;
    if (pid == null) {
      await deleteRuntimeFile();
      return false;
    }

    try {
      final pidFile = _agentDir != null ? File('$_agentDir/agent.pid') : null;
      if (pidFile != null && await pidFile.exists()) {
        try {
          sendMessage(jsonEncode({'type': 'shutdown'}));
          for (int i = 0; i < 20; i++) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (!await pidFile.exists()) {
              await deleteRuntimeFile();
              return true;
            }
          }
        } catch (_) {}
      }

      if (!await _isPidAlive(pid)) {
        await deleteRuntimeFile();
        return true;
      }

      if (await _isZabminAgentProcess(pid)) {
        await Process.run('taskkill', ['/F', '/PID', '$pid']);
        await deleteRuntimeFile();
        return true;
      }
      debugPrint('[Zabmin] Skipped kill: PID $pid is not a Zabmin agent');
      return false;
    } catch (e) {
      debugPrint('[Zabmin] Failed to stop agent: $e');
      return false;
    }
  }

  Future<bool> deleteRuntimeFile() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null) return false;
    try {
      final file = File('$localAppData\\Zabmin\\runtime.json');
      if (await file.exists()) {
        await file.delete();
        debugPrint('[Zabmin] Deleted runtime.json');
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _findAgentDir() {
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
          if (candidate.existsSync()) {
            _agentDir = candidate.path;
          }
          break;
        }
        searchPath = parent;
      }
    } catch (_) {}
  }
}
