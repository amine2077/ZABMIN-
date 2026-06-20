import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'chart_chrome.dart';

class GPUChart extends StatefulWidget {
  final List<SystemMetrics> history;

  const GPUChart({super.key, required this.history});

  @override
  State<GPUChart> createState() => _GPUChartState();
}

class _GPUChartState extends State<GPUChart> {
  int _rangeMinutes = 1;
  List<Map<String, dynamic>>? _historicData;
  bool _loading = false;

  void _onRangeChanged(int minutes) async {
    setState(() {
      _rangeMinutes = minutes;
      if (minutes == 1) {
        _historicData = null;
        _loading = false;
      } else {
        _loading = true;
      }
    });
    if (minutes > 1) {
      final ws = context.read<WebSocketService>();
      final data = await ws.fetchHistory(minutes);
      if (mounted) {
        setState(() {
          _historicData = data;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilSpots = <FlSpot>[];
    final vramSpots = <FlSpot>[];

    if (_rangeMinutes == 1) {
      for (int i = 0; i < widget.history.length; i++) {
        final gpus = widget.history[i].gpu;
        final util = gpus.isNotEmpty ? gpus.first.utilizationPercent : 0.0;
        final vram = gpus.isNotEmpty ? gpus.first.vramPercent : 0.0;
        utilSpots.add(FlSpot(i.toDouble(), util));
        vramSpots.add(FlSpot(i.toDouble(), vram));
      }
    } else if (_historicData != null) {
      for (int i = 0; i < _historicData!.length; i++) {
        final util =
            (_historicData![i]['gpu_percent'] as num?)?.toDouble() ?? 0.0;
        final vram =
            (_historicData![i]['gpu_vram_percent'] as num?)?.toDouble() ?? 0.0;
        utilSpots.add(FlSpot(i.toDouble(), util));
        vramSpots.add(FlSpot(i.toDouble(), vram));
      }
    }

    return ChartChrome(
      title: 'GPU Load',
      rangeMinutes: _rangeMinutes,
      onRangeChanged: _onRangeChanged,
      loading: _loading,
      accentGradient: ZColors.gradientGpu,
      child: utilSpots.isEmpty
          ? const ChartEmptyState()
          : Stack(
              children: [
                LineChart(
                  LineChartData(
                    gridData: chartGrid(),
                    titlesData: chartTitles(),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      gradientLine(
                        spots: utilSpots,
                        gradient: ZColors.gradientGpu,
                      ),
                      gradientLine(
                        spots: vramSpots,
                        gradient: ZColors.gradientRam,
                        barWidth: 2,
                      ),
                    ],
                    minY: 0,
                    maxY: 100,
                    lineTouchData: LineTouchData(enabled: false),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: Row(
                    children: [
                      _LegendDot(
                        label: 'Utilization',
                        gradient: ZColors.gradientGpu,
                      ),
                      const SizedBox(width: 12),
                      _LegendDot(label: 'VRAM', gradient: ZColors.gradientRam),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  const _LegendDot({required this.label, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: ZRadii.pill,
            gradient: LinearGradient(colors: gradient),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: ZText.micro),
      ],
    );
  }
}
