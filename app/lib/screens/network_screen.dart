import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../widgets/network_chart.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)));
        }

        final net = metrics.network;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Network', style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Real-time network activity', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B949E))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _statCard('Download', '${net.recvMbS.toStringAsFixed(2)} MB/s', const Color(0xFF58A6FF), Icons.download_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Upload', '${net.sentMbS.toStringAsFixed(2)} MB/s', const Color(0xFF3FB950), Icons.upload_outlined)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _statCard('Total Downloaded', '${net.totalRecvGb.toStringAsFixed(1)} GB', const Color(0xFF8B949E), Icons.data_usage_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard('Total Uploaded', '${net.totalSentGb.toStringAsFixed(1)} GB', const Color(0xFF8B949E), Icons.data_usage_outlined)),
                ],
              ),
              const SizedBox(height: 20),
              NetworkChart(history: service.history),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Speed Summary', style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _speedBar('Download', net.recvMbS, 100, const Color(0xFF58A6FF)),
                    const SizedBox(height: 12),
                    _speedBar('Upload', net.sentMbS, 100, const Color(0xFF3FB950)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
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

  Widget _speedBar(String label, double current, double max, Color color) {
    final pct = (current / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B949E)))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFF21262D),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: Text('${current.toStringAsFixed(2)} MB/s', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600))),
      ],
    );
  }
}
