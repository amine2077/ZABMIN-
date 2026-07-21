import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabmin/core/models/system_metrics.dart';
import 'package:zabmin/core/services/alerts_service.dart';
import 'package:zabmin/core/services/settings_service.dart';

SystemMetrics _makeMetrics({
  double cpuPercent = 10.0,
  double ramPercent = 10.0,
  double diskPercent = 10.0,
  double netRecvMbS = 1.0,
}) {
  return SystemMetrics(
    version: 1,
    timestamp: 0,
    cpu: CPUStats(
      percentTotal: cpuPercent,
      percentPerCore: [cpuPercent],
      freqMhz: 0,
      coreCount: 0,
      threadCount: 0,
    ),
    memory: MemoryStats(
      totalGb: 16,
      usedGb: 8,
      percent: ramPercent,
      availableGb: 8,
      cachedGb: 2,
      speedMhz: 0,
    ),
    disk: DiskStats(
      totalGb: 500,
      usedGb: 250,
      percent: diskPercent,
      readMbS: 0,
      writeMbS: 0,
      partitions: [],
    ),
    network: NetworkStats(
      sentMbS: 0,
      recvMbS: netRecvMbS,
      totalSentGb: 0,
      totalRecvGb: 0,
    ),
    processes: [],
    gpu: [],
  );
}

void main() {
  group('AlertsService - CPU high alert', () {
    test('does not fire below threshold', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(cpuPercent: 50.0));
      expect(service.unreadCount, 0);
    });

    test('fires after N consecutive high readings', () {
      final service = AlertsService();
      for (int i = 0; i < 29; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      expect(service.unreadCount, 0);

      service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      expect(service.unreadCount, 1);

      final alert = service.alerts.first;
      expect(alert.severity, 'critical');
      expect(alert.message, contains('CPU'));
    });

    test('resets counter when cpu drops below threshold', () {
      final service = AlertsService();
      for (int i = 0; i < 20; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      service.onMetrics(_makeMetrics(cpuPercent: 50.0));
      for (int i = 0; i < 29; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      expect(service.unreadCount, 0);

      service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      expect(service.unreadCount, 1);
    });

    test('does not fire again immediately after first alert', () {
      final service = AlertsService();
      for (int i = 0; i < 30; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      expect(service.unreadCount, 1);

      for (int i = 0; i < 30; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      expect(service.unreadCount, 1);
    });

    test('re-arms after cpu drops then goes high again', () {
      final service = AlertsService();
      for (int i = 0; i < 30; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      expect(service.unreadCount, 1);

      service.onMetrics(_makeMetrics(cpuPercent: 50.0));

      for (int i = 0; i < 30; i++) {
        service.onMetrics(_makeMetrics(cpuPercent: 90.0));
      }
      expect(service.unreadCount, 2);
    });
  });

  group('AlertsService - RAM high alert', () {
    test('does not fire below 90%', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(ramPercent: 80.0));
      expect(service.unreadCount, 0);
    });

    test('fires when above threshold', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(ramPercent: 95.0));
      expect(service.unreadCount, 1);
      expect(service.alerts.first.message, contains('RAM'));
    });

    test('respects 60s cooldown', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(ramPercent: 95.0));
      expect(service.unreadCount, 1);

      service.onMetrics(_makeMetrics(ramPercent: 95.0));
      expect(service.unreadCount, 1);
    });
  });

  group('AlertsService - Disk full alert', () {
    test('does not fire below 95%', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(diskPercent: 85.0));
      expect(service.unreadCount, 0);
    });

    test('fires when above threshold', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(diskPercent: 97.0));
      expect(service.unreadCount, 1);
      expect(service.alerts.first.message, contains('Disk'));
    });

    test('respects 60s cooldown', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(diskPercent: 97.0));
      expect(service.unreadCount, 1);

      service.onMetrics(_makeMetrics(diskPercent: 97.0));
      expect(service.unreadCount, 1);
    });
  });

  group('AlertsService - Network spike alert', () {
    test('does not fire below 10 MB/s', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(netRecvMbS: 5.0));
      expect(service.unreadCount, 0);
    });

    test('fires when above threshold', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(netRecvMbS: 50.0));
      expect(service.unreadCount, 1);
      expect(service.alerts.first.message, contains('Network'));
    });

    test('respects 60s cooldown', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(netRecvMbS: 50.0));
      expect(service.unreadCount, 1);

      service.onMetrics(_makeMetrics(netRecvMbS: 50.0));
      expect(service.unreadCount, 1);
    });
  });

  group('AlertsService - UI state', () {
    test('toggle panel marks all alerts as read', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(ramPercent: 95.0));
      expect(service.unreadCount, 1);
      expect(service.alerts.first.read, false);

      service.togglePanel();
      expect(service.alerts.first.read, true);
      expect(service.unreadCount, 0);
    });

    test('clearAll removes all alerts', () {
      final service = AlertsService();
      service.onMetrics(_makeMetrics(ramPercent: 95.0));
      service.onMetrics(_makeMetrics(diskPercent: 97.0));
      expect(service.alerts.length, 2);

      service.clearAll();
      expect(service.alerts.length, 0);
    });
  });

  group('AlertsService - custom thresholds from settings', () {
    test('uses SettingsService thresholds when provided', () async {
      SharedPreferences.setMockInitialValues({
        'cpu_threshold': 50.0,
        'cpu_consecutive_seconds': 3,
      });
      final settings = SettingsService();
      await settings.load();
      final service = AlertsService(settings: settings);

      service.onMetrics(_makeMetrics(cpuPercent: 60.0));
      expect(service.unreadCount, 0);

      service.onMetrics(_makeMetrics(cpuPercent: 60.0));
      expect(service.unreadCount, 0);

      service.onMetrics(_makeMetrics(cpuPercent: 60.0));
      expect(service.unreadCount, 1);
    });
  });
}
