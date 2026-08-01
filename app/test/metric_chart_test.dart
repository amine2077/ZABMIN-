import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zabmin/core/models/system_metrics.dart';
import 'package:zabmin/core/services/history_service.dart';
import 'package:zabmin/core/theme/zcolors.dart';
import 'package:zabmin/widgets/metric_chart.dart';

SystemMetrics liveMetrics(int ts, {double cpu = 10}) {
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
      percent: 25,
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

MetricSnapshot snapshot(int i) => MetricSnapshot(
  ts: 1700000000 + i * 60,
  cpuPct: 10.0 + i,
  ramUsedGb: 8,
  ramTotalGb: 32,
  ramPct: 25,
  diskUsedGb: 256,
  diskTotalGb: 512,
  diskPct: 50,
  netRecvMbS: 1,
  netSentMbS: 0.5,
  gpuPct: 10,
  gpuVramPct: 5,
  gpuTempC: 60,
);

class _FakeHistoryService extends HistoryService {
  _FakeHistoryService(this.rows);
  final List<MetricSnapshot> rows;
  int fetchCalls = 0;

  @override
  Future<List<MetricSnapshot>> fetchRange({
    DateTime? from,
    DateTime? to,
    int? maxPoints,
  }) async {
    fetchCalls++;
    return rows;
  }
}

Widget buildChart({
  required List<SystemMetrics> history,
  required HistoryService historyService,
}) {
  return ChangeNotifierProvider<HistoryService>.value(
    value: historyService,
    child: MaterialApp(
      home: Scaffold(
        body: MetricChart(
          title: 'CPU',
          history: history,
          accentGradient: ZColors.gradientCpu,
          series: [
            ChartSeries(
              label: 'CPU %',
              gradient: ZColors.gradientCpu,
              liveExtractor: (m) => m.cpu.percentTotal,
              snapshotExtractor: (s) => s.cpuPct,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('live range tracks the rolling history buffer', (tester) async {
    final fake = _FakeHistoryService([]);
    await tester.pumpWidget(
      buildChart(
        history: [liveMetrics(1), liveMetrics(2), liveMetrics(3)],
        historyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.spots.length, 3);

    // A live tick pushes a new sample in; the chart follows.
    await tester.pumpWidget(
      buildChart(
        history: [
          liveMetrics(1),
          liveMetrics(2),
          liveMetrics(3),
          liveMetrics(4),
        ],
        historyService: fake,
      ),
    );
    await tester.pumpAndSettle();
    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.spots.length, 4);
  });

  testWidgets('historical range loads from HistoryService and is cached', (
    tester,
  ) async {
    final fake = _FakeHistoryService([
      for (var i = 0; i < 120; i++) snapshot(i),
    ]);
    await tester.pumpWidget(
      buildChart(history: [liveMetrics(1)], historyService: fake),
    );
    await tester.pumpAndSettle();

    // Switch to 15m: fetches from HistoryService.
    await tester.tap(find.text('15m'));
    await tester.pumpAndSettle();
    expect(fake.fetchCalls, 1);
    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.spots.length, 120);

    // Live ticks keep flowing into the parent, but the historical chart
    // must not rebuild or refetch.
    final before = chart;
    await tester.pumpWidget(
      buildChart(
        history: [liveMetrics(2), liveMetrics(3), liveMetrics(4)],
        historyService: fake,
      ),
    );
    await tester.pumpAndSettle();
    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(identical(before, chart), isTrue, reason: 'chart should be cached');
    expect(fake.fetchCalls, 1, reason: 'no refetch on live ticks');
  });
}
