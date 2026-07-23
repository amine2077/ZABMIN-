import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/animated_metric.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_chart.dart';
import '../widgets/screen_shell.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

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

        final net = metrics.network;

        return ScreenShell(
          title: 'Network',
          subtitle: 'Real-time throughput on active adapters',
          accentGradient: ZColors.gradientNet,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ThroughputCard(
                    label: 'Download',
                    mbPerSec: net.recvMbS,
                    icon: Icons.arrow_downward_rounded,
                    gradient: ZColors.gradientNet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ThroughputCard(
                    label: 'Upload',
                    mbPerSec: net.sentMbS,
                    icon: Icons.arrow_upward_rounded,
                    gradient: ZColors.gradientGpu,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DetailStatCard(
                    label: 'Total Downloaded',
                    value: '${net.totalRecvGb.toStringAsFixed(1)} GB',
                    icon: Icons.cloud_download_rounded,
                    gradient: ZColors.gradientNet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DetailStatCard(
                    label: 'Total Uploaded',
                    value: '${net.totalSentGb.toStringAsFixed(1)} GB',
                    icon: Icons.cloud_upload_rounded,
                    gradient: ZColors.gradientGpu,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MetricChart(
              title: 'Network Throughput',
              history: service.history,
              accentGradient: ZColors.gradientNet,
              fixedMaxY: false,
              showLegend: true,
              series: [
                ChartSeries(
                  label: 'Download',
                  gradient: ZColors.gradientNet,
                  liveExtractor: (m) => m.network.recvMbS,
                  historyKey: 'net_recv_mb_s',
                ),
                ChartSeries(
                  label: 'Upload',
                  gradient: ZColors.gradientGpu,
                  liveExtractor: (m) => m.network.sentMbS,
                  historyKey: 'net_sent_mb_s',
                  barWidth: 2,
                ),
              ],
            ),
            const SizedBox(height: 20),
            GlassCard(
              hoverable: false,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: ZRadii.pill,
                          gradient: LinearGradient(
                            colors: ZColors.gradientAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Speed Summary', style: ZText.title),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SpeedBar(
                    label: 'Download',
                    current: net.recvMbS,
                    gradient: ZColors.gradientNet,
                  ),
                  const SizedBox(height: 14),
                  _SpeedBar(
                    label: 'Upload',
                    current: net.sentMbS,
                    gradient: ZColors.gradientGpu,
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

class _ThroughputCard extends StatelessWidget {
  final String label;
  final double mbPerSec;
  final IconData icon;
  final List<Color> gradient;

  const _ThroughputCard({
    required this.label,
    required this.mbPerSec,
    required this.icon,
    required this.gradient,
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  borderRadius: ZRadii.inner,
                  gradient: LinearGradient(
                    colors: gradient
                        .map((c) => c.withValues(alpha: 0.18))
                        .toList(),
                  ),
                  border: Border.all(color: ZColors.border),
                ),
                child: Icon(icon, color: gradient.first, size: 18),
              ),
              const SizedBox(width: 10),
              Text(label.toUpperCase(), style: ZText.micro),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedMetric(value: mbPerSec, decimals: 2, style: ZText.metric),
              const SizedBox(width: 6),
              Text('MB/s', style: ZText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedBar extends StatelessWidget {
  final String label;
  final double current;
  final List<Color> gradient;

  const _SpeedBar({
    required this.label,
    required this.current,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    const max = 100.0;
    final pct = (current / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: ZText.body.copyWith(color: ZColors.textSecondary),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              return Container(
                height: 6,
                decoration: BoxDecoration(
                  color: ZColors.border.withValues(alpha: 0.4),
                  borderRadius: ZRadii.pill,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: pct, end: pct),
                  duration: const Duration(milliseconds: 600),
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
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 92,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: current, end: current),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return Text(
                '${v.toStringAsFixed(2)} MB/s',
                textAlign: TextAlign.right,
                style: ZText.mono(
                  size: 12,
                  weight: FontWeight.w600,
                ).copyWith(color: gradient.first),
              );
            },
          ),
        ),
      ],
    );
  }
}
