import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/websocket_service.dart';
import 'core/services/alerts_service.dart';
import 'screens/dashboard_screen.dart';

Process? _agentProcess;

Future<void> _startAgent() async {
  try {
    final appDir = Directory(Platform.script.resolve('.').toFilePath());

    String? searchPath = appDir.path;
    String? agentPath;

    while (true) {
      final parent = Directory(searchPath!).parent.path;
      if (parent == searchPath) break;
      final segments = Uri.directory(searchPath).pathSegments;
      final dirName = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      if (dirName == 'app') {
        final candidate = File('$parent/agent/agent.py');
        if (await candidate.exists()) {
          agentPath = candidate.path;
        }
        break;
      }
      searchPath = parent;
    }

    agentPath ??= Platform.script.resolve('../agent/agent.py').toFilePath();

    final agentFile = File(agentPath);
    if (await agentFile.exists()) {
      final venvPython = File('${agentFile.parent.path}/venv/Scripts/python.exe');
      String pythonCmd;
      List<String> args;

      if (await venvPython.exists()) {
        pythonCmd = venvPython.path;
        args = [agentFile.path];
      } else {
        pythonCmd = 'py';
        args = [agentFile.path];
      }

      _agentProcess = await Process.start(
        pythonCmd,
        args,
        workingDirectory: agentFile.parent.path,
        mode: ProcessStartMode.detached,
      );
      stdout.writeln('[Zabmin] Agent started: $pythonCmd');
    } else {
      stderr.writeln('[Zabmin] Agent not found at $agentPath');
    }
  } catch (e) {
    stderr.writeln('[Zabmin] Failed to start agent: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0xFF0D1117),
    title: 'Zabmin',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await _startAgent();

  runApp(const ZabminApp());
}

class ZabminApp extends StatelessWidget {
  const ZabminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketService()),
        ChangeNotifierProvider(create: (_) => AlertsService()),
      ],
      child: MaterialApp(
        title: 'Zabmin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF58A6FF),
            surface: const Color(0xFF161B22),
            secondary: const Color(0xFF8B949E),
          ),
          useMaterial3: true,
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initAlerts();
  }

  void _initAlerts() {
    final ws = context.read<WebSocketService>();
    final alerts = context.read<AlertsService>();
    ws.metricsNotifier.addListener(() {
      final m = ws.metricsNotifier.value;
      if (m != null) {
        alerts.onMetrics(m);
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _agentProcess?.kill();
    super.dispose();
  }

  @override
  void onWindowClose() {
    _agentProcess?.kill();
    windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen();
  }
}
