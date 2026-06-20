import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import 'chart_chrome.dart';

class CPUChart extends StatefulWidget {
  final List<SystemMetrics> history;

  const CPUChart({super.key, required this.history});

  @override
  State<CPUChart> createState() => _CPUChartState();
}

class _CPUChartState extends State<CPUChart> {
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
    final spots = <FlSpot>[];

    if (_rangeMinutes == 1) {
      for (int i = 0; i < widget.history.length; i++) {
        spots.add(FlSpot(i.toDouble(), widget.history[i].cpu.percentTotal));
      }
    } else if (_historicData != null) {
      for (int i = 0; i < _historicData!.length; i++) {
        spots.add(
          FlSpot(
            i.toDouble(),
            (_historicData![i]['cpu_percent'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    }

    return ChartChrome(
      title: 'CPU Usage',
      rangeMinutes: _rangeMinutes,
      onRangeChanged: _onRangeChanged,
      loading: _loading,
      accentGradient: ZColors.gradientCpu,
      child: spots.isEmpty
          ? const ChartEmptyState()
          : LineChart(
              LineChartData(
                gridData: chartGrid(),
                titlesData: chartTitles(),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  gradientLine(spots: spots, gradient: ZColors.gradientCpu),
                ],
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots
                          .map(
                            (s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)}%',
                              inter(
                                size: 11,
                                weight: FontWeight.w600,
                                color: ZColors.textPrimary,
                              ),
                            ),
                          )
                          .toList();
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
