import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../core/models/system_metrics.dart';
import '../widgets/animated_metric.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_shell.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  ProcessInfo? _selectedProcess;
  bool _panelVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPanel(ProcessInfo proc) {
    setState(() {
      _selectedProcess = proc;
      _panelVisible = true;
    });
  }

  void _closePanel() {
    setState(() {
      _panelVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(
            child: CircularProgressIndicator(color: ZColors.accent),
          );
        }

        final allProcesses = List<ProcessInfo>.from(metrics.processes)
          ..sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

        final filtered =
            _searchText.isEmpty
                ? allProcesses
                : allProcesses
                    .where(
                      (p) => p.name.toLowerCase().contains(
                        _searchText.toLowerCase(),
                      ),
                    )
                    .toList();

        return Stack(
          children: [
            _buildMainContent(filtered, allProcesses, metrics),
            if (_selectedProcess != null)
              _ConnectionPanel(
                process: _selectedProcess!,
                visible: _panelVisible,
                onClose: _closePanel,
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(
    List<ProcessInfo> filtered,
    List<ProcessInfo> all,
    SystemMetrics metrics,
  ) {
    return ScreenShell(
      title: 'Processes',
      subtitle: '${all.length} running processes',
      accentGradient: ZColors.gradientCpu,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryStat(
                label: 'CPU Load',
                value: metrics.cpu.percentTotal,
                decimals: 1,
                suffix: '%',
                gradient: ZColors.gradientCpu,
                icon: Icons.memory_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryStatString(
                label: 'Memory',
                value: '${metrics.memory.usedGb.toStringAsFixed(1)} GB',
                gradient: ZColors.gradientRam,
                icon: Icons.view_in_ar_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryStatString(
                label: 'Processes',
                value: all.length.toString(),
                gradient: ZColors.gradientGpu,
                icon: Icons.layers_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PremiumSearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchText = value),
          resultCount: filtered.length,
          totalCount: all.length,
        ),
        const SizedBox(height: 12),
        GlassCard(
          hoverable: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: ZRadii.pill,
                        gradient: const LinearGradient(
                          colors: ZColors.gradientCpu,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('All Processes', style: ZText.title),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ZColors.accent.withValues(alpha: 0.1),
                        borderRadius: ZRadii.pill,
                        border: Border.all(
                          color: ZColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: ZText.micro.copyWith(
                          color: ZColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: ZColors.hairline),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.50,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _ProcessRow(
                      proc: filtered[index],
                      index: index,
                      onTap: () => _openPanel(filtered[index]),
                      onKill: () => _confirmKill(context, filtered[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmKill(BuildContext context, ProcessInfo process) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ZColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: ZRadii.card,
              side: const BorderSide(color: ZColors.borderStrong),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: ZColors.red,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Kill ${process.name}?', style: ZText.title),
                ),
              ],
            ),
            content: Text(
              'This will terminate PID ${process.pid}.',
              style: ZText.body.copyWith(color: ZColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: ZText.body.copyWith(color: ZColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: ZRadii.inner),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _doKill(context, process);
                },
                child: const Text('Kill Process'),
              ),
            ],
          ),
    );
  }

  void _doKill(BuildContext context, ProcessInfo process) {
    final ws = context.read<WebSocketService>();
    ws.killProcess(process.pid);
    ws.waitForKillResult(process.pid).then((result) {
      if (!context.mounted) return;
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? '${process.name} terminated'
                      : 'Failed: ${result['error'] ?? 'unknown error'}',
                ),
              ),
            ],
          ),
          backgroundColor:
              success
                  ? ZColors.green.withValues(alpha: 0.95)
                  : ZColors.red.withValues(alpha: 0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: ZRadii.inner),
        ),
      );
    });
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final double value;
  final int decimals;
  final String suffix;
  final List<Color> gradient;
  final IconData icon;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.decimals,
    required this.suffix,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      glowColor: gradient.last,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              gradient: LinearGradient(
                colors: gradient.map((c) => c.withValues(alpha: 0.18)).toList(),
              ),
              border: Border.all(color: ZColors.border),
            ),
            child: Icon(icon, color: gradient.first, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: ZText.micro),
                const SizedBox(height: 4),
                AnimatedMetric(
                  value: value,
                  decimals: decimals,
                  suffix: suffix,
                  style: ZText.metricSm.copyWith(
                    color: gradient.first,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatString extends StatelessWidget {
  final String label;
  final String value;
  final List<Color> gradient;
  final IconData icon;

  const _SummaryStatString({
    required this.label,
    required this.value,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      glowColor: gradient.last,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              gradient: LinearGradient(
                colors: gradient.map((c) => c.withValues(alpha: 0.18)).toList(),
              ),
              border: Border.all(color: ZColors.border),
            ),
            child: Icon(icon, color: gradient.first, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: ZText.micro),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: ZText.metricSm.copyWith(
                    color: gradient.first,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int resultCount;
  final int totalCount;

  const _PremiumSearchField({
    required this.controller,
    required this.onChanged,
    required this.resultCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverable: false,
      padding: EdgeInsets.zero,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: ZColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: ZText.body,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Search processes...',
                  hintStyle: ZText.body.copyWith(color: ZColors.textTertiary),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ZColors.accent.withValues(alpha: 0.1),
                borderRadius: ZRadii.pill,
              ),
              child: Text(
                '$resultCount / $totalCount',
                style: ZText.micro.copyWith(
                  color: ZColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (controller.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  borderRadius: ZRadii.inner,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: ZColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProcessRow extends StatefulWidget {
  final ProcessInfo proc;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onKill;

  const _ProcessRow({
    required this.proc,
    required this.index,
    required this.onTap,
    required this.onKill,
  });

  @override
  State<_ProcessRow> createState() => _ProcessRowState();
}

class _ProcessRowState extends State<_ProcessRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final proc = widget.proc;
    final baseBg =
        widget.index.isEven
            ? ZColors.surface.withValues(alpha: 0.2)
            : ZColors.rowAlt.withValues(alpha: 0.4);
    final bg = _hovered ? ZColors.rowHover : baseBg;
    final cpuColor = ZColors.usageColor(proc.cpuPercent);
    final status = proc.status.toLowerCase();
    final statusColor =
        status == 'running'
            ? ZColors.green
            : status == 'sleeping'
            ? ZColors.accent
            : ZColors.textTertiary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: ZRadii.inner,
                          gradient: LinearGradient(
                            colors: [
                              ZColors.accent.withValues(alpha: 0.15),
                              ZColors.purple.withValues(alpha: 0.15),
                            ],
                          ),
                          border: Border.all(color: ZColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (proc.name.isEmpty ? '?' : proc.name.characters.first)
                              .toUpperCase(),
                          style: ZText.caption.copyWith(
                            color: ZColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          proc.name,
                          overflow: TextOverflow.ellipsis,
                          style: ZText.body.copyWith(
                            color: ZColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    proc.pid.toString(),
                    style: ZText.mono(
                      size: 11,
                      weight: FontWeight.w500,
                    ).copyWith(color: ZColors.textTertiary),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: ZColors.border.withValues(alpha: 0.4),
                            borderRadius: ZRadii.pill,
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: proc.cpuPercent / 100,
                              end: proc.cpuPercent / 100,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) {
                              return FractionallySizedBox(
                                widthFactor: v.clamp(0.0, 1.0),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: ZRadii.pill,
                                    color: cpuColor,
                                    boxShadow: ZShadows.hairlineGlow(cpuColor),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: proc.cpuPercent,
                            end: proc.cpuPercent,
                          ),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) {
                            return Text(
                              '${v.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: ZText.mono(
                                size: 11,
                                weight: FontWeight.w600,
                              ).copyWith(color: cpuColor),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${proc.memoryMb.toStringAsFixed(1)} MB',
                    textAlign: TextAlign.right,
                    style: ZText.mono(
                      size: 11,
                      weight: FontWeight.w500,
                    ).copyWith(color: ZColors.textTertiary),
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: ZRadii.pill,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              boxShadow: ZShadows.hairlineGlow(statusColor),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status.toUpperCase(),
                            style: ZText.micro.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '${proc.connections}',
                    textAlign: TextAlign.right,
                    style: ZText.mono(
                      size: 11,
                      weight: FontWeight.w500,
                    ).copyWith(color: ZColors.textTertiary),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onKill,
                        borderRadius: ZRadii.inner,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: ZRadii.inner,
                            color:
                                _hovered
                                    ? ZColors.red.withValues(alpha: 0.12)
                                    : Colors.transparent,
                            border: Border.all(
                              color:
                                  _hovered
                                      ? ZColors.red.withValues(alpha: 0.3)
                                      : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: _hovered ? ZColors.red : ZColors.textMuted,
                          ),
                        ),
                      ),
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

class _ConnectionPanel extends StatefulWidget {
  final ProcessInfo process;
  final bool visible;
  final VoidCallback onClose;

  const _ConnectionPanel({
    required this.process,
    required this.visible,
    required this.onClose,
  });

  @override
  State<_ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<_ConnectionPanel> {
  List<Map<String, dynamic>>? _connections;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  @override
  void didUpdateWidget(covariant _ConnectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.process.pid != widget.process.pid) {
      _fetchConnections();
    }
  }

  void _fetchConnections() async {
    setState(() {
      _loading = true;
      _connections = null;
    });
    final ws = context.read<WebSocketService>();
    final conns = await ws.fetchConnections(widget.process.pid);
    if (mounted) {
      setState(() {
        _connections = conns;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      right: widget.visible ? 0 : -400,
      top: 20,
      bottom: 20,
      width: 380,
      child: ClipRRect(
        borderRadius: ZRadii.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: ZColors.surfaceElevated.withValues(alpha: 0.95),
              borderRadius: ZRadii.card,
              border: Border.all(color: ZColors.borderStrong),
              boxShadow: ZShadows.softElevation,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(color: ZColors.hairline, height: 1),
                _buildStatCards(),
                const Divider(color: ZColors.hairline, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: ZRadii.pill,
                          gradient: const LinearGradient(
                            colors: ZColors.gradientNet,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Network Connections', style: ZText.section),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZColors.accent.withValues(alpha: 0.1),
                          borderRadius: ZRadii.pill,
                        ),
                        child: Text(
                          '${_connections?.length ?? 0}',
                          style: ZText.micro.copyWith(
                            color: ZColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildConnectionsList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              gradient: LinearGradient(
                colors:
                    ZColors.gradientCpu
                        .map((c) => c.withValues(alpha: 0.18))
                        .toList(),
              ),
              border: Border.all(color: ZColors.border),
            ),
            child: const Icon(
              Icons.memory_rounded,
              size: 18,
              color: ZColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.process.name,
                  style: ZText.section,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('PID ${widget.process.pid}', style: ZText.micro),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: ZRadii.inner,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: ZColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              label: 'CPU',
              value: '${widget.process.cpuPercent.toStringAsFixed(1)}%',
              color: ZColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(
              label: 'Memory',
              value: '${widget.process.memoryMb.toStringAsFixed(1)} MB',
              color: ZColors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ZColors.accent),
      );
    }

    if (_connections == null || _connections!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, size: 34, color: ZColors.textTertiary),
            const SizedBox(height: 10),
            Text(
              'No active connections',
              style: ZText.body.copyWith(color: ZColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      itemCount: _connections!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _ConnectionRow(conn: _connections![index]);
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZColors.backgroundDeep.withValues(alpha: 0.6),
        borderRadius: ZRadii.inner,
        border: Border.all(color: ZColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: ZText.micro),
          const SizedBox(height: 4),
          Text(
            value,
            style: ZText.metricSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final Map<String, dynamic> conn;
  const _ConnectionRow({required this.conn});

  @override
  Widget build(BuildContext context) {
    final status = conn['status'] as String? ?? 'UNKNOWN';
    final statusLower = status.toLowerCase();
    final Color dotColor;
    if (statusLower == 'established') {
      dotColor = ZColors.green;
    } else if (statusLower == 'time_wait') {
      dotColor = ZColors.orange;
    } else if (statusLower == 'listen') {
      dotColor = ZColors.accent;
    } else if (statusLower == 'close_wait' ||
        statusLower == 'fin_wait1' ||
        statusLower == 'fin_wait2') {
      dotColor = ZColors.red;
    } else {
      dotColor = ZColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZColors.surface.withValues(alpha: 0.5),
        borderRadius: ZRadii.inner,
        border: Border.all(color: ZColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: ZShadows.hairlineGlow(dotColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conn['local_addr'] as String? ?? '—',
                  style: ZText.mono(
                    size: 10,
                    weight: FontWeight.w500,
                  ).copyWith(color: ZColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_downward_rounded,
                      size: 10,
                      color: ZColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        conn['remote_addr'] as String? ?? '—',
                        style: ZText.mono(
                          size: 11,
                          weight: FontWeight.w600,
                        ).copyWith(color: ZColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.12),
              borderRadius: ZRadii.pill,
              border: Border.all(color: dotColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              status,
              style: ZText.micro.copyWith(
                color: dotColor,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
