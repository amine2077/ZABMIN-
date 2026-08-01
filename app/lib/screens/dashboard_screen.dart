import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/nav_items.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/app_rail.dart';
import '../widgets/core_bar_grid.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/metric_grid.dart';
import '../widgets/metric_chart.dart';
import '../widgets/process_table.dart';
import 'processes_screen.dart';
import 'network_screen.dart';
import 'disk_screen.dart';
import 'ram_screen.dart';
import 'gpu_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedNav = 'Dashboard';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth >= 1100;
        return Row(
          children: [
            wide
                ? _buildSidebar()
                : AppRail(
                    selectedNav: _selectedNav,
                    onNavSelected: (label) =>
                        setState(() => _selectedNav = label),
                    bottom: const _ConnectionBadge(compact: true),
                  ),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        color: ZColors.surface,
        border: Border(right: BorderSide(color: ZColors.border, width: 1)),
      ),
      child: Column(
        children: [
          const _BrandHeader(),
          const Divider(color: ZColors.border, height: 1, thickness: 1),
          const SizedBox(height: 8),
          ...kNavItems.map((item) {
            final isSelected = item.label == _selectedNav;
            return _SidebarTile(
              item: item,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedNav = item.label),
            );
          }),
          const Spacer(),
          const Divider(color: ZColors.border, height: 1, thickness: 1),
          const _ConnectionBadge(compact: false),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedNav) {
      case 'Processes':
        return const ProcessesScreen();
      case 'Network':
        return const NetworkScreen();
      case 'Disk':
        return const DiskScreen();
      case 'RAM':
        return const RamScreen();
      case 'GPU':
        return const GpuScreen();
      case 'Settings':
        return const SettingsScreen();
      default:
        return _DashboardHome(
          onNavigate: (label) => setState(() => _selectedNav = label),
        );
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              color: ZColors.accent.withValues(alpha: 0.15),
              border: Border.all(color: ZColors.accent.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.monitor_heart_rounded,
              size: 16,
              color: ZColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZABMIN',
                style: ZText.section.copyWith(
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w800,
                  color: ZColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'System Monitor',
                style: ZText.micro.copyWith(color: ZColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ZRadii.inner,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              color: isSelected
                  ? item.gradient.first.withValues(alpha: 0.10)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(
                      color: item.gradient.first.withValues(alpha: 0.25),
                    )
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 17,
                  color: isSelected
                      ? item.gradient.first
                      : ZColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: ZText.body.copyWith(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? ZColors.textPrimary
                          : ZColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool compact;
  const _ConnectionBadge({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, ws, _) {
        final connected = ws.connectionStatus == 'connected';
        final accent = connected ? ZColors.green : ZColors.textTertiary;
        final label = connected ? 'Agent Online' : 'Reconnecting';
        if (compact) {
          return Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: ZRadii.inner,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ZColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  connected ? 'OK' : '...',
                  style: ZText.micro.copyWith(
                    color: ZColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: ZRadii.inner,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected ? ZColors.green : ZColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: ZText.caption.copyWith(
                    color: ZColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final ValueChanged<String>? onNavigate;
  const _DashboardHome({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final ws = context.read<WebSocketService>();
    return ValueListenableBuilder<SystemMetrics?>(
      valueListenable: ws.metricsNotifier,
      builder: (context, metrics, _) {
        if (metrics == null) {
          return Consumer<WebSocketService>(
            builder: (context, service, _) {
              final status = service.connectionStatus;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulseLoader(),
                    const SizedBox(height: 24),
                    Text(
                      status == 'connecting'
                          ? 'Connecting to agent...'
                          : 'Agent disconnected',
                      style: ZText.body.copyWith(color: ZColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status == 'connecting'
                          ? 'Establishing WebSocket on localhost:8765'
                          : 'Retrying in 3 seconds...',
                      style: ZText.caption,
                    ),
                  ],
                ),
              );
            },
          );
        }

        return Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZColors.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZColors.purple.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(child: _ExecutiveHeader(metrics: metrics)),
                  const SizedBox(height: 20),
                  RepaintBoundary(child: _MetricCardsSection(metrics: metrics)),
                  const SizedBox(height: 24),
                  _TelemetrySection(
                    ws: ws,
                    metrics: metrics,
                    onNavigate: onNavigate,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Metric cards rebuild only when live metrics change (1s ticks), isolated
/// from the rest of the dashboard.
class _MetricCardsSection extends StatelessWidget {
  final SystemMetrics metrics;
  const _MetricCardsSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final gpus = metrics.gpu;
    final gpuUtil = gpus.isNotEmpty ? gpus.first.utilizationPercent : 0.0;
    return MetricGrid(
      children: [
        MetricCard(
          label: 'CPU',
          value: metrics.cpu.percentTotal.toStringAsFixed(1),
          unit: '%',
          percent: metrics.cpu.percentTotal,
          icon: Icons.memory_rounded,
          gradient: ZColors.gradientCpu,
        ),
        MetricCard(
          label: 'Memory',
          value: metrics.memory.usedGb.toStringAsFixed(1),
          unit: '/ ${metrics.memory.totalGb.toStringAsFixed(0)} GB',
          percent: metrics.memory.percent,
          icon: Icons.pie_chart_rounded,
          gradient: ZColors.gradientRam,
        ),
        MetricCard(
          label: 'Disk I/O',
          value: (metrics.disk.readMbS + metrics.disk.writeMbS).toStringAsFixed(
            1,
          ),
          unit: 'MB/s',
          percent: metrics.disk.percent,
          icon: Icons.dns_rounded,
          gradient: ZColors.gradientDisk,
        ),
        MetricCard(
          label: 'Network',
          value: (metrics.network.recvMbS + metrics.network.sentMbS)
              .toStringAsFixed(1),
          unit: 'MB/s',
          percent: ((metrics.network.recvMbS + metrics.network.sentMbS) * 5)
              .clamp(0.0, 100.0),
          icon: Icons.sensors_rounded,
          gradient: ZColors.gradientNet,
        ),
        if (gpus.isNotEmpty) ...[
          MetricCard(
            label: 'GPU',
            value: gpuUtil.toStringAsFixed(1),
            unit: '%',
            percent: gpuUtil,
            icon: Icons.videogame_asset_rounded,
            gradient: ZColors.gradientGpu,
          ),
        ],
      ],
    );
  }
}

/// Charts and per-core bars follow live metrics; the process table listens
/// to its own notifier so it only rebuilds when process data changes.
class _TelemetrySection extends StatelessWidget {
  final WebSocketService ws;
  final SystemMetrics metrics;
  final ValueChanged<String>? onNavigate;

  const _TelemetrySection({
    required this.ws,
    required this.metrics,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth >= 950;
        final chart = RepaintBoundary(
          child: MetricChart(
            title: 'CPU & RAM Telemetry History',
            history: ws.history,
            accentGradient: ZColors.gradientCpu,
            series: [
              ChartSeries(
                label: 'CPU %',
                gradient: ZColors.gradientCpu,
                liveExtractor: (m) => m.cpu.percentTotal,
                snapshotExtractor: (s) => s.cpuPct,
              ),
              ChartSeries(
                label: 'RAM %',
                gradient: ZColors.gradientRam,
                liveExtractor: (m) => m.memory.percent,
                snapshotExtractor: (s) => s.ramPct,
              ),
            ],
            showTooltip: true,
          ),
        );
        final cores = RepaintBoundary(
          child: CoreBarGrid(percentPerCore: metrics.cpu.percentPerCore),
        );
        final processes = ValueListenableBuilder<List<ProcessInfo>>(
          valueListenable: ws.processesNotifier,
          builder: (context, procs, _) => ProcessTable(
            processes: procs,
            limit: 9,
            onViewAll: onNavigate != null
                ? () => onNavigate!('Processes')
                : null,
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [chart, const SizedBox(height: 20), cores],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: processes),
            ],
          );
        }
        return Column(
          children: [
            chart,
            const SizedBox(height: 20),
            cores,
            const SizedBox(height: 20),
            ValueListenableBuilder<List<ProcessInfo>>(
              valueListenable: ws.processesNotifier,
              builder: (context, procs, _) => ProcessTable(
                processes: procs,
                limit: 8,
                onViewAll: onNavigate != null
                    ? () => onNavigate!('Processes')
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExecutiveHeader extends StatelessWidget {
  final SystemMetrics metrics;
  const _ExecutiveHeader({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverable: false,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZColors.accent.withValues(alpha: 0.12),
              borderRadius: ZRadii.inner,
              border: Border.all(color: ZColors.accent.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.computer_rounded,
              color: ZColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'LOCAL WORKSTATION',
                      style: ZText.title.copyWith(
                        fontSize: 16,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ZColors.green.withValues(alpha: 0.12),
                        borderRadius: ZRadii.pill,
                        border: Border.all(
                          color: ZColors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: ZColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'ONLINE',
                            style: ZText.micro.copyWith(
                              color: ZColors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Windows System  •  ${metrics.cpu.coreCount} Cores / ${metrics.cpu.threadCount} Threads (${metrics.cpu.freqMhz} MHz)  •  ${metrics.memory.totalGb.toStringAsFixed(0)} GB RAM',
                  style: ZText.caption.copyWith(
                    color: ZColors.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const _TimestampChip(),
        ],
      ),
    );
  }
}

class _TimestampChip extends StatelessWidget {
  const _TimestampChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ZColors.surfaceElevated,
        borderRadius: ZRadii.pill,
        border: Border.all(color: ZColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: ZColors.textSecondary),
          const SizedBox(width: 6),
          Text('Live • 1s refresh', style: ZText.caption),
        ],
      ),
    );
  }
}

class _PulseLoader extends StatefulWidget {
  const _PulseLoader();

  @override
  State<_PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<_PulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) {
        final v = _ctl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ZColors.accent.withValues(alpha: 1 - v),
                  width: 2,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.4 + v * 0.8,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZColors.accent.withValues(alpha: 0.6 * (1 - v)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: ZColors.gradientAccent),
                boxShadow: ZShadows.glow(ZColors.accent),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bolt_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
