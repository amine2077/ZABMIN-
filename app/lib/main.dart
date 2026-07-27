import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/agent_process_manager.dart';
import 'core/services/websocket_service.dart';
import 'core/services/alerts_service.dart';
import 'core/services/history_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/zcolors.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/export_dialog.dart';

final AgentProcessManager _agentProcessManager = AgentProcessManager();

Future<void> _startAgent() async {
  try {
    final runtimeData = await _agentProcessManager.readRuntimeFile();
    final valid = await _agentProcessManager.isRuntimeValid(runtimeData);

    if (valid) {
      stdout.writeln('[Zabmin] Valid running agent found, reusing it');
      return;
    }

    if (runtimeData != null) {
      stdout.writeln('[Zabmin] Stale runtime.json detected, cleaning up');
    }

    await _agentProcessManager.deleteRuntimeFile();
    await _agentProcessManager.startAgent();
  } catch (e) {
    stderr.writeln('[Zabmin] Failed to start agent: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final historyService = HistoryService();
  await historyService.init();

  final settingsService = SettingsService();
  await settingsService.load();

  launchAtStartup.setup(
    appName: 'Zabmin',
    appPath: Platform.resolvedExecutable,
  );

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(720, 520),
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0xFF0D1117),
    title: 'Zabmin',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await _startAgent();

  await trayManager.setIcon('assets/tray_icon.png');
  await trayManager.setToolTip('Zabmin');
  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(label: 'Show Zabmin', key: 'show'),
        MenuItem.separator(),
        MenuItem(label: 'Exit', key: 'exit'),
      ],
    ),
  );

  await localNotifier.setup(
    appName: 'Zabmin',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(
    ZabminApp(historyService: historyService, settingsService: settingsService),
  );
}

class ZabminApp extends StatelessWidget {
  final HistoryService historyService;
  final SettingsService settingsService;

  const ZabminApp({
    super.key,
    required this.historyService,
    required this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketService()),
        ChangeNotifierProvider(
          create: (_) => AlertsService(settings: settingsService),
        ),
        ChangeNotifierProvider<HistoryService>.value(value: historyService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
      ],
      child: MaterialApp(
        title: 'Zabmin',
        debugShowCheckedModeBanner: false,
        theme: ZTheme.dark,
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

class _AppShellState extends State<AppShell> with WindowListener, TrayListener {
  bool _isMaximized = false;
  bool _forceClose = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initAlerts();
    _initTrayTooltip();
  }

  void _initTrayTooltip() {
    final ws = context.read<WebSocketService>();
    ws.metricsNotifier.addListener(() {
      final m = ws.metricsNotifier.value;
      if (m != null) {
        final cpu = m.cpu.percentTotal.toStringAsFixed(0);
        final ram = m.memory.percent.toStringAsFixed(0);
        trayManager.setToolTip('Zabmin — CPU: $cpu% | RAM: $ram%');
      }
    });
  }

  void _initAlerts() {
    final ws = context.read<WebSocketService>();
    final alerts = context.read<AlertsService>();
    final history = context.read<HistoryService>();
    ws.metricsNotifier.addListener(() {
      final m = ws.metricsNotifier.value;
      if (m != null) {
        alerts.onMetrics(m);
        history.record(m);
      }
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    trayManager.destroy();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!_forceClose) {
      final settings = context.read<SettingsService>();
      if (settings.minimizeToTray) {
        await windowManager.hide();
        return;
      }
    }
    await _killAgent();
    trayManager.destroy();
    windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit') {
      _forceClose = true;
      windowManager.close();
    }
  }

  Future<void> _killAgent() async {
    try {
      final runtimeData = await _agentProcessManager.readRuntimeFile();

      if (mounted) {
        try {
          final ws = context.read<WebSocketService>();
          if (ws.connectionStatus == 'connected') {
            await _agentProcessManager.stopAgent(
              runtimeData,
              (msg) => ws.sendMessage(msg),
            );
            return;
          }
        } catch (_) {}
      }

      await _agentProcessManager.stopAgent(runtimeData, (_) {});
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
                  final error = ws.agentError;
                  if (error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ZColors.red.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                Icons.warning_rounded,
                                size: 28,
                                color: ZColors.red,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Agent failed to start',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ZColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              error,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: ZColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => ws.retryConnection(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

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
        height: 38,
        decoration: const BoxDecoration(
          color: ZColors.surface,
          border: Border(bottom: BorderSide(color: ZColors.border, width: 1)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: ZColors.accent.withValues(alpha: 0.15),
                border: Border.all(
                  color: ZColors.accent.withValues(alpha: 0.35),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.monitor_heart_rounded,
                size: 11,
                color: ZColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ZABMIN',
              style: GoogleFonts.inter(
                fontSize: 11,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w800,
                color: ZColors.textSecondary,
              ),
            ),
            const Spacer(),
            _TitleBarButton(
              icon: Icons.download_rounded,
              tooltip: 'Export report',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const ExportDialog(),
                );
              },
            ),
            const SizedBox(
              width: 1,
              height: 20,
              child: ColoredBox(color: ZColors.border),
            ),
            _WindowButton(
              icon: Icons.remove_rounded,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: _isMaximized
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
              icon: Icons.close_rounded,
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
    final bgColor = _hovering
        ? (widget.isClose ? ZColors.red : ZColors.surface)
        : Colors.transparent;
    final iconColor = _hovering && widget.isClose
        ? Colors.white
        : ZColors.textSecondary;

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

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TitleBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 46,
            height: 36,
            color: _hovering ? ZColors.surface : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovering ? ZColors.accent : ZColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
