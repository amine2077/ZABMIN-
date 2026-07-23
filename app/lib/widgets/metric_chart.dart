import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'chart_chrome.dart';

class ChartSeries {
  final String label;
  final List<Color> gradient;
  final double Function(SystemMetrics) liveExtractor;
  final String historyKey;
  final double barWidth;

  const ChartSeries({
    required this.label,
    required this.gradient,
    required this.liveExtractor,
    required this.historyKey,
    this.barWidth = 2.5,
  });
}

class MetricChart extends StatefulWidget {
  final String title;
  final List<SystemMetrics> history;
  final List<ChartSeries> series;
  final List<Color> accentGradient;
  final bool fixedMaxY;
  final bool showLegend;
  final bool showTooltip;

  const MetricChart({
    super.key,
    required this.title,
    required this.history,
    required this.series,
    required this.accentGradient,
    this.fixedMaxY = true,
    this.showLegend = false,
    this.showTooltip = false,
  });

  @override
  State<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<MetricChart> {
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

  List<List<FlSpot>> _buildSpots() {
    final allSpots = <List<FlSpot>>[];
    for (int i = 0; i < widget.series.length; i++) {
      allSpots.add(<FlSpot>[]);
    }

    if (_rangeMinutes == 1) {
      for (int i = 0; i < widget.history.length; i++) {
        final m = widget.history[i];
        for (int j = 0; j < widget.series.length; j++) {
          allSpots[j].add(
            FlSpot(i.toDouble(), widget.series[j].liveExtractor(m)),
          );
        }
      }
    } else if (_historicData != null) {
      for (int i = 0; i < _historicData!.length; i++) {
        final row = _historicData![i];
        for (int j = 0; j < widget.series.length; j++) {
          allSpots[j].add(
            FlSpot(
              i.toDouble(),
              (row[widget.series[j].historyKey] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
      }
    }

    return allSpots;
  }

  @override
  Widget build(BuildContext context) {
    final allSpots = _buildSpots();
    final isEmpty = allSpots.first.isEmpty;

    double maxY = 100;
    double interval = 25;
    String Function(double)? format;

    if (!widget.fixedMaxY) {
      double maxVal = 1;
      for (final spots in allSpots) {
        for (final spot in spots) {
          if (spot.y > maxVal) maxVal = spot.y;
        }
      }
      maxY = (maxVal * 1.2).ceilToDouble().clamp(1.0, double.infinity);
      interval = maxY > 10 ? 10.0 : (maxY / 4);
      format = (v) => v.toStringAsFixed(1);
    }

    return ChartChrome(
      title: widget.title,
      rangeMinutes: _rangeMinutes,
      onRangeChanged: _onRangeChanged,
      loading: _loading,
      accentGradient: widget.accentGradient,
      child: isEmpty
          ? const ChartEmptyState()
          : _buildChart(allSpots, maxY, interval, format),
    );
  }

  Widget _buildChart(
    List<List<FlSpot>> allSpots,
    double maxY,
    double interval,
    String Function(double)? format,
  ) {
    final lineBars = <LineChartBarData>[];
    for (int j = 0; j < widget.series.length; j++) {
      lineBars.add(
        gradientLine(
          spots: allSpots[j],
          gradient: widget.series[j].gradient,
          barWidth: widget.series[j].barWidth,
        ),
      );
    }

    final touchData = widget.showTooltip
        ? LineTouchData(
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
          )
        : LineTouchData(enabled: false);

    final chart = LineChart(
      LineChartData(
        gridData: chartGrid(),
        titlesData: chartTitles(maxY: maxY, interval: interval, format: format),
        borderData: FlBorderData(show: false),
        lineBarsData: lineBars,
        minY: 0,
        maxY: maxY,
        lineTouchData: touchData,
      ),
    );

    if (!widget.showLegend || widget.series.length < 2) {
      return chart;
    }

    return Stack(
      children: [
        chart,
        Positioned(
          top: 6,
          right: 8,
          child: Row(
            children: [
              for (int j = 0; j < widget.series.length; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                _LegendDot(
                  label: widget.series[j].label,
                  gradient: widget.series[j].gradient,
                ),
              ],
            ],
          ),
        ),
      ],
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
