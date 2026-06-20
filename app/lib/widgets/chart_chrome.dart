import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'glass_card.dart';
import 'time_range_selector.dart';

class ChartChrome extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int rangeMinutes;
  final ValueChanged<int>? onRangeChanged;
  final Widget child;
  final bool loading;
  final List<Color>? accentGradient;

  const ChartChrome({
    super.key,
    required this.title,
    this.subtitle,
    required this.rangeMinutes,
    this.onRangeChanged,
    required this.child,
    this.loading = false,
    this.accentGradient,
  });

  @override
  Widget build(BuildContext context) {
    final rangeLabel = rangeMinutes == 1
        ? 'last 60s'
        : rangeMinutes == 15
        ? 'last 15m'
        : 'last 1h';

    return GlassCard(
      hoverable: false,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: ZRadii.pill,
                  gradient: LinearGradient(
                    colors: accentGradient ?? ZColors.gradientAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ZText.title),
                    const SizedBox(height: 2),
                    Text(subtitle ?? rangeLabel, style: ZText.caption),
                  ],
                ),
              ),
              if (onRangeChanged != null)
                TimeRangeSelector(
                  selectedMinutes: rangeMinutes,
                  onChanged: onRangeChanged!,
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: ZColors.accent),
                  )
                : child,
          ),
        ],
      ),
    );
  }
}

class ChartEmptyState extends StatelessWidget {
  final String label;
  const ChartEmptyState({super.key, this.label = 'Waiting for data...'});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label, style: ZText.caption));
  }
}

FlGridData chartGrid() {
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: 25,
    getDrawingHorizontalLine: (value) {
      return FlLine(color: ZColors.hairline, strokeWidth: 1, dashArray: [3, 4]);
    },
  );
}

FlTitlesData chartTitles({
  String Function(double value)? format,
  double maxY = 100,
  bool showLeft = true,
  double interval = 25,
}) {
  return FlTitlesData(
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: showLeft,
        reservedSize: 32,
        interval: interval,
        getTitlesWidget: (value, meta) {
          final text = format?.call(value) ?? '${value.toInt()}%';
          return Text(text, style: ZText.micro.copyWith(fontSize: 9));
        },
      ),
    ),
    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );
}

LineChartBarData gradientLine({
  required List<FlSpot> spots,
  required List<Color> gradient,
  double barWidth = 2.5,
}) {
  return LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.25,
    color: gradient.first,
    gradient: LinearGradient(colors: gradient),
    barWidth: barWidth,
    dotData: const FlDotData(show: false),
    preventCurveOverShooting: true,
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gradient.first.withValues(alpha: 0.35),
          gradient.first.withValues(alpha: 0.02),
        ],
      ),
    ),
    shadow: Shadow(
      color: gradient.last.withValues(alpha: 0.55),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  );
}

TextStyle inter({
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color? color,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color ?? ZColors.textPrimary,
  );
}
