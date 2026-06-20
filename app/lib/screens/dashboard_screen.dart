import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/nav_items.dart';
import '../core/services/websocket_service.dart';
import '../core/services/alerts_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/app_rail.dart';
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
                  onNavSelected:
                      (label) => setState(() => _selectedNav = label),
                  bottom: const _ConnectionBadge(compact: true),
                ),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildSidebar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 230,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ZColors.surfaceElevated.withValues(alpha: 0.92),
                ZColors.surface.withValues(alpha: 0.92),
              ],
            ),
            border: const Border(right: BorderSide(color: ZColors.hairline)),
          ),
          child: Column(
            children: [
              const _BrandHeader(),
              const SizedBox(height: 4),
              ...kNavItems.map((item) {
                final isSelected = item.label == _selectedNav;
                return _SidebarTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedNav = item.label),
                );
              }),
              const Spacer(),
              const _ConnectionBadge(compact: false),
              const SizedBox(height: 18),
            ],
          ),
        ),
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
        return const _DashboardHome();
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              gradient: const LinearGradient(colors: ZColors.gradientAccent),
              boxShadow: ZShadows.hairlineGlow(ZColors.accent),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZABMIN',
                style: ZText.section.copyWith(
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w800,
                  color: ZColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ZRadii.inner,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors:
                            item.gradient
                                .map((c) => c.withValues(alpha: 0.18))
                                .toList(),
                      )
                      : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 3,
                  height: 22,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: ZRadii.pill,
                    gradient:
                        isSelected
                            ? LinearGradient(colors: item.gradient)
                            : null,
                    color: isSelected ? null : ZColors.hairline,
                    boxShadow:
                        isSelected
                            ? ZShadows.hairlineGlow(item.gradient.last)
                            : null,
                  ),
                ),
                Icon(
                  item.icon,
                  size: 18,
                  color:
                      isSelected ? item.gradient.first : ZColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: ZText.body.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isSelected
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
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return Consumer2<WebSocketService, AlertsService>(
      builder: (context, wsService, alertsService, _) {
        final metrics = wsService.latest;
        final status = wsService.connectionStatus;

        if (metrics == null) {
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
        }

        final gpus = metrics.gpu;
        final gpuUtil = gpus.isNotEmpty ? gpus.first.utilizationPercent : 0.0;
        final gpuVramPercent = gpus.isNotEmpty ? gpus.first.vramPercent : 0.0;

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
                      ZColors.accent.withValues(alpha: 0.10),
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
                      ZColors.purple.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('System Overview', style: ZText.display),
                            const SizedBox(height: 6),
                            Text(
                              'Live telemetry from your Windows machine',
                              style: ZText.body.copyWith(
                                color: ZColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _TimestampChip(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  MetricGrid(
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
                        unit:
                            '/ ${metrics.memory.totalGb.toStringAsFixed(0)} GB',
                        percent: metrics.memory.percent,
                        icon: Icons.memory_rounded,
                        gradient: ZColors.gradientRam,
                      ),
                      MetricCard(
                        label: 'Disk',
                        value: metrics.disk.usedGb.toStringAsFixed(1),
                        unit: '/ ${metrics.disk.totalGb.toStringAsFixed(0)} GB',
                        percent: metrics.disk.percent,
                        icon: Icons.storage_rounded,
                        gradient: ZColors.gradientDisk,
                      ),
                      MetricCard(
                        label: 'Network',
                        value: metrics.network.recvMbS.toStringAsFixed(1),
                        unit: 'MB/s',
                        percent: (metrics.network.recvMbS +
                                metrics.network.sentMbS)
                            .clamp(0, 100),
                        icon: Icons.wifi_rounded,
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
                        MetricCard(
                          label: 'VRAM',
                          value: gpus.first.vramUsedMb.toStringAsFixed(0),
                          unit:
                              '/ ${gpus.first.vramTotalMb.toStringAsFixed(0)} MB',
                          percent: gpuVramPercent,
                          icon: Icons.layers_rounded,
                          gradient: ZColors.gradientRam,
                        ),
                        MetricCard(
                          label: 'GPU Temp',
                          value:
                              gpus.first.temperatureC > 0
                                  ? gpus.first.temperatureC.toStringAsFixed(0)
                                  : '—',
                          unit: gpus.first.temperatureC > 0 ? '°C' : '',
                          percent:
                              gpus.first.temperatureC > 0
                                  ? gpus.first.temperatureC.clamp(0, 100)
                                  : 0,
                          icon: Icons.thermostat_rounded,
                          gradient: ZColors.gradientDisk,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  MetricChart(
                    title: 'CPU Usage',
                    history: wsService.history,
                    accentGradient: ZColors.gradientCpu,
                    series: [
                      ChartSeries(
                        label: 'CPU',
                        gradient: ZColors.gradientCpu,
                        liveExtractor: (m) => m.cpu.percentTotal,
                        historyKey: 'cpu_percent',
                      ),
                    ],
                    showTooltip: true,
                  ),
                  const SizedBox(height: 24),
                  ProcessTable(processes: metrics.processes),
                ],
              ),
            ),
          ],
        );
      },
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
