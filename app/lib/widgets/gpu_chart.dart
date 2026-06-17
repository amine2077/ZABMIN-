import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import 'time_range_selector.dart';

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
    double maxVal = 100;

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
        final util = (_historicData![i]['gpu_percent'] as num?)?.toDouble() ?? 0.0;
        final vram = (_historicData![i]['gpu_vram_percent'] as num?)?.toDouble() ?? 0.0;
        utilSpots.add(FlSpot(i.toDouble(), util));
        vramSpots.add(FlSpot(i.toDouble(), vram));
      }
    }

    final rangeLabel = _rangeMinutes == 1
        ? 'last 60s'
        : _rangeMinutes == 15
            ? 'last 15m'
            : 'last 1h';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GPU ($rangeLabel)',
                style: GoogleFonts.inter(fontSize: 15, color: ZColors.textPrimary, fontWeight: FontWeight.w600),
              ),
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
              _legend('Utilization', ZColors.green),
              const SizedBox(width: 16),
              _legend('VRAM', ZColors.purple),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: ZColors.accent))
                : utilSpots.isEmpty
                    ? Center(
                        child: Text('Waiting for data...', style: GoogleFonts.inter(color: ZColors.textSecondary)))
                    : LineChart(_chartData(utilSpots, vramSpots, maxVal)),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: ZColors.textSecondary)),
      ],
    );
  }

  LineChartData _chartData(List<FlSpot> util, List<FlSpot> vram, double maxY) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (value) => FlLine(color: ZColors.border, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 25,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}%',
              style: GoogleFonts.inter(fontSize: 11, color: ZColors.textSecondary),
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
          spots: util,
          isCurved: true,
          curveSmoothness: 0.3,
          color: ZColors.green,
          barWidth: 2.5,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: ZColors.green.withValues(alpha: 0.08)),
        ),
        LineChartBarData(
          spots: vram,
          isCurved: true,
          curveSmoothness: 0.3,
          color: ZColors.purple,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: ZColors.purple.withValues(alpha: 0.08)),
        ),
      ],
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(enabled: false),
    );
  }
}
