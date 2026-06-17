import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import 'time_range_selector.dart';

class NetworkChart extends StatefulWidget {
  final List<SystemMetrics> history;

  const NetworkChart({super.key, required this.history});

  @override
  State<NetworkChart> createState() => _NetworkChartState();
}

class _NetworkChartState extends State<NetworkChart> {
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
    final recvSpots = <FlSpot>[];
    final sentSpots = <FlSpot>[];
    double maxVal = 1;

    if (_rangeMinutes == 1) {
      for (int i = 0; i < widget.history.length; i++) {
        final recv = widget.history[i].network.recvMbS;
        final sent = widget.history[i].network.sentMbS;
        recvSpots.add(FlSpot(i.toDouble(), recv));
        sentSpots.add(FlSpot(i.toDouble(), sent));
        if (recv > maxVal) maxVal = recv;
        if (sent > maxVal) maxVal = sent;
      }
    } else if (_historicData != null) {
      for (int i = 0; i < _historicData!.length; i++) {
        final recv =
            (_historicData![i]['net_recv_mb_s'] as num?)?.toDouble() ?? 0.0;
        final sent =
            (_historicData![i]['net_sent_mb_s'] as num?)?.toDouble() ?? 0.0;
        recvSpots.add(FlSpot(i.toDouble(), recv));
        sentSpots.add(FlSpot(i.toDouble(), sent));
        if (recv > maxVal) maxVal = recv;
        if (sent > maxVal) maxVal = sent;
      }
    }

    final maxY = (maxVal * 1.2).ceilToDouble();
    final rangeLabel = _rangeMinutes == 1
        ? 'last 60s'
        : _rangeMinutes == 15
            ? 'last 15m'
            : 'last 1h';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Network ($rangeLabel)',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      color: ZColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              TimeRangeSelector(
                selectedMinutes: _rangeMinutes,
                onChanged: _onRangeChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legend('Recv', ZColors.accent),
              const SizedBox(width: 16),
              _legend('Sent', ZColors.green),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: ZColors.accent))
                : recvSpots.isEmpty
                    ? Center(
                        child: Text('Waiting for data...',
                            style: GoogleFonts.inter(
                                color: ZColors.textSecondary)))
                    : LineChart(
                        _chartData(recvSpots, sentSpots, maxY)),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(fontSize: 11, color: ZColors.textSecondary)),
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: ZColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ZColors.border),
    );
  }

  LineChartData _chartData(List<FlSpot> recv, List<FlSpot> sent, double maxY) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 10 ? 10 : (maxY / 4),
        getDrawingHorizontalLine: (value) =>
            FlLine(color: ZColors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: maxY > 10 ? 10 : (maxY / 4),
            getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1),
                style: GoogleFonts.inter(
                    fontSize: 10, color: ZColors.textSecondary)),
          ),
        ),
        bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: recv,
          isCurved: true,
          curveSmoothness: 0.3,
          color: ZColors.accent,
          barWidth: 2.5,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: ZColors.accent.withValues(alpha: 0.08)),
        ),
        LineChartBarData(
          spots: sent,
          isCurved: true,
          curveSmoothness: 0.3,
          color: ZColors.green,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: ZColors.green.withValues(alpha: 0.08)),
        ),
      ],
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(enabled: false),
    );
  }
}
