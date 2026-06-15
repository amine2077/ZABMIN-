import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../widgets/disk_chart.dart';

class DiskScreen extends StatelessWidget {
  const DiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)));
        }

        final disk = metrics.disk;
        final freeGb = disk.totalGb - disk.usedGb;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Disk', style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('C:\ drive storage', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B949E))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _statCard('Used', '${disk.usedGb.toStringAsFixed(1)} GB', _usageColor(disk.percent))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Free', '${freeGb.toStringAsFixed(1)} GB', const Color(0xFF3FB950))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Total', '${disk.totalGb.toStringAsFixed(1)} GB', const Color(0xFF58A6FF))),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Storage Usage', style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('${disk.percent.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 22, color: _usageColor(disk.percent), fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (disk.percent / 100).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: const Color(0xFF21262D),
                        valueColor: AlwaysStoppedAnimation<Color>(_usageColor(disk.percent)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _legendItem('Used', _usageColor(disk.percent)),
                        _legendItem('Free', const Color(0xFF3FB950)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _ioCard('Read Speed', '${disk.readMbS.toStringAsFixed(2)} MB/s', Icons.speed_outlined, const Color(0xFFD29922))),
                  const SizedBox(width: 16),
                  Expanded(child: _ioCard('Write Speed', '${disk.writeMbS.toStringAsFixed(2)} MB/s', Icons.edit_outlined, const Color(0xFF58A6FF))),
                ],
              ),
              const SizedBox(height: 20),
              DiskChart(history: service.history),
            ],
          ),
        );
      },
    );
  }

  Color _usageColor(double percent) {
    if (percent < 60) return const Color(0xFF3FB950);
    if (percent < 85) return const Color(0xFFD29922);
    return const Color(0xFFF85149);
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E))),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 20, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _ioCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E))),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E))),
      ],
    );
  }
}
