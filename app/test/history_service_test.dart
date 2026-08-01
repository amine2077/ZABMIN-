import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zabmin/core/models/system_metrics.dart';
import 'package:zabmin/core/services/history_service.dart';

const rawTable = HistoryService.rawTable;
const m1Table = HistoryService.m1Table;
const h1Table = HistoryService.h1Table;
const d1Table = HistoryService.d1Table;

SystemMetrics metricsAt(int ts, {double cpu = 10, double ramPct = 20}) {
  return SystemMetrics(
    version: 3,
    timestamp: ts,
    cpu: CPUStats(
      percentTotal: cpu,
      percentPerCore: const [],
      freqMhz: 3000,
      coreCount: 8,
      threadCount: 16,
    ),
    memory: MemoryStats(
      totalGb: 32,
      usedGb: 8,
      percent: ramPct,
      availableGb: 24,
      cachedGb: 4,
      speedMhz: 3200,
    ),
    disk: DiskStats(
      totalGb: 512,
      usedGb: 256,
      percent: 50,
      readMbS: 1,
      writeMbS: 2,
      partitions: const [],
    ),
    network: NetworkStats(
      sentMbS: 0.5,
      recvMbS: 1.5,
      totalSentGb: 10,
      totalRecvGb: 20,
    ),
    processes: const [],
    gpu: const [],
  );
}

void main() {
  late Directory tempDir;
  late String dbPath;
  late HistoryService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zabmin_test');
    dbPath = '${tempDir.path}${Platform.pathSeparator}zabmin_history.db';
    service = HistoryService(autoMaintenance: false);
    await service.init(databasePath: dbPath);
    // Let the start-of-app maintenance kickoff settle so explicit
    // maintenanceNow() calls are deterministic.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() async {
    service.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<void> insertRaw(List<int> timestamps, {List<double>? cpus}) async {
    for (var i = 0; i < timestamps.length; i++) {
      service.record(metricsAt(timestamps[i], cpu: cpus?[i] ?? 10));
      await service.flushPendingNow();
    }
  }

  Future<Map<String, Object?>> queryOne(String sql, List<Object?> args) async {
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    try {
      final rows = await db.rawQuery(sql, args);
      return rows.isEmpty ? const {} : rows.first;
    } finally {
      await db.close();
    }
  }

  Future<int> countRows(String table, String where, List<Object?> args) async {
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM $table WHERE $where',
        args,
      );
      return (rows.first['n'] as int?) ?? 0;
    } finally {
      await db.close();
    }
  }

  group('schema and migration', () {
    test('fresh database creates all four tables', () async {
      final db = await databaseFactoryFfi.openDatabase(dbPath);
      try {
        final names = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name LIKE 'metrics%' ORDER BY name",
        );
        expect(
          names.map((r) => r['name']).toList(),
          containsAll([rawTable, m1Table, h1Table, d1Table]),
        );
      } finally {
        await db.close();
      }
    });

    test('v1 legacy snapshots table is renamed to metrics_raw', () async {
      final legacyPath =
          '${tempDir.path}${Platform.pathSeparator}legacy_history.db';
      // Recent timestamps so the migrated raw row is still queryable via
      // tableForRange (raw retention is 7 days).
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final legacyTs = nowTs - 3600;
      // Create a database with the old v1 schema (snapshots table).
      final db = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                cpu_pct REAL,
                ram_used_gb REAL,
                ram_total_gb REAL,
                ram_pct REAL,
                disk_used_gb REAL,
                disk_total_gb REAL,
                disk_pct REAL,
                net_recv_mbs REAL,
                net_sent_mbs REAL,
                gpu_pct REAL,
                gpu_vram_pct REAL,
                gpu_temp_c REAL
              )
            ''');
            await db.insert('snapshots', {
              'ts': legacyTs,
              'cpu_pct': 42.5,
              'ram_used_gb': 8.0,
              'ram_total_gb': 32.0,
              'ram_pct': 25.0,
              'disk_used_gb': 256.0,
              'disk_total_gb': 512.0,
              'disk_pct': 50.0,
              'net_recv_mbs': 1.0,
              'net_sent_mbs': 0.5,
              'gpu_pct': 10.0,
              'gpu_vram_pct': 5.0,
              'gpu_temp_c': 60.0,
            });
          },
        ),
      );
      await db.close();

      final migrated = HistoryService(autoMaintenance: false);
      await migrated.init(databasePath: legacyPath);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final rows = await migrated.fetchRange(
        from: DateTime.fromMillisecondsSinceEpoch((legacyTs - 60) * 1000),
        to: DateTime.fromMillisecondsSinceEpoch((legacyTs + 60) * 1000),
      );
      expect(rows.length, 1);
      expect(rows.first.cpuPct, 42.5);
      expect(rows.first.ts, legacyTs);
      migrated.dispose();
    });
  });

  group('recording', () {
    test('record + flush persists a snapshot to raw table', () async {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      service.record(metricsAt(ts, cpu: 33.3));
      await service.flushPendingNow();

      final rows = await service.fetchRange(
        from: DateTime.fromMillisecondsSinceEpoch((ts - 60) * 1000),
        to: DateTime.fromMillisecondsSinceEpoch((ts + 60) * 1000),
      );
      expect(rows.length, 1);
      expect(rows.first.cpuPct, closeTo(33.3, 0.001));
    });
  });

  group('aggregation', () {
    test('raw rows aggregate into metrics_1m with avg/min/max/count', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final minute = (now ~/ 60 - 5) * 60; // a complete minute, 5 min ago
      final tss = [for (var i = 0; i < 12; i++) minute + i * 5];
      await insertRaw(tss, cpus: [for (var i = 0; i < 12; i++) 10.0 + i]);

      await service.maintenanceNow();

      final row = await queryOne('SELECT * FROM $m1Table WHERE bucket = ?', [
        minute,
      ]);
      expect(row['sample_count'], 12);
      expect(row['cpu_pct'], closeTo(15.5, 0.001)); // avg of 10..21
      expect(row['cpu_pct_min'], 10.0);
      expect(row['cpu_pct_max'], 21.0);
    });

    test('current incomplete minute is not aggregated', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final currentMinute = (now ~/ 60) * 60;
      await insertRaw([currentMinute + 10, currentMinute + 20]);

      await service.maintenanceNow();

      final rows = await queryOne(
        'SELECT COUNT(*) AS n FROM $m1Table',
        const [],
      );
      expect(rows['n'], 0);
    });

    test('1m aggregates into 1h, then 1h into 1d', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Two minutes in two different complete hours, two days ago so the
      // daily aggregate is also produced.
      final dayStart = (now ~/ 86400 - 2) * 86400;
      final hourA = dayStart + 3600;
      final hourB = dayStart + 2 * 3600;
      await insertRaw([hourA + 60, hourA + 120, hourB + 60]);

      await service.maintenanceNow();

      final h1Row = await queryOne('SELECT * FROM $h1Table WHERE bucket = ?', [
        hourA,
      ]);
      expect(h1Row['sample_count'], 2);
      expect(h1Row['cpu_pct'], 10.0);
      expect(h1Row['cpu_pct_min'], 10.0);
      expect(h1Row['cpu_pct_max'], 10.0);

      final d1Row = await queryOne('SELECT * FROM $d1Table WHERE bucket = ?', [
        dayStart,
      ]);
      // d1 aggregates hourly rows: two complete hours -> sample_count 2.
      expect(d1Row['sample_count'], 2);
    });

    test('idempotent: running maintenance twice keeps single rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final minute = (now ~/ 60 - 5) * 60;
      await insertRaw([minute, minute + 5, minute + 10]);

      await service.maintenanceNow();
      await service.maintenanceNow();

      final rows = await queryOne(
        'SELECT COUNT(*) AS n FROM $m1Table',
        const [],
      );
      expect(rows['n'], 1);
    });
  });

  group('retention', () {
    test('raw rows older than 7 days are pruned and not aggregated', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final old = now - 8 * 86400;
      await insertRaw([old, old + 5]);

      await service.maintenanceNow();

      expect(await countRows(rawTable, 'ts = ? OR ts = ?', [old, old + 5]), 0);
      final m1 = await queryOne('SELECT COUNT(*) AS n FROM $m1Table', const []);
      expect(m1['n'], 0);
    });

    test('aggregate tables prune past their retention tiers', () async {
      // Build schema (setUp's service already did), inject rows directly
      // into the aggregate tables, then verify maintenance prunes each
      // tier at its own cutoff.
      // Build schema, then inject rows directly into the aggregate tables
      // and verify maintenance prunes each tier at its own cutoff.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final old1m = now - 100 * 86400; // beyond 90d
      final recent1m = now - 10 * 86400;
      final old1h = now - 3 * 365 * 86400; // beyond 2y
      final recent1h = now - 365 * 86400;
      final old1d = now - 6 * 365 * 86400; // beyond 5y
      final recent1d = now - 365 * 86400;

      final db = await databaseFactoryFfi.openDatabase(dbPath);
      for (final (table, bucket) in [
        (m1Table, old1m),
        (m1Table, recent1m),
        (h1Table, old1h),
        (h1Table, recent1h),
        (d1Table, old1d),
        (d1Table, recent1d),
      ]) {
        await db.rawInsert(
          'INSERT OR REPLACE INTO $table (bucket, sample_count, cpu_pct, '
          'cpu_pct_min, cpu_pct_max, ram_used_gb, ram_used_gb_min, '
          'ram_used_gb_max, ram_pct, ram_pct_min, ram_pct_max, disk_used_gb, '
          'disk_used_gb_min, disk_used_gb_max, disk_pct, disk_pct_min, '
          'disk_pct_max, net_recv_mbs, net_recv_mbs_min, net_recv_mbs_max, '
          'net_sent_mbs, net_sent_mbs_min, net_sent_mbs_max, gpu_pct, '
          'gpu_pct_min, gpu_pct_max, gpu_vram_pct, gpu_vram_pct_min, '
          'gpu_vram_pct_max, gpu_temp_c, gpu_temp_c_min, gpu_temp_c_max) '
          'VALUES (?, 1, 10, 10, 10, 8, 8, 8, 25, 25, 25, 256, 256, 256, '
          '50, 50, 50, 1, 1, 1, 0.5, 0.5, 0.5, 10, 10, 10, 5, 5, 5, 60, '
          '60, 60)',
          [bucket],
        );
      }
      await db.close();

      final svc = HistoryService(autoMaintenance: false);
      await svc.init(databasePath: dbPath);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await svc.maintenanceNow();
      svc.dispose();

      expect(await countRows(m1Table, 'bucket = ?', [old1m]), 0);
      expect(await countRows(m1Table, 'bucket = ?', [recent1m]), 1);
      expect(await countRows(h1Table, 'bucket = ?', [old1h]), 0);
      expect(await countRows(h1Table, 'bucket = ?', [recent1h]), 1);
      expect(await countRows(d1Table, 'bucket = ?', [old1d]), 0);
      expect(await countRows(d1Table, 'bucket = ?', [recent1d]), 1);
    });
  });

  group('table selection', () {
    test('short spans use raw, longer spans use coarser tables', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(service.tableForRange(now - 900, now), rawTable);
      expect(service.tableForRange(now - 3600, now), rawTable);
      expect(service.tableForRange(now - 6 * 3600, now), m1Table);
      expect(service.tableForRange(now - 7 * 86400, now), m1Table);
      expect(service.tableForRange(now - 30 * 86400, now), h1Table);
      expect(service.tableForRange(now - 2 * 365 * 86400, now), h1Table);
      expect(service.tableForRange(now - 3 * 365 * 86400, now), d1Table);
    });

    test('old short windows fall back to 1m when raw is pruned', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final from = now - 30 * 86400;
      expect(service.tableForRange(from, from + 900), m1Table);
    });

    test('fetchRange over 6h returns rows from the 1m table', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final minute = (now ~/ 60 - 60) * 60;
      await insertRaw([minute, minute + 5, minute + 10]);
      await service.maintenanceNow();

      final rows = await service.fetchRange(
        from: DateTime.fromMillisecondsSinceEpoch((now - 6 * 3600) * 1000),
        to: DateTime.fromMillisecondsSinceEpoch(now * 1000),
      );
      expect(rows.length, 1);
      expect(rows.first.cpuPct, closeTo(10, 0.001));
    });
  });

  group('downsampling', () {
    test('keeps rows when under the limit', () {
      final rows = [
        for (var i = 0; i < 50; i++) <String, Object?>{'ts': i},
      ];
      expect(service.downsample(rows, 400), same(rows));
    });

    test('bounds point count and keeps first and last', () {
      final rows = [
        for (var i = 0; i < 1000; i++) <String, Object?>{'ts': i},
      ];
      final out = service.downsample(rows, 100);
      expect(out.length, lessThanOrEqualTo(101));
      expect(out.length, greaterThan(50));
      expect(out.first['ts'], 0);
      expect(out.last['ts'], 999);
    });

    test('fetchRange applies maxPoints', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final minute = (now ~/ 60 - 30) * 60;
      final tss = [for (var i = 0; i < 300; i++) minute + i * 2];
      await insertRaw(tss);

      final rows = await service.fetchRange(
        from: DateTime.fromMillisecondsSinceEpoch((now - 3600) * 1000),
        to: DateTime.fromMillisecondsSinceEpoch(now * 1000),
        maxPoints: 50,
      );
      expect(rows.length, lessThanOrEqualTo(51));
    });
  });

  group('summarize', () {
    test('computes min/avg/max per field from SQL aggregates', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final minute = (now ~/ 60 - 5) * 60;
      final tss = [for (var i = 0; i < 12; i++) minute + i * 5];
      await insertRaw(tss, cpus: [for (var i = 0; i < 12; i++) 10.0 + i]);
      await service.maintenanceNow();

      final summary = await service.summarize(
        from: DateTime.fromMillisecondsSinceEpoch((now - 86400) * 1000),
        to: DateTime.fromMillisecondsSinceEpoch(now * 1000),
      );
      expect(summary.samples, 12);
      expect(summary.stats['cpu_pct']!.min, 10.0);
      expect(summary.stats['cpu_pct']!.avg, closeTo(15.5, 0.001));
      expect(summary.stats['cpu_pct']!.max, 21.0);
      expect(summary.stats['ram_pct']!.min, 20.0);
    });

    test('empty range returns zero summary', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final summary = await service.summarize(
        from: DateTime.fromMillisecondsSinceEpoch((now - 86400) * 1000),
        to: DateTime.fromMillisecondsSinceEpoch((now - 86300) * 1000),
      );
      expect(summary.samples, 0);
      expect(summary.stats, isEmpty);
    });
  });
}
