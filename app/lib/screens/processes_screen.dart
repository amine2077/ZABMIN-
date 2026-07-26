import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../core/models/system_metrics.dart';
import '../core/utils/error_messages.dart';
import '../widgets/animated_metric.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_shell.dart';
import '../widgets/search_field.dart';

const Map<int, String> _priorityLabels = {
  64: 'IDLE',
  16384: 'BELOW NORMAL',
  32: 'NORMAL',
  32768: 'ABOVE NORMAL',
  128: 'HIGH',
};
const Map<int, IconData> _priorityIcons = {
  64: Icons.ac_unit_rounded,
  16384: Icons.arrow_downward_rounded,
  32: Icons.remove_rounded,
  32768: Icons.arrow_upward_rounded,
  128: Icons.flash_on_rounded,
};

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
  bool _treeMode = false;

  final Map<int, int> _treeDepth = {};

  List<ProcessInfo> _buildTreeList(List<ProcessInfo> flat) {
    _treeDepth.clear();
    final pidMap = <int, ProcessInfo>{};
    final children = <int, List<ProcessInfo>>{};
    for (final p in flat) {
      pidMap[p.pid] = p;
      children.putIfAbsent(p.ppid, () => []).add(p);
    }
    final roots = flat
        .where((p) => p.ppid == 0 || !pidMap.containsKey(p.ppid))
        .toList();
    roots.sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

    final result = <ProcessInfo>[];
    void walk(List<ProcessInfo> nodes, int depth) {
      for (final node in nodes) {
        _treeDepth[node.pid] = depth;
        result.add(node);
        final kids = children[node.pid];
        if (kids != null) {
          kids.sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));
          walk(kids, depth + 1);
        }
      }
    }

    walk(roots, 0);
    return result;
  }

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

        final filteredBase = _searchText.isEmpty
            ? allProcesses
            : allProcesses
                  .where(
                    (p) => p.name.toLowerCase().contains(
                      _searchText.toLowerCase(),
                    ),
                  )
                  .toList();

        final filtered = _treeMode
            ? _buildTreeList(filteredBase)
            : filteredBase;

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
        SearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchText = value),
          resultCount: filtered.length,
          totalCount: all.length,
          hintText: 'Search processes...',
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
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _treeMode = !_treeMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _treeMode
                              ? ZColors.gradientCpu.first.withValues(
                                  alpha: 0.15,
                                )
                              : ZColors.border.withValues(alpha: 0.3),
                          borderRadius: ZRadii.pill,
                          border: Border.all(
                            color: _treeMode
                                ? ZColors.gradientCpu.first.withValues(
                                    alpha: 0.3,
                                  )
                                : ZColors.hairline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _treeMode
                                  ? Icons.account_tree_rounded
                                  : Icons.list_rounded,
                              size: 14,
                              color: _treeMode
                                  ? ZColors.gradientCpu.first
                                  : ZColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _treeMode ? 'Tree' : 'Flat',
                              style: ZText.caption.copyWith(
                                color: _treeMode
                                    ? ZColors.gradientCpu.first
                                    : ZColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                    final proc = filtered[index];
                    final depth = _treeMode ? _treeDepth[proc.pid] ?? 0 : 0;
                    return _ProcessRow(
                      proc: proc,
                      index: index,
                      treeDepth: depth,
                      showTreeIndent: _treeMode,
                      onTap: () => _openPanel(proc),
                      onKill: () => _confirmKill(context, proc),
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
      builder: (ctx) => AlertDialog(
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
            Expanded(child: Text('Kill ${process.name}?', style: ZText.title)),
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
                      : userFacingAgentError(result['error'] as String?),
                ),
              ),
            ],
          ),
          backgroundColor: success
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

class _ProcessRow extends StatefulWidget {
  final ProcessInfo proc;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onKill;
  final int treeDepth;
  final bool showTreeIndent;

  const _ProcessRow({
    required this.proc,
    required this.index,
    required this.onTap,
    required this.onKill,
    this.treeDepth = 0,
    this.showTreeIndent = false,
  });

  @override
  State<_ProcessRow> createState() => _ProcessRowState();
}

class _ProcessRowState extends State<_ProcessRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final proc = widget.proc;
    final baseBg = widget.index.isEven
        ? ZColors.surface.withValues(alpha: 0.2)
        : ZColors.rowAlt.withValues(alpha: 0.4);
    final bg = _hovered ? ZColors.rowHover : baseBg;
    final cpuColor = ZColors.usageColor(proc.cpuPercent);
    final status = proc.status.toLowerCase();
    final statusColor = status == 'running'
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
                      if (widget.showTreeIndent)
                        ...List.generate(
                          widget.treeDepth.clamp(0, 20),
                          (_) => const SizedBox(width: 20),
                        ),
                      if (widget.showTreeIndent && widget.treeDepth > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 14,
                            color: ZColors.textTertiary,
                          ),
                        ),
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
                            color: _hovered
                                ? ZColors.red.withValues(alpha: 0.12)
                                : Colors.transparent,
                            border: Border.all(
                              color: _hovered
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

const List<int> _priorityValues = [64, 16384, 32, 32768, 128];

String _niceToLabel(int nice) => _priorityLabels[nice] ?? 'UNKNOWN ($nice)';

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
  int? _currentPriority;
  bool _priorityLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConnections();
    _fetchPriority();
  }

  @override
  void didUpdateWidget(covariant _ConnectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.process.pid != widget.process.pid) {
      _fetchConnections();
      _fetchPriority();
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

  void _fetchPriority() async {
    setState(() => _priorityLoading = true);
    final ws = context.read<WebSocketService>();
    final result = await ws.fetchPriority(widget.process.pid);
    if (mounted) {
      setState(() {
        _currentPriority = result['priority'] as int?;
        _priorityLoading = false;
      });
    }
  }

  void _changePriority(int priority) async {
    final ws = context.read<WebSocketService>();
    ws.setPriority(widget.process.pid, priority);
    final result = await ws.waitForPriorityResult(widget.process.pid);
    if (!mounted) return;
    final success = result['success'] == true;
    if (success) {
      setState(() => _currentPriority = result['priority'] as int?);
    }
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
                    ? 'Priority set to ${_niceToLabel(result['priority'] as int)}'
                    : userFacingAgentError(result['error'] as String?),
              ),
            ),
          ],
        ),
        backgroundColor: success
            ? ZColors.green.withValues(alpha: 0.95)
            : ZColors.red.withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: ZRadii.inner),
      ),
    );
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
                colors: ZColors.gradientCpu
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
    final prio = _currentPriority;
    final prioLabel = prio != null ? _niceToLabel(prio) : '—';
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 14),
          _buildPrioritySection(prioLabel, prio),
        ],
      ),
    );
  }

  Widget _buildPrioritySection(String prioLabel, int? prio) {
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
          Row(
            children: [
              Text('PRIORITY', style: ZText.micro),
              const Spacer(),
              if (_priorityLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ZColors.accent,
                  ),
                )
              else
                Text(
                  prioLabel,
                  style: ZText.metricSm.copyWith(
                    color: ZColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (prio != null && !_priorityLoading)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _priorityValues.map((val) {
                final selected = prio == val;
                return GestureDetector(
                  onTap: selected ? null : () => _changePriority(val),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ZColors.accent.withValues(alpha: 0.15)
                          : ZColors.surface.withValues(alpha: 0.5),
                      borderRadius: ZRadii.pill,
                      border: Border.all(
                        color: selected
                            ? ZColors.accent.withValues(alpha: 0.4)
                            : ZColors.hairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _priorityIcons[val] ?? Icons.remove_rounded,
                          size: 12,
                          color: selected
                              ? ZColors.accent
                              : ZColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _priorityLabels[val] ?? 'UNKNOWN',
                          style: ZText.micro.copyWith(
                            color: selected
                                ? ZColors.accent
                                : ZColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
