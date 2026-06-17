import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import 'time_range_selector.dart';

class DiskChart extends StatefulWidget {
  final List<SystemMetrics> history;

  const DiskChart({super.key, required this.history});

  @override
  State<DiskChart> createState() => _DiskChartState();
}

class _DiskChartState extends State<DiskChart> {
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
        spots.add(FlSpot(i.toDouble(), widget.history[i].disk.percent));
      }
    } else if (_historicData != null) {
      for (int i = 0; i < _historicData!.length; i++) {
        spots.add(FlSpot(
            i.toDouble(),
            (_historicData![i]['disk_percent'] as num?)?.toDouble() ?? 0.0));
      }
    }

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
              Text('Disk Usage ($rangeLabel)',
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
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: ZColors.accent))
                : spots.isEmpty
                    ? Center(
                        child: Text('Waiting for data...',
                            style: GoogleFonts.inter(
                                color: ZColors.textSecondary)))
                    : LineChart(_chartData(spots)),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: ZColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ZColors.border),
    );
  }

  LineChartData _chartData(List<FlSpot> spots) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: ZColors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 25,
            getTitlesWidget: (value, meta) => Text('${value.toInt()}%',
                style: GoogleFonts.inter(
                    fontSize: 11, color: ZColors.textSecondary)),
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
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: ZColors.orange,
          barWidth: 2.5,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: ZColors.orange.withValues(alpha: 0.1),
          ),
        ),
      ],
      minY: 0,
      maxY: 100,
      lineTouchData: LineTouchData(enabled: false),
    );
  }
}
