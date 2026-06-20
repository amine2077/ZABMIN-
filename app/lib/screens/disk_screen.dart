import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/animated_metric.dart';
import '../widgets/metric_chart.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_shell.dart';

class DiskScreen extends StatelessWidget {
  const DiskScreen({super.key});

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

        final disk = metrics.disk;
        final freeGb = disk.totalGb - disk.usedGb;
        final partitions = disk.partitions;

        final grouped = <String, List<DiskPartition>>{};
        for (final p in partitions) {
          final key = p.physicalDrive.isNotEmpty ? p.physicalDrive : 'volume';
          grouped.putIfAbsent(key, () => []).add(p);
        }

        return ScreenShell(
          title: 'Storage',
          subtitle:
              '${grouped.length} disk${grouped.length == 1 ? '' : 's'} · ${partitions.length} partition${partitions.length == 1 ? '' : 's'} · ${disk.totalGb.toStringAsFixed(0)} GB total',
          accentGradient: ZColors.gradientDisk,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Used',
                    value: '${disk.usedGb.toStringAsFixed(1)} GB',
                    gradient: ZColors.usageGradient(disk.percent),
                    percent: disk.percent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryStat(
                    label: 'Free',
                    value: '${freeGb.toStringAsFixed(1)} GB',
                    gradient: const [ZColors.green, ZColors.greenSoft],
                    percent: (freeGb / disk.totalGb) * 100,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryStat(
                    label: 'Total',
                    value: '${disk.totalGb.toStringAsFixed(1)} GB',
                    gradient: ZColors.gradientAccent,
                    percent: 100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...grouped.entries.expand((entry) {
              final parts = entry.value;
              final driveRead = parts.fold<double>(0, (s, p) => s + p.readMbS);
              final driveWrite = parts.fold<double>(
                0,
                (s, p) => s + p.writeMbS,
              );
              return [
                _DiskGroupCard(
                  title:
                      parts.first.physicalDrive.isNotEmpty
                          ? parts.first.physicalDrive
                          : 'Volume',
                  subtitle:
                      parts.first.label.isNotEmpty ? parts.first.label : 'Disk',
                  readMbS: driveRead,
                  writeMbS: driveWrite,
                  partitions: parts,
                ),
                const SizedBox(height: 16),
              ];
            }),
            const SizedBox(height: 8),
            MetricChart(
              title: 'Disk Usage',
              history: service.history,
              accentGradient: ZColors.gradientDisk,
              series: [
                ChartSeries(
                  label: 'Disk',
                  gradient: ZColors.gradientDisk,
                  liveExtractor: (m) => m.disk.percent,
                  historyKey: 'disk_percent',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final List<Color> gradient;
  final double percent;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.gradient,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      glowColor: gradient.last,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: ZRadii.pill,
                  boxShadow: ZShadows.hairlineGlow(gradient.last),
                ),
              ),
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: ZText.micro),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedMetric(
                value:
                    double.tryParse(
                      value.replaceAll(RegExp(r'[^0-9.\-]'), ''),
                    ) ??
                    0.0,
                decimals: 1,
                style: ZText.metricSm,
              ),
              const SizedBox(width: 6),
              Text('GB', style: ZText.caption),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, c) {
              return Container(
                height: 5,
                decoration: BoxDecoration(
                  color: ZColors.border.withValues(alpha: 0.5),
                  borderRadius: ZRadii.pill,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: percent / 100,
                    end: percent / 100,
                  ),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    return FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: ZRadii.pill,
                          gradient: LinearGradient(colors: gradient),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiskGroupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double readMbS;
  final double writeMbS;
  final List<DiskPartition> partitions;

  const _DiskGroupCard({
    required this.title,
    required this.subtitle,
    required this.readMbS,
    required this.writeMbS,
    required this.partitions,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverable: false,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  borderRadius: ZRadii.inner,
                  gradient: LinearGradient(
                    colors:
                        ZColors.gradientDisk
                            .map((c) => c.withValues(alpha: 0.18))
                            .toList(),
                  ),
                  border: Border.all(color: ZColors.border),
                ),
                child: const Icon(
                  Icons.developer_board_rounded,
                  color: ZColors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ZText.title),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: ZText.caption),
                  ],
                ),
              ),
              _IoChip(
                label: 'Read',
                mbPerSec: readMbS,
                icon: Icons.arrow_downward_rounded,
                gradient: ZColors.gradientDisk,
              ),
              const SizedBox(width: 8),
              _IoChip(
                label: 'Write',
                mbPerSec: writeMbS,
                icon: Icons.arrow_upward_rounded,
                gradient: ZColors.gradientAccent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...partitions.asMap().entries.expand((entry) {
            final p = entry.value;
            return [
              if (entry.key > 0) const SizedBox(height: 18),
              _PartitionRow(p: p),
            ];
          }),
        ],
      ),
    );
  }
}

class _IoChip extends StatelessWidget {
  final String label;
  final double mbPerSec;
  final IconData icon;
  final List<Color> gradient;

  const _IoChip({
    required this.label,
    required this.mbPerSec,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient.map((c) => c.withValues(alpha: 0.10)).toList(),
        ),
        borderRadius: ZRadii.inner,
        border: Border.all(color: gradient.first.withValues(alpha: 0.3)),
        boxShadow: ZShadows.hairlineGlow(gradient.last),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: gradient.first),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: ZText.micro.copyWith(color: ZColors.textTertiary),
              ),
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: mbPerSec, end: mbPerSec),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  final text =
                      v >= 1
                          ? '${v.toStringAsFixed(1)} MB/s'
                          : '${(v * 1024).toStringAsFixed(0)} KB/s';
                  return Text(
                    text,
                    style: ZText.caption.copyWith(
                      color: gradient.first,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartitionRow extends StatelessWidget {
  final DiskPartition p;
  const _PartitionRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final driveLetter = p.mountpoint.replaceAll('\\', '');
    final color = ZColors.usageColor(p.percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: ZRadii.inner,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              alignment: Alignment.center,
              child: Text(
                driveLetter,
                style: ZText.title.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.label.isEmpty ? 'Partition' : p.label,
                          style: ZText.section,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: ZRadii.pill,
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${p.percent.toStringAsFixed(1)}%',
                          style: ZText.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${p.device} · ${p.filesystem}', style: ZText.micro),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, c) {
            return Container(
              height: 6,
              decoration: BoxDecoration(
                color: ZColors.border.withValues(alpha: 0.5),
                borderRadius: ZRadii.pill,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: p.percent / 100,
                  end: p.percent / 100,
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  return FractionallySizedBox(
                    widthFactor: v.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: ZRadii.pill,
                        gradient: LinearGradient(
                          colors: ZColors.usageGradient(p.percent),
                        ),
                        boxShadow: ZShadows.hairlineGlow(color),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MiniStat(
              label: 'USED',
              value: '${p.usedGb.toStringAsFixed(1)} GB',
              color: ZColors.textSecondary,
            ),
            const Spacer(),
            _MiniStat(
              label: 'FREE',
              value: '${p.freeGb.toStringAsFixed(1)} GB',
              color: ZColors.green,
            ),
            const Spacer(),
            _MiniStat(
              label: 'TOTAL',
              value: '${p.totalGb.toStringAsFixed(1)} GB',
              color: ZColors.textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ZText.micro.copyWith(color: ZColors.textTertiary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: ZText.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
