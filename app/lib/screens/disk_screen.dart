import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import '../widgets/disk_chart.dart';

class DiskScreen extends StatelessWidget {
  const DiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(child: CircularProgressIndicator(color: ZColors.accent));
        }

        final disk = metrics.disk;
        final freeGb = disk.totalGb - disk.usedGb;
        final partitions = disk.partitions;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Disks', style: GoogleFonts.inter(fontSize: 22, color: ZColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${partitions.length} partition${partitions.length == 1 ? '' : 's'} — ${disk.totalGb.toStringAsFixed(0)} GB total',
                style: GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _statCard('Used', '${disk.usedGb.toStringAsFixed(1)} GB', _usageColor(disk.percent))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Free', '${freeGb.toStringAsFixed(1)} GB', ZColors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Total', '${disk.totalGb.toStringAsFixed(1)} GB', ZColors.accent)),
                ],
              ),
              const SizedBox(height: 20),
              ...partitions.asMap().entries.map((entry) {
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _partitionCard(p),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _ioCard('Read Speed', '${disk.readMbS.toStringAsFixed(2)} MB/s', Icons.speed_outlined, ZColors.orange)),
                  const SizedBox(width: 16),
                  Expanded(child: _ioCard('Write Speed', '${disk.writeMbS.toStringAsFixed(2)} MB/s', Icons.edit_outlined, ZColors.accent)),
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
    if (percent < 60) return ZColors.green;
    if (percent < 85) return ZColors.orange;
    return ZColors.red;
  }

  Widget _partitionCard(DiskPartition p) {
    final driveLetter = p.mountpoint.replaceAll('\\', '');
    final color = _usageColor(p.percent);

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.storage_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          driveLetter,
                          style: GoogleFonts.inter(fontSize: 16, color: ZColors.textPrimary, fontWeight: FontWeight.w700),
                        ),
                        if (p.label.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            p.label,
                            style: GoogleFonts.inter(fontSize: 14, color: ZColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.device} — ${p.filesystem}',
                      style: GoogleFonts.inter(fontSize: 11, color: ZColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${p.percent.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (p.percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: ZColors.gridBg,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat('${p.usedGb.toStringAsFixed(1)} GB used', ZColors.textSecondary),
              const Spacer(),
              _miniStat('${p.freeGb.toStringAsFixed(1)} GB free', ZColors.green),
              const Spacer(),
              _miniStat('${p.totalGb.toStringAsFixed(1)} GB total', ZColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, color: color),
    );
  }

  Widget _statCard(String label, String value, Color color) {
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
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: ZColors.textSecondary)),
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
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZColors.border),
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
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: ZColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 18, color: ZColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
