import 'package:flutter/foundation.dart';

import '../models/system_metrics.dart';

class Alert {
  final String id;
  final String message;
  final String severity; // 'critical', 'warning', 'info'
  final DateTime createdAt;
  bool read;

  Alert({
    required this.id,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.read = false,
  });
}

class AlertsService extends ChangeNotifier {
  final List<Alert> _alerts = [];
  bool _panelVisible = false;

  // Cooldown tracking
  DateTime? _lastCpuAlertTime;
  DateTime? _lastRamAlertTime;
  DateTime? _lastDiskAlertTime;
  DateTime? _lastNetAlertTime;

  // CPU high counter (needs 30 consecutive seconds)
  int _cpuHighConsecutiveCount = 0;

  List<Alert> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => _alerts.where((a) => !a.read).length;
  final ValueNotifier<bool> panelVisibleNotifier = ValueNotifier<bool>(false);

  bool get panelVisible => _panelVisible;

  void togglePanel() {
    _panelVisible = !_panelVisible;
    if (_panelVisible) {
      for (final alert in _alerts) {
        alert.read = true;
      }
    }
    panelVisibleNotifier.value = _panelVisible;
    notifyListeners();
  }

  void onMetrics(SystemMetrics metrics) {
    final now = DateTime.now();

    _checkCpuHigh(metrics.cpu, now);
    _checkRamHigh(metrics.memory, now);
    _checkDiskFull(metrics.disk, now);
    _checkNetSpike(metrics.network, now);
  }

  void _checkCpuHigh(CPUStats cpu, DateTime now) {
    if (cpu.percentTotal > 85) {
      _cpuHighConsecutiveCount++;
      if (_cpuHighConsecutiveCount >= 30) {
        if (_lastCpuAlertTime == null) {
          _addAlert(
            message: 'CPU usage is critically high (${cpu.percentTotal.toStringAsFixed(1)}%) for 30+ seconds',
            severity: 'critical',
          );
          _lastCpuAlertTime = now;
        }
      }
    } else {
      _cpuHighConsecutiveCount = 0;
      _lastCpuAlertTime = null;
    }
  }

  void _checkRamHigh(MemoryStats memory, DateTime now) {
    if (memory.percent > 90) {
      if (_lastRamAlertTime == null || now.difference(_lastRamAlertTime!).inSeconds >= 60) {
        _addAlert(
          message: 'RAM usage is high at ${memory.percent.toStringAsFixed(1)}%',
          severity: 'warning',
        );
        _lastRamAlertTime = now;
      }
    }
  }

  void _checkDiskFull(DiskStats disk, DateTime now) {
    if (disk.percent > 95) {
      if (_lastDiskAlertTime == null || now.difference(_lastDiskAlertTime!).inSeconds >= 60) {
        _addAlert(
          message: 'Disk space is critically low (${disk.percent.toStringAsFixed(1)}% used)',
          severity: 'critical',
        );
        _lastDiskAlertTime = now;
      }
    }
  }

  void _checkNetSpike(NetworkStats network, DateTime now) {
    if (network.recvMbS > 10) {
      if (_lastNetAlertTime == null || now.difference(_lastNetAlertTime!).inSeconds >= 60) {
        _addAlert(
          message: 'Network download spike detected (${network.recvMbS.toStringAsFixed(1)} MB/s)',
          severity: 'info',
        );
        _lastNetAlertTime = now;
      }
    }
  }

  void _addAlert({required String message, required String severity}) {
    final alert = Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      severity: severity,
      createdAt: DateTime.now(),
    );
    _alerts.insert(0, alert);
    notifyListeners();
  }

  void clearAll() {
    _alerts.clear();
    notifyListeners();
  }
}
