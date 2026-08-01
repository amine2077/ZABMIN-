import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/history_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'chart_chrome.dart';

class ChartSeries {
  final String label;
  final List<Color> gradient;
  final double Function(SystemMetrics) liveExtractor;
  final double Function(MetricSnapshot) snapshotExtractor;
  final double barWidth;

  const ChartSeries({
    required this.label,
    required this.gradient,
    required this.liveExtractor,
    required this.snapshotExtractor,
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
  final int maxPoints;

  const MetricChart({
    super.key,
    required this.title,
    required this.history,
    required this.series,
    required this.accentGradient,
    this.fixedMaxY = true,
    this.showLegend = false,
    this.showTooltip = false,
    this.maxPoints = 400,
  });

  @override
  State<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<MetricChart> {
  int _rangeMinutes = 1;
  List<List<FlSpot>>? _historicSpots;
  bool _loading = false;

  /// Cached subtree for historical ranges: the chart does not need to
  /// repaint on every live metric tick, only when its own data changes.
  Widget? _cachedChild;

  void _onRangeChanged(int minutes) {
    setState(() {
      _rangeMinutes = minutes;
      _historicSpots = null;
      _cachedChild = null;
      _loading = minutes > 1;
    });
    if (minutes > 1) {
      _fetchHistoric(minutes);
    }
  }

  Future<void> _fetchHistoric(int minutes) async {
    final historyService = context.read<HistoryService>();
    final now = DateTime.now();
    final rows = await historyService.fetchRange(
      from: now.subtract(Duration(minutes: minutes)),
      to: now,
      maxPoints: widget.maxPoints,
    );
    if (!mounted || _rangeMinutes != minutes) return;
    final spots = _snapshotsToSpots(rows);
    setState(() {
      _historicSpots = spots;
      _loading = false;
      _cachedChild = null;
    });
  }

  List<List<FlSpot>> _snapshotsToSpots(List<MetricSnapshot> rows) {
    final allSpots = List.generate(widget.series.length, (_) => <FlSpot>[]);
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      for (int j = 0; j < widget.series.length; j++) {
        allSpots[j].add(
          FlSpot(i.toDouble(), widget.series[j].snapshotExtractor(row)),
        );
      }
    }
    return allSpots;
  }

  List<List<FlSpot>> _liveSpots() {
    final allSpots = List.generate(widget.series.length, (_) => <FlSpot>[]);
    for (int i = 0; i < widget.history.length; i++) {
      final m = widget.history[i];
      for (int j = 0; j < widget.series.length; j++) {
        allSpots[j].add(
          FlSpot(i.toDouble(), widget.series[j].liveExtractor(m)),
        );
      }
    }
    return allSpots;
  }

  List<List<FlSpot>> _currentSpots() {
    if (_rangeMinutes == 1) return _liveSpots();
    return _historicSpots ?? List.generate(widget.series.length, (_) => []);
  }

  @override
  Widget build(BuildContext context) {
    // Historical ranges rebuild only when their own state changes; live
    // ranges rebuild every tick so the rolling line moves.
    if (_rangeMinutes > 1 && _cachedChild != null) {
      return _cachedChild!;
    }
    final child = _buildCurrent();
    if (_rangeMinutes > 1) {
      _cachedChild = child;
    }
    return child;
  }

  Widget _buildCurrent() {
    final allSpots = _currentSpots();
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
