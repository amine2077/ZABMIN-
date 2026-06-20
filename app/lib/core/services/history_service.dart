import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/system_metrics.dart';

class MetricSnapshot {
  final int ts; // unix seconds
  final double cpuPct;
  final double ramUsedGb;
  final double ramTotalGb;
  final double ramPct;
  final double diskUsedGb;
  final double diskTotalGb;
  final double diskPct;
  final double netRecvMbS;
  final double netSentMbS;
  final double gpuPct;
  final double gpuVramPct;
  final double gpuTempC;

  MetricSnapshot({
    required this.ts,
    required this.cpuPct,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.ramPct,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.diskPct,
    required this.netRecvMbS,
    required this.netSentMbS,
    required this.gpuPct,
    required this.gpuVramPct,
    required this.gpuTempC,
  });

  factory MetricSnapshot.fromMetrics(SystemMetrics m) {
    final gpu = m.gpu.isNotEmpty ? m.gpu.first : null;
    return MetricSnapshot(
      ts: m.timestamp > 0
          ? m.timestamp
          : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      cpuPct: m.cpu.percentTotal,
      ramUsedGb: m.memory.usedGb,
      ramTotalGb: m.memory.totalGb,
      ramPct: m.memory.percent,
      diskUsedGb: m.disk.usedGb,
      diskTotalGb: m.disk.totalGb,
      diskPct: m.disk.percent,
      netRecvMbS: m.network.recvMbS,
      netSentMbS: m.network.sentMbS,
      gpuPct: gpu?.utilizationPercent ?? 0.0,
      gpuVramPct: gpu?.vramPercent ?? 0.0,
      gpuTempC: gpu?.temperatureC ?? 0.0,
    );
  }

  Map<String, Object?> toRow() => {
    'ts': ts,
    'cpu_pct': cpuPct,
    'ram_used_gb': ramUsedGb,
    'ram_total_gb': ramTotalGb,
    'ram_pct': ramPct,
    'disk_used_gb': diskUsedGb,
    'disk_total_gb': diskTotalGb,
    'disk_pct': diskPct,
    'net_recv_mbs': netRecvMbS,
    'net_sent_mbs': netSentMbS,
    'gpu_pct': gpuPct,
    'gpu_vram_pct': gpuVramPct,
    'gpu_temp_c': gpuTempC,
  };

  factory MetricSnapshot.fromRow(Map<String, Object?> r) => MetricSnapshot(
    ts: (r['ts'] as int?) ?? 0,
    cpuPct: (r['cpu_pct'] as num?)?.toDouble() ?? 0.0,
    ramUsedGb: (r['ram_used_gb'] as num?)?.toDouble() ?? 0.0,
    ramTotalGb: (r['ram_total_gb'] as num?)?.toDouble() ?? 0.0,
    ramPct: (r['ram_pct'] as num?)?.toDouble() ?? 0.0,
    diskUsedGb: (r['disk_used_gb'] as num?)?.toDouble() ?? 0.0,
    diskTotalGb: (r['disk_total_gb'] as num?)?.toDouble() ?? 0.0,
    diskPct: (r['disk_pct'] as num?)?.toDouble() ?? 0.0,
    netRecvMbS: (r['net_recv_mbs'] as num?)?.toDouble() ?? 0.0,
    netSentMbS: (r['net_sent_mbs'] as num?)?.toDouble() ?? 0.0,
    gpuPct: (r['gpu_pct'] as num?)?.toDouble() ?? 0.0,
    gpuVramPct: (r['gpu_vram_pct'] as num?)?.toDouble() ?? 0.0,
    gpuTempC: (r['gpu_temp_c'] as num?)?.toDouble() ?? 0.0,
  );
}

class MetricSummary {
  final int from;
  final int to;
  final int samples;
  final Map<String, MetricStat> stats; // key -> min/avg/max

  MetricSummary({
    required this.from,
    required this.to,
    required this.samples,
    required this.stats,
  });
}

class MetricStat {
  final double min;
  final double avg;
  final double max;
  MetricStat(this.min, this.avg, this.max);

  Map<String, double> toJson() => {'min': min, 'avg': avg, 'max': max};
}

class HistoryService extends ChangeNotifier {
  Database? _db;
  Timer? _pruneTimer;
  Timer? _writeTimer;
  MetricSnapshot? _pending;
  bool _initialized = false;

  static const _tableName = 'snapshots';
  static const int _retentionSeconds = 5 * 365 * 24 * 3600;
  static const int _writeIntervalSeconds = 5;

  Future<void> init() async {
    if (_initialized) return;
    try {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final dir = await getApplicationSupportDirectory();
      final path = '${dir.path}${Platform.pathSeparator}zabmin_history.db';
      _db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS $_tableName (
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
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_snapshots_ts ON $_tableName(ts)',
            );
          },
        ),
      );
      await _pruneOld();
      _initialized = true;
    } catch (e) {
      debugPrint('[HistoryService] init failed: $e');
    }
  }

  Future<void> _pruneOld() async {
    final db = _db;
    if (db == null) return;
    final cutoff =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - _retentionSeconds;
    try {
      await db.delete(_tableName, where: 'ts < ?', whereArgs: [cutoff]);
    } catch (e) {
      debugPrint('[HistoryService] prune failed: $e');
    }
  }

  void record(SystemMetrics metrics) {
    _pending = MetricSnapshot.fromMetrics(metrics);
    _writeTimer ??= Timer.periodic(
      const Duration(seconds: _writeIntervalSeconds),
      (_) => _flushPending(),
    );
    _pruneTimer ??= Timer.periodic(
      const Duration(hours: 1),
      (_) => _pruneOld(),
    );
  }

  Future<void> _flushPending() async {
    final db = _db;
    final snap = _pending;
    if (db == null || snap == null) return;
    try {
      await db.insert(_tableName, snap.toRow());
    } catch (e) {
      debugPrint('[HistoryService] insert failed: $e');
    }
  }

  Future<List<MetricSnapshot>> fetchRange({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = _db;
    if (db == null) return const [];
    final now = DateTime.now();
    final fromTs =
        (from ?? now.subtract(const Duration(days: 7)))
            .toUtc()
            .millisecondsSinceEpoch ~/
        1000;
    final toTs = (to ?? now).toUtc().millisecondsSinceEpoch ~/ 1000;
    try {
      final rows = await db.query(
        _tableName,
        where: 'ts >= ? AND ts <= ?',
        whereArgs: [fromTs, toTs],
        orderBy: 'ts ASC',
      );
      return rows.map(MetricSnapshot.fromRow).toList();
    } catch (e) {
      debugPrint('[HistoryService] fetchRange failed: $e');
      return const [];
    }
  }

  Future<MetricSummary> summarize({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await fetchRange(from: from, to: to);
    if (rows.isEmpty) {
      return MetricSummary(
        from: from.millisecondsSinceEpoch ~/ 1000,
        to: to.millisecondsSinceEpoch ~/ 1000,
        samples: 0,
        stats: const {},
      );
    }
    const keys = [
      'cpu_pct',
      'ram_pct',
      'ram_used_gb',
      'disk_pct',
      'disk_used_gb',
      'net_recv_mbs',
      'net_sent_mbs',
      'gpu_pct',
      'gpu_vram_pct',
      'gpu_temp_c',
    ];
    final stats = <String, MetricStat>{};
    double access(MetricSnapshot s, String k) {
      switch (k) {
        case 'cpu_pct':
          return s.cpuPct;
        case 'ram_pct':
          return s.ramPct;
        case 'ram_used_gb':
          return s.ramUsedGb;
        case 'disk_pct':
          return s.diskPct;
        case 'disk_used_gb':
          return s.diskUsedGb;
        case 'net_recv_mbs':
          return s.netRecvMbS;
        case 'net_sent_mbs':
          return s.netSentMbS;
        case 'gpu_pct':
          return s.gpuPct;
        case 'gpu_vram_pct':
          return s.gpuVramPct;
        case 'gpu_temp_c':
          return s.gpuTempC;
        default:
          return 0;
      }
    }

    for (final k in keys) {
      final vals = rows.map((r) => access(r, k)).toList();
      double mn = vals.first, mx = vals.first, sum = 0;
      for (final v in vals) {
        if (v < mn) mn = v;
        if (v > mx) mx = v;
        sum += v;
      }
      stats[k] = MetricStat(mn, sum / vals.length, mx);
    }
    return MetricSummary(
      from: rows.first.ts,
      to: rows.last.ts,
      samples: rows.length,
      stats: stats,
    );
  }

  @override
  void dispose() {
    _writeTimer?.cancel();
    _pruneTimer?.cancel();
    _db?.close();
    super.dispose();
  }
}
