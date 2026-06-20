import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/animated_metric.dart';
import '../widgets/circular_progress_arc.dart';
import '../widgets/glass_card.dart';
import '../widgets/gpu_chart.dart';
import '../widgets/screen_shell.dart';

class GpuScreen extends StatelessWidget {
  const GpuScreen({super.key});

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

        final gpus = metrics.gpu;

        if (gpus.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: ZColors.gradientGpu
                          .map((c) => c.withValues(alpha: 0.15))
                          .toList(),
                    ),
                  ),
                  child: const Icon(
                    Icons.videogame_asset_off_rounded,
                    size: 40,
                    color: ZColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                Text('No GPU detected', style: ZText.title),
                const SizedBox(height: 8),
                Text(
                  'GPU monitoring requires NVIDIA or WMI-compatible hardware',
                  style: ZText.body.copyWith(color: ZColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ScreenShell(
          title: 'Graphics',
          subtitle: '${gpus.length} GPU${gpus.length == 1 ? '' : 's'} detected',
          accentGradient: ZColors.gradientGpu,
          children: [
            ...gpus.asMap().entries.expand((entry) {
              final gpu = entry.value;
              return [
                _GpuCard(gpu: gpu),
                if (entry.key < gpus.length - 1) const SizedBox(height: 20),
              ];
            }),
            if (gpus.any(
              (g) => g.utilizationPercent > 0 || g.temperatureC > 0,
            )) ...[
              const SizedBox(height: 20),
              GPUChart(history: service.history),
            ],
          ],
        );
      },
    );
  }
}

class _GpuCard extends StatelessWidget {
  final GPUStats gpu;
  const _GpuCard({required this.gpu});

  @override
  Widget build(BuildContext context) {
    final utilColor = ZColors.usageColor(gpu.utilizationPercent);
    final tempColor = ZColors.tempColor(gpu.temperatureC);

    return GlassCard(
      hoverable: false,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: ZRadii.inner,
                  gradient: LinearGradient(
                    colors: ZColors.gradientGpu
                        .map((c) => c.withValues(alpha: 0.18))
                        .toList(),
                  ),
                  border: Border.all(color: ZColors.border),
                ),
                child: const Icon(
                  Icons.videogame_asset_rounded,
                  color: ZColors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gpu.name, style: ZText.title),
                    if (gpu.driverVersion.isNotEmpty)
                      Text('Driver ${gpu.driverVersion}', style: ZText.caption),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressArc(
                  percent: gpu.utilizationPercent,
                  gradient: ZColors.gradientGpu,
                  size: 80,
                  strokeWidth: 7,
                  center: AnimatedMetric(
                    value: gpu.utilizationPercent,
                    decimals: 0,
                    suffix: '%',
                    style: ZText.caption.copyWith(
                      color: utilColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              if (gpu.vramTotalMb > 0) ...[
                Expanded(
                  child: _GpuStat(
                    label: gpu.vramUsedMb > 0 ? 'VRAM Used' : 'VRAM',
                    value: gpu.vramUsedMb > 0
                        ? '${gpu.vramUsedMb.toStringAsFixed(0)} MB'
                        : 'Shared',
                    color: ZColors.usageColor(gpu.vramPercent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GpuStat(
                    label: 'VRAM Total',
                    value: '${gpu.vramTotalMb.toStringAsFixed(0)} MB',
                    color: ZColors.accent,
                  ),
                ),
              ],
              if (gpu.vramTotalMb > 0) const SizedBox(width: 12),
              Expanded(
                child: _GpuStat(
                  label: 'Utilization',
                  value: gpu.utilizationPercent > 0
                      ? '${gpu.utilizationPercent.toStringAsFixed(1)}%'
                      : 'N/A',
                  color: utilColor,
                ),
              ),
              if (gpu.temperatureC > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _GpuStat(
                    label: 'Temperature',
                    value: '${gpu.temperatureC.toStringAsFixed(0)}°C',
                    color: tempColor,
                  ),
                ),
              ],
              if (gpu.fanPercent > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _GpuStat(
                    label: 'Fan',
                    value: '${gpu.fanPercent.toStringAsFixed(0)}%',
                    color: ZColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (gpu.vramTotalMb > 0 && gpu.vramUsedMb > 0) ...[
            const SizedBox(height: 22),
            _BarSection(
              label: 'VRAM Usage',
              percent: gpu.vramPercent,
              detail:
                  '${gpu.vramUsedMb.toStringAsFixed(0)} / ${gpu.vramTotalMb.toStringAsFixed(0)} MB',
              gradient: ZColors.gradientRam,
            ),
          ],
          if (gpu.utilizationPercent > 0) ...[
            const SizedBox(height: 16),
            _BarSection(
              label: 'GPU Utilization',
              percent: gpu.utilizationPercent,
              detail: '${gpu.utilizationPercent.toStringAsFixed(1)}%',
              gradient: ZColors.gradientGpu,
            ),
          ],
        ],
      ),
    );
  }
}

class _GpuStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _GpuStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZColors.backgroundDeep.withValues(alpha: 0.6),
        borderRadius: ZRadii.inner,
        border: Border.all(color: ZColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: ZText.micro),
          const SizedBox(height: 6),
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

class _BarSection extends StatelessWidget {
  final String label;
  final double percent;
  final String detail;
  final List<Color> gradient;

  const _BarSection({
    required this.label,
    required this.percent,
    required this.detail,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: ZText.body.copyWith(color: ZColors.textSecondary),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: percent, end: percent),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                final text = detail.contains('%')
                    ? '${v.toStringAsFixed(1)}%'
                    : detail;
                return Text(
                  text,
                  style: ZText.body.copyWith(
                    color: gradient.first,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (ctx, c) {
            return Container(
              height: 10,
              decoration: BoxDecoration(
                color: ZColors.border.withValues(alpha: 0.4),
                borderRadius: ZRadii.pill,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: percent / 100, end: percent / 100),
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
                        boxShadow: ZShadows.hairlineGlow(gradient.last),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
