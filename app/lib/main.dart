import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/websocket_service.dart';
import 'core/services/alerts_service.dart';
import 'core/theme/zcolors.dart';
import 'screens/dashboard_screen.dart';

Future<void> _startAgent() async {
  try {
    final appDir = Directory(Platform.script.resolve('.').toFilePath());

    String? searchPath = appDir.path;
    String? agentDir;

    while (true) {
      final parent = Directory(searchPath!).parent.path;
      if (parent == searchPath) break;
      final segments = Uri.directory(searchPath).pathSegments;
      final dirName = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      if (dirName == 'app') {
        final candidate = Directory('$parent/agent');
        if (await candidate.exists()) {
          agentDir = candidate.path;
        }
        break;
      }
      searchPath = parent;
    }

    agentDir ??= Platform.script.resolve('../agent').toFilePath();

    final vbs = File('$agentDir/run_agent.vbs');
    if (await vbs.exists()) {
      await Process.start('wscript', [
        vbs.path,
      ], mode: ProcessStartMode.detached);
      stdout.writeln('[Zabmin] Agent started (hidden)');
    } else {
      stderr.writeln('[Zabmin] run_agent.vbs not found at ${vbs.path}');
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
  bool _isMaximized = false;

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
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await _killAgent();
    windowManager.destroy();
  }

  Future<void> _killAgent() async {
    try {
      final appDir = Directory(Platform.script.resolve('.').toFilePath());
      String searchPath = appDir.path;
      String? agentDir;
      while (true) {
        final parent = Directory(searchPath).parent.path;
        if (parent == searchPath) break;
        final segments = Uri.directory(searchPath).pathSegments;
        final dirName = segments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (dirName == 'app') {
          final candidate = Directory('$parent/agent');
          if (await candidate.exists()) agentDir = candidate.path;
          break;
        }
        searchPath = parent;
      }
      agentDir ??= Platform.script.resolve('../agent').toFilePath();

      int? pid;
      final pidFile = File('$agentDir/agent.pid');
      if (await pidFile.exists()) {
        final content = (await pidFile.readAsString()).trim();
        pid = int.tryParse(content);
      }

      if (pid != null) {
        try {
          final check = await Process.run('tasklist', [
            '/FI',
            'PID eq $pid',
            '/FO',
            'CSV',
            '/NH',
          ], runInShell: true);
          final stdout = (check.stdout as String).toLowerCase();
          if (stdout.contains('python')) {
            await Process.run('taskkill', ['/F', '/PID', '$pid']);
            return;
          }
        } catch (_) {}
      }

      final wmic = await Process.run('wmic', [
        'process',
        'where',
        "name='python.exe' and CommandLine like '%agent.py%'",
        'get',
        'ProcessId',
        '/format:list',
      ], runInShell: true);
      final out = (wmic.stdout as String);
      for (final line in out.split('\n')) {
        final m = RegExp(r'ProcessId=(\d+)').firstMatch(line);
        if (m != null) {
          final p = m.group(1)!;
          await Process.run('taskkill', ['/F', '/PID', p]);
        }
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.background,
      body: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: Consumer<WebSocketService>(
              builder: (context, ws, _) {
                final status = ws.connectionStatus;
                final hasData = ws.latest != null;

                if (status != 'connected' || !hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Zabmin',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: ZColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          color: ZColors.accent,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          status == 'connecting'
                              ? 'Connecting to agent...'
                              : 'Agent disconnected. Retrying in 3s...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: ZColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return const DashboardScreen();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 36,
        color: ZColors.background,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              'Zabmin',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ZColors.textSecondary,
              ),
            ),
            const Spacer(),
            _WindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon:
                  _isMaximized
                      ? Icons.filter_none_rounded
                      : Icons.crop_square_rounded,
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close,
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _hovering
            ? (widget.isClose ? ZColors.red : ZColors.surface)
            : Colors.transparent;
    final iconColor =
        _hovering && widget.isClose ? Colors.white : ZColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 36,
          color: bgColor,
          child: Icon(widget.icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}
