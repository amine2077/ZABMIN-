import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import '../widgets/ram_chart.dart';

class RamScreen extends StatelessWidget {
  const RamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(child: CircularProgressIndicator(color: ZColors.accent));
        }

        final mem = metrics.memory;
        final freeGb = mem.totalGb - mem.usedGb;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Memory', style: GoogleFonts.inter(fontSize: 22, color: ZColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${mem.totalGb.toStringAsFixed(0)} GB${mem.speedMhz > 0 ? ' — ${mem.speedMhz} MHz' : ''}',
                style: GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _statCard('Used', '${mem.usedGb.toStringAsFixed(1)} GB', _usageColor(mem.percent))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Free', '${freeGb.toStringAsFixed(1)} GB', ZColors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Total', '${mem.totalGb.toStringAsFixed(1)} GB', ZColors.accent)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ZColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ZColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Memory Usage', style: GoogleFonts.inter(fontSize: 15, color: ZColors.textPrimary, fontWeight: FontWeight.w600)),
                        Text(
                          '${mem.percent.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(fontSize: 22, color: _usageColor(mem.percent), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (mem.percent / 100).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: ZColors.gridBg,
                        valueColor: AlwaysStoppedAnimation<Color>(_usageColor(mem.percent)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _legendItem('Used', _usageColor(mem.percent)),
                        _legendItem('Free', ZColors.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _detailCard('Available', '${mem.availableGb.toStringAsFixed(1)} GB', Icons.check_circle_outline, ZColors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _detailCard('Cached', '${mem.cachedGb.toStringAsFixed(1)} GB', Icons.cached_outlined, ZColors.purple)),
                  const SizedBox(width: 16),
                  Expanded(child: _detailCard('Speed', mem.speedMhz > 0 ? '${mem.speedMhz} MHz' : 'N/A', Icons.speed_outlined, ZColors.accent)),
                ],
              ),
              const SizedBox(height: 20),
              RAMChart(history: service.history),
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

  Widget _detailCard(String label, String value, IconData icon, Color color) {
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

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: ZColors.textSecondary)),
      ],
    );
  }
}
