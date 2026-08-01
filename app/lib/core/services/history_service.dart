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

/// Single source of truth for persistent history.
///
/// Tiered schema (SQLite `PRAGMA user_version` 2):
///  - [HistoryService.rawTable]: 5-second samples, kept 7 days
///  - [HistoryService.m1Table]: 1-minute aggregates, kept 90 days
///  - [HistoryService.h1Table]: hourly aggregates, kept 2 years
///  - [HistoryService.d1Table]: daily aggregates, kept 5 years
///
/// Aggregation runs on app start and hourly while the app is open; rows are
/// pruned per retention tier. Chart/export queries pick the coarsest table
/// that still satisfies the requested range.
class HistoryService extends ChangeNotifier {
  static const rawTable = 'metrics_raw';
  static const m1Table = 'metrics_1m';
  static const h1Table = 'metrics_1h';
  static const d1Table = 'metrics_1d';

  static const _legacyTable = 'snapshots';
  static const int _schemaVersion = 2;

  /// Fields that are aggregated into every tier (min/avg/max + count).
  static const aggFields = [
    'cpu_pct',
    'ram_used_gb',
    'ram_pct',
    'disk_used_gb',
    'disk_pct',
    'net_recv_mbs',
    'net_sent_mbs',
    'gpu_pct',
    'gpu_vram_pct',
    'gpu_temp_c',
  ];

  /// Raw-only fields (total capacities, ~constant; not aggregated).
  static const _rawOnlyFields = ['ram_total_gb', 'disk_total_gb'];

  static const _rawColumns = ['ts', ...aggFields, ..._rawOnlyFields];

  static const _second = 1;
  static const _minute = 60 * _second;
  static const _hour = 60 * _minute;
  static const _day = 24 * _hour;

  static const int rawRetentionDays = 7;
  static const int m1RetentionDays = 90;
  static const int h1RetentionDays = 2 * 365;
  static const int d1RetentionDays = 5 * 365;

  static const int _writeIntervalSeconds = 5;

  final int writeIntervalSeconds;
  final bool autoMaintenance;

  Database? _db;
  Timer? _writeTimer;
  Timer? _maintenanceTimer;
  MetricSnapshot? _pending;
  bool _initialized = false;
  bool _maintenanceRunning = false;

  HistoryService({
    this.writeIntervalSeconds = _writeIntervalSeconds,
    this.autoMaintenance = true,
  });

  Future<void> init({String? databasePath}) async {
    if (_initialized) return;
    try {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      String path;
      if (databasePath != null) {
        path = databasePath;
      } else {
        final dir = await getApplicationSupportDirectory();
        path = '${dir.path}${Platform.pathSeparator}zabmin_history.db';
      }
      _db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _schemaVersion,
          onCreate: (db, version) async {
            await _createRawTable(db);
            await _createAggTables(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _migrateToV2(db);
            }
          },
        ),
      );
      _initialized = true;
      unawaited(maintenanceNow());
      if (autoMaintenance) {
        _maintenanceTimer ??= Timer.periodic(
          const Duration(hours: 1),
          (_) => unawaited(maintenanceNow()),
        );
      }
    } catch (e) {
      debugPrint('[HistoryService] init failed: $e');
    }
  }

  Future<void> _migrateToV2(DatabaseExecutor db) async {
    final legacy = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [_legacyTable],
    );
    if (legacy.isNotEmpty) {
      await db.execute('ALTER TABLE $_legacyTable RENAME TO $rawTable');
    } else {
      await _createRawTable(db);
    }
    await _createAggTables(db);
    debugPrint('[HistoryService] migrated schema to v$_schemaVersion');
  }

  Future<void> _createRawTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $rawTable (
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
      'CREATE INDEX IF NOT EXISTS idx_${rawTable}_ts ON $rawTable(ts)',
    );
  }

  Future<void> _createAggTables(DatabaseExecutor db) async {
    for (final name in [m1Table, h1Table, d1Table]) {
      final cols = StringBuffer(
        'bucket INTEGER PRIMARY KEY, '
        'sample_count INTEGER NOT NULL',
      );
      for (final f in aggFields) {
        cols.write(', $f REAL, ${f}_min REAL, ${f}_max REAL');
      }
      await db.execute('CREATE TABLE IF NOT EXISTS $name ($cols)');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${name}_bucket ON $name(bucket)',
      );
    }
  }

  /// Aggregates raw -> 1m -> 1h -> 1d and prunes expired rows.
  /// Idempotent (INSERT OR REPLACE), safe to run repeatedly.
  @visibleForTesting
  Future<void> maintenanceNow() async {
    final db = _db;
    if (db == null || _maintenanceRunning) return;
    _maintenanceRunning = true;
    try {
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _aggregate(db, rawTable, m1Table, _minute, nowTs);
      await _aggregate(db, m1Table, h1Table, _hour, nowTs);
      await _aggregate(db, h1Table, d1Table, _day, nowTs);
      await _prune(db, rawTable, rawRetentionDays, 'ts');
      await _prune(db, m1Table, m1RetentionDays, 'bucket');
      await _prune(db, h1Table, h1RetentionDays, 'bucket');
      await _prune(db, d1Table, d1RetentionDays, 'bucket');
    } catch (e) {
      debugPrint('[HistoryService] maintenance failed: $e');
    } finally {
      _maintenanceRunning = false;
    }
  }

  Future<void> _aggregate(
    Database db,
    String src,
    String dst,
    int bucketSeconds,
    int nowTs,
  ) async {
    final srcTsCol = src == rawTable ? 'ts' : 'bucket';
    final fromAgg = src != rawTable;
    final divisor = bucketSeconds;
    // bucket start = (ts / bucketSeconds) * bucketSeconds, floor division
    final srcBucket = '($srcTsCol / $divisor) * $divisor';
    final currentBucket = (nowTs ~/ divisor) * divisor;

    final sel = StringBuffer(
      'SELECT $srcBucket AS bucket, '
      'COUNT(*) AS sample_count',
    );
    for (final f in aggFields) {
      // From raw, min/max are the sample values themselves; from an
      // aggregate table, min/max come from the tracked extremes.
      final minExpr = fromAgg ? 'MIN(${f}_min)' : 'MIN($f)';
      final maxExpr = fromAgg ? 'MAX(${f}_max)' : 'MAX($f)';
      sel.write(', AVG($f), $minExpr, $maxExpr');
    }
    sel.write(
      ' FROM $src WHERE $srcTsCol < ? AND $srcTsCol >= ? GROUP BY $srcBucket',
    );

    final colList = StringBuffer('bucket, sample_count');
    for (final f in aggFields) {
      colList.write(', $f, ${f}_min, ${f}_max');
    }

    final retentionDays = switch (src) {
      rawTable => rawRetentionDays,
      m1Table => m1RetentionDays,
      h1Table => h1RetentionDays,
      _ => d1RetentionDays,
    };
    final lowerBound = nowTs - retentionDays * _day;

    await db.rawInsert('INSERT OR REPLACE INTO $dst ($colList) $sel', [
      currentBucket,
      lowerBound,
    ]);
  }

  Future<void> _prune(
    Database db,
    String table,
    int retentionDays,
    String tsCol,
  ) async {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - retentionDays * _day;
    try {
      await db.delete(table, where: '$tsCol < ?', whereArgs: [cutoff]);
    } catch (e) {
      debugPrint('[HistoryService] prune $table failed: $e');
    }
  }

  void record(SystemMetrics metrics) {
    _pending = MetricSnapshot.fromMetrics(metrics);
    _writeTimer ??= Timer.periodic(
      Duration(seconds: writeIntervalSeconds),
      (_) => unawaited(_flushPending()),
    );
  }

  Future<void> _flushPending() async {
    final db = _db;
    final snap = _pending;
    if (db == null || snap == null) return;
    try {
      await db.insert(rawTable, snap.toRow());
    } catch (e) {
      debugPrint('[HistoryService] insert failed: $e');
    }
  }

  @visibleForTesting
  Future<void> flushPendingNow() => _flushPending();

  /// Chooses the coarsest aggregate table that still satisfies the range,
  /// so long ranges stay small and fast.
  @visibleForTesting
  String tableForRange(int fromTs, int toTs) {
    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final span = toTs - fromTs;
    if (span <= _hour) {
      // Raw covers the last 7 days; older short windows fall back to 1m.
      if (fromTs >= nowTs - rawRetentionDays * _day) return rawTable;
      return m1Table;
    }
    if (span <= rawRetentionDays * _day) return m1Table;
    if (span <= h1RetentionDays * _day) return h1Table;
    return d1Table;
  }

  Future<List<MetricSnapshot>> fetchRange({
    DateTime? from,
    DateTime? to,
    int? maxPoints,
  }) async {
    final db = _db;
    if (db == null) return const [];
    final now = DateTime.now();
    final fromTs =
        (from ?? now.subtract(Duration(days: rawRetentionDays)))
            .toUtc()
            .millisecondsSinceEpoch ~/
        1000;
    final toTs = (to ?? now).toUtc().millisecondsSinceEpoch ~/ 1000;
    final table = tableForRange(fromTs, toTs);
    try {
      final rows = await _queryTable(db, table, fromTs, toTs);
      final selected = maxPoints != null ? downsample(rows, maxPoints) : rows;
      return selected.map(MetricSnapshot.fromRow).toList();
    } catch (e) {
      debugPrint('[HistoryService] fetchRange failed: $e');
      return const [];
    }
  }

  Future<List<Map<String, Object?>>> _queryTable(
    Database db,
    String table,
    int fromTs,
    int toTs,
  ) async {
    if (table == rawTable) {
      return db.query(
        rawTable,
        columns: _rawColumns,
        where: 'ts >= ? AND ts <= ?',
        whereArgs: [fromTs, toTs],
        orderBy: 'ts ASC',
      );
    }
    final colList =
        'bucket AS ts, sample_count, '
        '${aggFields.map((f) => '$f, ${f}_min, ${f}_max').join(', ')}';
    return db.rawQuery(
      'SELECT $colList FROM $table '
      'WHERE bucket >= ? AND bucket <= ? ORDER BY bucket ASC',
      [fromTs, toTs],
    );
  }

  /// Uniform decimation: keep the first and last row, sample every Nth in
  /// between, so chart point counts stay bounded.
  @visibleForTesting
  List<Map<String, Object?>> downsample(
    List<Map<String, Object?>> rows,
    int maxPoints,
  ) {
    if (rows.length <= maxPoints) return rows;
    final step = (rows.length / maxPoints).ceil();
    final out = <Map<String, Object?>>[];
    for (var i = 0; i < rows.length; i += step) {
      out.add(rows[i]);
    }
    if (!identical(out.last, rows.last)) out.add(rows.last);
    return out;
  }

  Future<MetricSummary> summarize({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = _db;
    if (db == null) {
      return _emptySummary(from, to);
    }
    final fromTs = from.toUtc().millisecondsSinceEpoch ~/ 1000;
    final toTs = to.toUtc().millisecondsSinceEpoch ~/ 1000;
    final table = tableForRange(fromTs, toTs);
    final tsCol = table == rawTable ? 'ts' : 'bucket';
    try {
      final sel = StringBuffer(
        table == rawTable
            ? 'COUNT(*) AS sample_count'
            : 'COALESCE(SUM(sample_count), 0) AS sample_count',
      );
      for (final f in aggFields) {
        // Aggregate tables store avg in the plain column and the tracked
        // min/max in the *_min/*_max columns.
        final minExpr = table == rawTable ? 'MIN($f)' : 'MIN(${f}_min)';
        final maxExpr = table == rawTable ? 'MAX($f)' : 'MAX(${f}_max)';
        sel.write(
          ', AVG($f) AS ${f}_avg, $minExpr AS ${f}_min, $maxExpr AS ${f}_max',
        );
      }
      final rows = await db.rawQuery(
        'SELECT $sel FROM $table WHERE $tsCol >= ? AND $tsCol <= ?',
        [fromTs, toTs],
      );
      final row = rows.isNotEmpty ? rows.first : null;
      final samples = (row?['sample_count'] as num?)?.toInt() ?? 0;
      if (samples == 0) return _emptySummary(from, to);
      final stats = <String, MetricStat>{};
      for (final f in aggFields) {
        stats[f] = MetricStat(
          (row!['${f}_min'] as num?)?.toDouble() ?? 0.0,
          (row['${f}_avg'] as num?)?.toDouble() ?? 0.0,
          (row['${f}_max'] as num?)?.toDouble() ?? 0.0,
        );
      }
      return MetricSummary(
        from: fromTs,
        to: toTs,
        samples: samples,
        stats: stats,
      );
    } catch (e) {
      debugPrint('[HistoryService] summarize failed: $e');
      return _emptySummary(from, to);
    }
  }

  MetricSummary _emptySummary(DateTime from, DateTime to) => MetricSummary(
    from: from.toUtc().millisecondsSinceEpoch ~/ 1000,
    to: to.toUtc().millisecondsSinceEpoch ~/ 1000,
    samples: 0,
    stats: const {},
  );

  @override
  void dispose() {
    _writeTimer?.cancel();
    _maintenanceTimer?.cancel();
    _db?.close();
    super.dispose();
  }
}
