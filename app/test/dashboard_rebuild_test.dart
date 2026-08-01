import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zabmin/core/models/system_metrics.dart';
import 'package:zabmin/core/services/history_service.dart';
import 'package:zabmin/core/services/websocket_service.dart';
import 'package:zabmin/screens/dashboard_screen.dart';

/// WebSocketService subclass that never touches runtime.json or opens a
/// WebSocket, so dashboard tests are hermetic.
class _FakeWebSocketService extends WebSocketService {
  String _status = 'connecting';

  @override
  String get connectionStatus => _status;

  @override
  void connect() {}

  void setStatus(String s) {
    _status = s;
    notifyListeners();
  }
}

class _BuildProbe extends StatelessWidget {
  const _BuildProbe({required this.onBuild, required this.child});
  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

SystemMetrics metricsAt(int ts, {double cpu = 10}) {
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

void main() {
  late _FakeWebSocketService ws;
  late HistoryService history;
  late int rootBuilds;

  Widget buildApp() {
    return _BuildProbe(
      onBuild: () => rootBuilds++,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<WebSocketService>.value(value: ws),
          ChangeNotifierProvider<HistoryService>.value(value: history),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    // Wide surface: exercises the sidebar layout (no compact rail badge).
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp());
  }

  /// The FlutterTest font is wider than the real Inter font, so the sidebar
  /// brand header and status pill overflow in tests only. Not app bugs.
  void suppressOverflowErrors(WidgetTester tester) {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is FlutterError &&
          details.exception.toString().contains('overflowed')) {
        return;
      }
      original?.call(details);
    };
  }

  setUp(() {
    ws = _FakeWebSocketService();
    history = HistoryService(autoMaintenance: false);
    rootBuilds = 0;
  });

  testWidgets('dashboard root does not rebuild on every metric tick', (
    tester,
  ) async {
    suppressOverflowErrors(tester);
    await pumpDashboard(tester);
    await tester.pump();
    expect(rootBuilds, 1);
    expect(find.text('Connecting to agent...'), findsOneWidget);

    // First live metrics arrive; the ValueListenableBuilder swaps the
    // loading state for the live dashboard without rebuilding the root.
    ws.metricsNotifier.value = metricsAt(1);
    await tester.pumpAndSettle();
    expect(find.text('10.0'), findsOneWidget); // CPU card value

    // Ten more ticks: only the ValueListenableBuilder subtree rebuilds,
    // the DashboardScreen root must not.
    for (var i = 0; i < 10; i++) {
      ws.metricsNotifier.value = metricsAt(i + 2, cpu: i.toDouble());
      await tester.pumpAndSettle();
    }
    expect(rootBuilds, 1);
    expect(find.text('9.0'), findsOneWidget); // latest CPU value shown
    expect(find.text('10.0'), findsNothing);
  });

  testWidgets('connection status updates the badge without a root rebuild', (
    tester,
  ) async {
    suppressOverflowErrors(tester);
    ws.metricsNotifier.value = metricsAt(1);
    await pumpDashboard(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reconnecting'), findsOneWidget);

    ws.setStatus('connected');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Agent Online'), findsOneWidget);
    expect(rootBuilds, 1);
  });

  testWidgets('process table follows its own notifier', (tester) async {
    suppressOverflowErrors(tester);
    ws.metricsNotifier.value = metricsAt(1);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();

    ws.processesNotifier.value = [
      ProcessInfo(
        pid: 100,
        name: 'test_explorer.exe',
        cpuPercent: 3.5,
        memoryMb: 120,
        status: 'running',
        connections: 0,
      ),
    ];
    await tester.pumpAndSettle();
    expect(find.text('test_explorer.exe'), findsOneWidget);
    expect(rootBuilds, 1);
  });
}
