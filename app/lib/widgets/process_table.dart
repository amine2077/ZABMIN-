import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../core/models/system_metrics.dart';
import '../core/utils/error_messages.dart';
import 'glass_card.dart';

class ProcessTable extends StatefulWidget {
  final List<ProcessInfo> processes;
  final int? limit;
  final VoidCallback? onViewAll;

  const ProcessTable({
    super.key,
    required this.processes,
    this.limit,
    this.onViewAll,
  });

  @override
  State<ProcessTable> createState() => _ProcessTableState();
}

class _ProcessTableState extends State<ProcessTable> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    var sorted = List<ProcessInfo>.from(widget.processes)
      ..sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

    if (widget.limit != null && sorted.length > widget.limit!) {
      sorted = sorted.take(widget.limit!).toList();
    }

    return GlassCard(
      hoverable: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: ZRadii.pill,
                    gradient: const LinearGradient(
                      colors: ZColors.gradientAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Top Processes', style: ZText.title),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ZColors.accent.withValues(alpha: 0.1),
                    borderRadius: ZRadii.pill,
                    border: Border.all(
                      color: ZColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${sorted.length}',
                    style: ZText.micro.copyWith(
                      color: ZColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.onViewAll != null) ...[
                  const Spacer(),
                  InkWell(
                    onTap: widget.onViewAll,
                    borderRadius: ZRadii.inner,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'View All',
                            style: ZText.caption.copyWith(
                              color: ZColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: ZColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _TableHeader(),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverIndex = index),
                  onExit: (_) => setState(() {
                    if (_hoverIndex == index) _hoverIndex = null;
                  }),
                  child: _ProcessRow(
                    process: sorted[index],
                    index: index,
                    hovered: _hoverIndex == index,
                    onKill: () => _confirmKill(context, sorted[index]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
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
            Icon(Icons.warning_amber_rounded, color: ZColors.red, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Kill ${process.name}?', style: ZText.title)),
          ],
        ),
        content: Text(
          'This will terminate PID ${process.pid}. Unsaved work in that process will be lost.',
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

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: ZColors.backgroundDeep.withValues(alpha: 0.6),
        border: const Border(
          top: BorderSide(color: ZColors.hairline),
          bottom: BorderSide(color: ZColors.hairline),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showMemory = constraints.maxWidth > 430;
          final showStatus = constraints.maxWidth > 540;
          return Row(
            children: [
              Expanded(
                child: Text(
                  'PROCESS',
                  overflow: TextOverflow.ellipsis,
                  style: ZText.micro.copyWith(
                    letterSpacing: 1.2,
                    color: ZColors.textTertiary,
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  'CPU',
                  textAlign: TextAlign.right,
                  style: ZText.micro.copyWith(
                    letterSpacing: 1.2,
                    color: ZColors.textTertiary,
                  ),
                ),
              ),
              if (showMemory)
                SizedBox(
                  width: 84,
                  child: Text(
                    'MEMORY',
                    textAlign: TextAlign.right,
                    style: ZText.micro.copyWith(
                      letterSpacing: 1.2,
                      color: ZColors.textTertiary,
                    ),
                  ),
                ),
              if (showStatus)
                SizedBox(
                  width: 72,
                  child: Text(
                    'STATUS',
                    textAlign: TextAlign.center,
                    style: ZText.micro.copyWith(
                      letterSpacing: 1.2,
                      color: ZColors.textTertiary,
                    ),
                  ),
                ),
              const SizedBox(width: 44),
            ],
          );
        },
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  final ProcessInfo process;
  final int index;
  final bool hovered;
  final VoidCallback onKill;

  const _ProcessRow({
    required this.process,
    required this.index,
    required this.hovered,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    final baseBg = index.isEven
        ? ZColors.surface.withValues(alpha: 0.2)
        : ZColors.rowAlt.withValues(alpha: 0.4);
    final bg = hovered ? ZColors.rowHover : baseBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showMemory = constraints.maxWidth > 430;
          final showStatus = constraints.maxWidth > 540;
          return Row(
            children: [
              Expanded(
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
                        (process.name.isEmpty
                                ? '?'
                                : process.name.characters.first)
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
                        process.name,
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
                width: 64,
                child: Text(
                  '${process.cpuPercent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: ZText.mono(
                    size: 11,
                    weight: FontWeight.w600,
                  ).copyWith(color: ZColors.usageColor(process.cpuPercent)),
                ),
              ),
              if (showMemory)
                SizedBox(
                  width: 84,
                  child: Text(
                    '${process.memoryMb.toStringAsFixed(1)} MB',
                    textAlign: TextAlign.right,
                    style: ZText.mono(
                      size: 11,
                      weight: FontWeight.w500,
                    ).copyWith(color: ZColors.textTertiary),
                  ),
                ),
              if (showStatus)
                SizedBox(
                  width: 72,
                  child: Center(child: _StatusPill(status: process.status)),
                ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onKill,
                      borderRadius: ZRadii.inner,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: ZRadii.inner,
                          color: hovered
                              ? ZColors.red.withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: Border.all(
                            color: hovered
                                ? ZColors.red.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: hovered ? ZColors.red : ZColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRunning = status.toLowerCase() == 'running';
    final isSleeping = status.toLowerCase() == 'sleeping';
    Color color;
    if (isRunning) {
      color = ZColors.green;
    } else if (isSleeping) {
      color = ZColors.accent;
    } else {
      color = ZColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: ZRadii.pill,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: ZShadows.hairlineGlow(color),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: ZText.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
