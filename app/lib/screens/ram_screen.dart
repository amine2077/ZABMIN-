import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/animated_metric.dart';
import '../widgets/circular_progress_arc.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_chart.dart';
import '../widgets/screen_shell.dart';

class RamScreen extends StatelessWidget {
  const RamScreen({super.key});

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

        final mem = metrics.memory;
        final freeGb = mem.totalGb - mem.usedGb;
        final grad = ZColors.gradientRam;

        return ScreenShell(
          title: 'Memory',
          subtitle:
              '${mem.totalGb.toStringAsFixed(0)} GB${mem.speedMhz > 0 ? ' · ${mem.speedMhz} MHz' : ''}',
          accentGradient: grad,
          children: [
            GlassCard(
              hoverable: false,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircularProgressArc(
                    percent: mem.percent,
                    gradient: grad,
                    size: 120,
                    strokeWidth: 10,
                    center: AnimatedMetric(
                      value: mem.percent,
                      decimals: 0,
                      suffix: '%',
                      style: ZText.metricSm,
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Memory Usage', style: ZText.section),
                        const SizedBox(height: 6),
                        Text(
                          'Active physical RAM consumption',
                          style: ZText.caption,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            InlineStat(
                              label: 'Used',
                              value: '${mem.usedGb.toStringAsFixed(1)} GB',
                              color: ZColors.usageColor(mem.percent),
                            ),
                            const SizedBox(width: 20),
                            InlineStat(
                              label: 'Free',
                              value: '${freeGb.toStringAsFixed(1)} GB',
                              color: ZColors.green,
                            ),
                            const SizedBox(width: 20),
                            InlineStat(
                              label: 'Total',
                              value: '${mem.totalGb.toStringAsFixed(1)} GB',
                              color: ZColors.textPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DetailStatCard(
                    label: 'Available',
                    value: '${mem.availableGb.toStringAsFixed(1)} GB',
                    icon: Icons.check_circle_rounded,
                    gradient: ZColors.gradientGpu,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DetailStatCard(
                    label: 'Cached',
                    value: '${mem.cachedGb.toStringAsFixed(1)} GB',
                    icon: Icons.cached_rounded,
                    gradient: ZColors.gradientRam,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DetailStatCard(
                    label: 'Speed',
                    value: mem.speedMhz > 0 ? '${mem.speedMhz} MHz' : 'N/A',
                    icon: Icons.speed_rounded,
                    gradient: ZColors.gradientAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MetricChart(
              title: 'Memory Usage',
              history: service.history,
              accentGradient: ZColors.gradientRam,
              series: [
                ChartSeries(
                  label: 'RAM',
                  gradient: ZColors.gradientRam,
                  liveExtractor: (m) => m.memory.percent,
                  historyKey: 'ram_percent',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
