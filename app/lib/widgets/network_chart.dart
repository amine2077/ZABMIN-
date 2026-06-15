import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/models/system_metrics.dart';

class NetworkChart extends StatelessWidget {
  final List<SystemMetrics> history;

  const NetworkChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _placeholder('Waiting for data...');
    }

    final recvSpots = <FlSpot>[];
    final sentSpots = <FlSpot>[];
    double maxVal = 1;
    for (int i = 0; i < history.length; i++) {
      final recv = history[i].network.recvMbS;
      final sent = history[i].network.sentMbS;
      recvSpots.add(FlSpot(i.toDouble(), recv));
      sentSpots.add(FlSpot(i.toDouble(), sent));
      if (recv > maxVal) maxVal = recv;
      if (sent > maxVal) maxVal = sent;
    }

    final maxY = (maxVal * 1.2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Network (last 60s)', style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _legend('Recv', const Color(0xFF58A6FF)),
              const SizedBox(width: 16),
              _legend('Sent', const Color(0xFF3FB950)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: LineChart(_chartData(recvSpots, sentSpots, maxY)),
          ),
        ],
      ),
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

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8B949E))),
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF30363D)),
    );
  }

  LineChartData _chartData(List<FlSpot> recv, List<FlSpot> sent, double maxY) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 10 ? 10 : (maxY / 4),
        getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF30363D), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: maxY > 10 ? 10 : (maxY / 4),
            getTitlesWidget: (value, meta) => Text(
              '${value.toStringAsFixed(1)}',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF8B949E)),
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
          spots: recv,
          isCurved: true,
          curveSmoothness: 0.3,
          color: const Color(0xFF58A6FF),
          barWidth: 2.5,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: const Color(0xFF58A6FF).withOpacity(0.08)),
        ),
        LineChartBarData(
          spots: sent,
          isCurved: true,
          curveSmoothness: 0.3,
          color: const Color(0xFF3FB950),
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: const Color(0xFF3FB950).withOpacity(0.08)),
        ),
      ],
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(enabled: false),
    );
  }
}
