import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/models/system_metrics.dart';
import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import '../widgets/gpu_chart.dart';

class GpuScreen extends StatelessWidget {
  const GpuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(child: CircularProgressIndicator(color: ZColors.accent));
        }

        final gpus = metrics.gpu;

        if (gpus.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videogame_asset_off_outlined, size: 64, color: ZColors.textSecondary),
                const SizedBox(height: 16),
                Text('No GPU detected', style: GoogleFonts.inter(fontSize: 18, color: ZColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('GPU monitoring requires NVIDIA or WMI-compatible hardware', style: GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GPU', style: GoogleFonts.inter(fontSize: 22, color: ZColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${gpus.length} GPU${gpus.length == 1 ? '' : 's'} detected',
                style: GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ...gpus.asMap().entries.expand((entry) {
                final gpu = entry.value;
                return [
                  _gpuCard(gpu),
                  if (entry.key < gpus.length - 1) const SizedBox(height: 20),
                ];
              }),
              if (gpus.any((g) => g.utilizationPercent > 0 || g.temperatureC > 0)) ...[
                const SizedBox(height: 20),
                GPUChart(history: service.history),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _gpuCard(GPUStats gpu) {
    final vramColor = _usageColor(gpu.vramPercent);
    final utilColor = _usageColor(gpu.utilizationPercent);
    final tempColor = _tempColor(gpu.temperatureC);

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ZColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.videogame_asset_outlined, color: ZColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gpu.name, style: GoogleFonts.inter(fontSize: 16, color: ZColors.textPrimary, fontWeight: FontWeight.w700)),
                    if (gpu.driverVersion.isNotEmpty)
                      Text('Driver ${gpu.driverVersion}', style: GoogleFonts.inter(fontSize: 11, color: ZColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (gpu.vramTotalMb > 0) ...[
                Expanded(child: _statCard(
                  gpu.vramUsedMb > 0 ? 'VRAM Used' : 'VRAM',
                  gpu.vramUsedMb > 0 ? '${gpu.vramUsedMb.toStringAsFixed(0)} MB' : 'Shared',
                  vramColor,
                )),
                const SizedBox(width: 12),
                Expanded(child: _statCard('VRAM Total', '${gpu.vramTotalMb.toStringAsFixed(0)} MB', ZColors.accent)),
              ],
              if (gpu.vramTotalMb > 0) const SizedBox(width: 12),
              Expanded(child: _statCard(
                'Utilization',
                gpu.utilizationPercent > 0 ? '${gpu.utilizationPercent.toStringAsFixed(1)}%' : 'N/A',
                utilColor,
              )),
              if (gpu.temperatureC > 0) ...[
                const SizedBox(width: 12),
                Expanded(child: _statCard('Temperature', '${gpu.temperatureC.toStringAsFixed(0)} °C', tempColor)),
              ],
              if (gpu.fanPercent > 0) ...[
                const SizedBox(width: 12),
                Expanded(child: _statCard('Fan', '${gpu.fanPercent.toStringAsFixed(0)}%', ZColors.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (gpu.vramTotalMb > 0 && gpu.vramUsedMb > 0) ...[
            _barSection('VRAM Usage', gpu.vramPercent, '${gpu.vramUsedMb.toStringAsFixed(0)} / ${gpu.vramTotalMb.toStringAsFixed(0)} MB', vramColor),
            const SizedBox(height: 12),
          ],
          if (gpu.utilizationPercent > 0)
            _barSection('GPU Utilization', gpu.utilizationPercent, '${gpu.utilizationPercent.toStringAsFixed(1)}%', utilColor),
        ],
      ),
    );
  }

  Widget _barSection(String label, double percent, String detail, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary)),
            Text(detail, style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: ZColors.gridBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Color _usageColor(double percent) {
    if (percent < 60) return ZColors.green;
    if (percent < 85) return ZColors.orange;
    return ZColors.red;
  }

  Color _tempColor(double temp) {
    if (temp < 60) return ZColors.green;
    if (temp < 80) return ZColors.orange;
    return ZColors.red;
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: ZColors.textSecondary)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 17, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
