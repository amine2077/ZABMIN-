import 'dart:convert';
import 'dart:typed_data';

import 'history_service.dart';

enum ReportFormat { csv, json }

class ReportExporter {
  static const _columns = [
    'ts',
    'cpu_pct',
    'ram_pct',
    'ram_used_gb',
    'ram_total_gb',
    'disk_pct',
    'disk_used_gb',
    'disk_total_gb',
    'net_recv_mbs',
    'net_sent_mbs',
    'gpu_pct',
    'gpu_vram_pct',
    'gpu_temp_c',
  ];

  static Uint8List export({
    required List<MetricSnapshot> rows,
    required MetricSummary summary,
    required ReportFormat format,
  }) {
    switch (format) {
      case ReportFormat.csv:
        return _toCsv(rows);
      case ReportFormat.json:
        return _toJson(rows, summary);
    }
  }

  static Uint8List _toCsv(List<MetricSnapshot> rows) {
    final buf = StringBuffer();
    buf.writeln(_columns.join(','));
    for (final r in rows) {
      buf.writeln(
        [
          r.ts,
          r.cpuPct.toStringAsFixed(2),
          r.ramPct.toStringAsFixed(2),
          r.ramUsedGb.toStringAsFixed(2),
          r.ramTotalGb.toStringAsFixed(2),
          r.diskPct.toStringAsFixed(2),
          r.diskUsedGb.toStringAsFixed(2),
          r.diskTotalGb.toStringAsFixed(2),
          r.netRecvMbS.toStringAsFixed(3),
          r.netSentMbS.toStringAsFixed(3),
          r.gpuPct.toStringAsFixed(2),
          r.gpuVramPct.toStringAsFixed(2),
          r.gpuTempC.toStringAsFixed(1),
        ].join(','),
      );
    }
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  static Uint8List _toJson(List<MetricSnapshot> rows, MetricSummary summary) {
    final payload = {
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'from_ts': summary.from,
      'to_ts': summary.to,
      'sample_count': summary.samples,
      'summary': {
        for (final e in summary.stats.entries) e.key: e.value.toJson(),
      },
      'rows': rows.map((r) => r.toRow()).toList(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    return Uint8List.fromList(utf8.encode(encoder.convert(payload)));
  }

  static String suggestedFilename(ReportFormat fmt) {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final ext = fmt == ReportFormat.csv ? 'csv' : 'json';
    return 'zabmin-report-$stamp.$ext';
  }
}
