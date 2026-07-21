import 'package:flutter_test/flutter_test.dart';
import 'package:zabmin/core/models/system_metrics.dart';

Map<String, dynamic> _fullPayload() {
  return {
    'version': 3,
    'timestamp': 1718000000,
    'cpu': <String, dynamic>{
      'percent_total': 35.2,
      'percent_per_core': [30.1, 40.3, 25.0, 45.5],
      'freq_mhz': 3200,
      'core_count': 4,
      'thread_count': 8,
      'temperature_c': 68.5,
      'throttled': false,
    },
    'memory': <String, dynamic>{
      'total_gb': 16.0,
      'used_gb': 8.4,
      'percent': 52.3,
      'available_gb': 7.6,
      'cached_gb': 2.1,
      'speed_mhz': 3200,
    },
    'disk': <String, dynamic>{
      'total_gb': 500.0,
      'used_gb': 250.0,
      'percent': 50.0,
      'read_mb_s': 120.5,
      'write_mb_s': 80.3,
      'partitions': [
        <String, dynamic>{
          'device': 'C:\\',
          'mountpoint': 'C:\\',
          'label': 'OS',
          'filesystem': 'NTFS',
          'total_gb': 500.0,
          'used_gb': 250.0,
          'free_gb': 250.0,
          'percent': 50.0,
          'physical_drive': 'PhysicalDrive0',
          'read_mb_s': 60.0,
          'write_mb_s': 40.0,
        },
      ],
    },
    'network': <String, dynamic>{
      'sent_mb_s': 1.2,
      'recv_mb_s': 5.8,
      'total_sent_gb': 12.5,
      'total_recv_gb': 45.3,
    },
    'processes': [
      <String, dynamic>{
        'pid': 1234,
        'ppid': 4321,
        'name': 'chrome.exe',
        'cpu_percent': 5.2,
        'memory_mb': 312.4,
        'status': 'running',
        'connections': 12,
      },
      <String, dynamic>{
        'pid': 5678,
        'ppid': 1234,
        'name': 'python.exe',
        'cpu_percent': 2.1,
        'memory_mb': 150.0,
        'status': 'running',
        'connections': 3,
      },
    ],
    'battery': <String, dynamic>{
      'percent': 78.5,
      'power_plugged': false,
      'secs_left': 5400,
    },
    'gpu': [
      <String, dynamic>{
        'name': 'NVIDIA GeForce RTX 4090',
        'vram_total_mb': 24576.0,
        'vram_used_mb': 12288.0,
        'vram_percent': 50.0,
        'temperature_c': 65.0,
        'fan_percent': 40.0,
        'utilization_percent': 45.0,
        'driver_version': '535.98',
      },
    ],
  };
}

void main() {
  group('SystemMetrics.fromJson - full payload', () {
    late SystemMetrics metrics;

    setUp(() {
      metrics = SystemMetrics.fromJson(_fullPayload());
    });

    test('parses top-level fields', () {
      expect(metrics.version, 3);
      expect(metrics.timestamp, 1718000000);
    });

    test('parses CPU stats', () {
      expect(metrics.cpu.percentTotal, 35.2);
      expect(metrics.cpu.percentPerCore, [30.1, 40.3, 25.0, 45.5]);
      expect(metrics.cpu.freqMhz, 3200);
      expect(metrics.cpu.coreCount, 4);
      expect(metrics.cpu.threadCount, 8);
      expect(metrics.cpu.temperatureC, 68.5);
      expect(metrics.cpu.throttled, false);
    });

    test('parses Memory stats', () {
      expect(metrics.memory.totalGb, 16.0);
      expect(metrics.memory.usedGb, 8.4);
      expect(metrics.memory.percent, 52.3);
      expect(metrics.memory.availableGb, 7.6);
      expect(metrics.memory.cachedGb, 2.1);
      expect(metrics.memory.speedMhz, 3200);
    });

    test('parses Disk stats with partitions', () {
      expect(metrics.disk.totalGb, 500.0);
      expect(metrics.disk.usedGb, 250.0);
      expect(metrics.disk.percent, 50.0);
      expect(metrics.disk.readMbS, 120.5);
      expect(metrics.disk.writeMbS, 80.3);
      expect(metrics.disk.partitions.length, 1);
      expect(metrics.disk.partitions.first.device, 'C:\\');
      expect(metrics.disk.partitions.first.label, 'OS');
      expect(metrics.disk.partitions.first.filesystem, 'NTFS');
      expect(metrics.disk.partitions.first.physicalDrive, 'PhysicalDrive0');
    });

    test('parses Network stats', () {
      expect(metrics.network.sentMbS, 1.2);
      expect(metrics.network.recvMbS, 5.8);
      expect(metrics.network.totalSentGb, 12.5);
      expect(metrics.network.totalRecvGb, 45.3);
    });

    test('parses Process list', () {
      expect(metrics.processes.length, 2);
      expect(metrics.processes[0].pid, 1234);
      expect(metrics.processes[0].ppid, 4321);
      expect(metrics.processes[0].name, 'chrome.exe');
      expect(metrics.processes[0].cpuPercent, 5.2);
      expect(metrics.processes[0].memoryMb, 312.4);
      expect(metrics.processes[0].status, 'running');
      expect(metrics.processes[0].connections, 12);
      expect(metrics.processes[1].ppid, 1234);
    });

    test('parses GPU list', () {
      expect(metrics.gpu.length, 1);
      expect(metrics.gpu[0].name, 'NVIDIA GeForce RTX 4090');
      expect(metrics.gpu[0].vramTotalMb, 24576.0);
      expect(metrics.gpu[0].vramUsedMb, 12288.0);
      expect(metrics.gpu[0].vramPercent, 50.0);
      expect(metrics.gpu[0].temperatureC, 65.0);
      expect(metrics.gpu[0].fanPercent, 40.0);
      expect(metrics.gpu[0].utilizationPercent, 45.0);
      expect(metrics.gpu[0].driverVersion, '535.98');
    });

    test('parses Battery stats when present', () {
      expect(metrics.battery, isNotNull);
      expect(metrics.battery!.percent, 78.5);
      expect(metrics.battery!.powerPlugged, false);
      expect(metrics.battery!.secsLeft, 5400);
    });
  });

  group('SystemMetrics.fromJson - partial/malformed payload', () {
    test('returns defaults for empty json', () {
      final metrics = SystemMetrics.fromJson(<String, dynamic>{});
      expect(metrics.version, 0);
      expect(metrics.timestamp, 0);
      expect(metrics.cpu.percentTotal, 0.0);
      expect(metrics.cpu.percentPerCore, []);
      expect(metrics.cpu.freqMhz, 0);
      expect(metrics.cpu.coreCount, 0);
      expect(metrics.memory.totalGb, 0.0);
      expect(metrics.memory.usedGb, 0.0);
      expect(metrics.disk.totalGb, 0.0);
      expect(metrics.disk.partitions, []);
      expect(metrics.network.sentMbS, 0.0);
      expect(metrics.processes, []);
      expect(metrics.gpu, []);
    });

    test('handles null values gracefully', () {
      final metrics = SystemMetrics.fromJson(<String, dynamic>{
        'version': null,
        'cpu': null,
        'memory': null,
        'disk': null,
        'network': null,
        'processes': null,
        'gpu': null,
      });
      expect(metrics.version, 0);
      expect(metrics.cpu.percentTotal, 0.0);
    });

    test('handles missing fields within nested objects', () {
      final metrics = SystemMetrics.fromJson(<String, dynamic>{
        'version': 2,
        'cpu': <String, dynamic>{'percent_total': 50.0},
        'memory': <String, dynamic>{},
        'disk': <String, dynamic>{},
        'network': <String, dynamic>{},
      });
      expect(metrics.version, 2);
      expect(metrics.cpu.percentTotal, 50.0);
      expect(metrics.cpu.percentPerCore, []);
      expect(metrics.cpu.freqMhz, 0);
      expect(metrics.memory.totalGb, 0.0);
      expect(metrics.disk.totalGb, 0.0);
      expect(metrics.network.sentMbS, 0.0);
      expect(metrics.processes, []);
      expect(metrics.gpu, []);
    });

    test('handles partial process entry', () {
      final metrics = SystemMetrics.fromJson(<String, dynamic>{
        'version': 1,
        'cpu': <String, dynamic>{},
        'memory': <String, dynamic>{},
        'disk': <String, dynamic>{},
        'network': <String, dynamic>{},
        'processes': [
          <String, dynamic>{'pid': 999},
        ],
        'gpu': <dynamic>[],
      });
      expect(metrics.processes.length, 1);
      expect(metrics.processes[0].pid, 999);
      expect(metrics.processes[0].name, '');
      expect(metrics.processes[0].cpuPercent, 0.0);
      expect(metrics.processes[0].status, 'unknown');
    });

    test('handles partial gpu entry', () {
      final metrics = SystemMetrics.fromJson(<String, dynamic>{
        'version': 1,
        'cpu': <String, dynamic>{},
        'memory': <String, dynamic>{},
        'disk': <String, dynamic>{},
        'network': <String, dynamic>{},
        'processes': <dynamic>[],
        'gpu': [
          <String, dynamic>{'name': 'Test GPU'},
        ],
      });
      expect(metrics.gpu.length, 1);
      expect(metrics.gpu[0].name, 'Test GPU');
      expect(metrics.gpu[0].vramTotalMb, 0.0);
      expect(metrics.gpu[0].driverVersion, '');
    });

    test('battery is null when not in payload', () {
      final payload = <String, dynamic>{
        'version': 2,
        'cpu': <String, dynamic>{},
        'memory': <String, dynamic>{},
        'disk': <String, dynamic>{},
        'network': <String, dynamic>{},
      };
      final metrics = SystemMetrics.fromJson(payload);
      expect(metrics.battery, isNull);
    });

    test('missing processes field defaults to empty list', () {
      final metrics = SystemMetrics.fromJson(<String, dynamic>{
        'version': 1,
        'cpu': <String, dynamic>{},
        'memory': <String, dynamic>{},
        'disk': <String, dynamic>{},
        'network': <String, dynamic>{},
        'gpu': <dynamic>[],
      });
      expect(metrics.processes, []);
    });
  });

  group('Protocol version constant', () {
    test('kZabminProtocolVersion is 3', () {
      expect(kZabminProtocolVersion, 3);
    });
  });
}
