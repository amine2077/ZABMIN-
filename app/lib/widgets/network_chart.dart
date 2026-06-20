import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'chart_chrome.dart';

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

    final maxY = (maxVal * 1.2).ceilToDouble().clamp(1.0, double.infinity);
    final interval = maxY > 10 ? 10.0 : (maxY / 4);

    return ChartChrome(
      title: 'Network Throughput',
      rangeMinutes: _rangeMinutes,
      onRangeChanged: _onRangeChanged,
      loading: _loading,
      accentGradient: ZColors.gradientNet,
      child: recvSpots.isEmpty
          ? const ChartEmptyState()
          : Stack(
              children: [
                LineChart(
                  LineChartData(
                    gridData: chartGrid(),
                    titlesData: chartTitles(
                      maxY: maxY,
                      interval: interval,
                      format: (v) => v.toStringAsFixed(1),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      gradientLine(
                        spots: recvSpots,
                        gradient: ZColors.gradientNet,
                      ),
                      gradientLine(
                        spots: sentSpots,
                        gradient: ZColors.gradientGpu,
                        barWidth: 2,
                      ),
                    ],
                    minY: 0,
                    maxY: maxY,
                    lineTouchData: LineTouchData(enabled: false),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: Row(
                    children: [
                      _LegendDot(
                        label: 'Download',
                        gradient: ZColors.gradientNet,
                      ),
                      const SizedBox(width: 12),
                      _LegendDot(
                        label: 'Upload',
                        gradient: ZColors.gradientGpu,
                      ),
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
