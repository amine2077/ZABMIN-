import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/models/system_metrics.dart';

class RAMChart extends StatelessWidget {
  final List<SystemMetrics> history;

  const RAMChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _placeholder('Waiting for data...');
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].memory.percent));
    }

    return _chart(
      title: 'RAM Usage (last 60s)',
      spots: spots,
      maxY: 100,
    );
  }

  Widget _placeholder(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _boxDecoration(),
      child: Center(
        child: Text(text, style: GoogleFonts.inter(color: const Color(0xFF8B949E))),
      ),
    );
  }

  Widget _chart({required String title, required List<FlSpot> spots, required double maxY}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(_chartData(spots, maxY: maxY)),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF30363D)),
    );
  }

  LineChartData _chartData(List<FlSpot> spots, {required double maxY}) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF30363D), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 25,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}%',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B949E)),
            ),
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: const Color(0xFFBC8CFF),
          barWidth: 2.5,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFFBC8CFF).withOpacity(0.1),
          ),
        ),
      ],
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(enabled: false),
    );
  }
}
