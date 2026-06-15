import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/models/system_metrics.dart';

class ProcessesScreen extends StatelessWidget {
  const ProcessesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)));
        }

        final processes = List<ProcessInfo>.from(metrics.processes)
          ..sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Processes',
                style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${processes.length} running processes',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF8B949E)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _summaryCard('Total CPU', '${metrics.cpu.percentTotal.toStringAsFixed(1)}%', const Color(0xFF58A6FF))),
                  const SizedBox(width: 16),
                  Expanded(child: _summaryCard('Total RAM', '${metrics.memory.usedGb.toStringAsFixed(1)} GB', const Color(0xFFBC8CFF))),
                  const SizedBox(width: 16),
                  Expanded(child: _summaryCard('Processes', '${processes.length}', const Color(0xFF3FB950))),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('All Processes', style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    const Divider(color: Color(0xFF30363D), height: 1),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.55,
                      child: ListView.builder(
                        itemCount: processes.length,
                        itemBuilder: (context, index) {
                          final proc = processes[index];
                          return _processRow(proc, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
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
          Text(value, style: GoogleFonts.inter(fontSize: 22, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _processRow(ProcessInfo proc, int index) {
    final bgColor = index % 2 == 0 ? const Color(0xFF161B22) : const Color(0xFF1C2128);
    final cpuColor = proc.cpuPercent > 10 ? const Color(0xFFF85149) : proc.cpuPercent > 3 ? const Color(0xFFD29922) : const Color(0xFF8B949E);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(proc.name, style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: 80, child: Text(proc.pid.toString(), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E)))),
          SizedBox(
            width: 80,
            child: Text('${proc.cpuPercent.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 13, color: cpuColor, fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 90, child: Text('${proc.memoryMb.toStringAsFixed(1)} MB', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFC9D1D9)))),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: proc.status == 'running' ? const Color(0xFF3FB950).withValues(alpha: 0.15) : const Color(0xFF8B949E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(proc.status, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: proc.status == 'running' ? const Color(0xFF3FB950) : const Color(0xFF8B949E))),
            ),
          ),
          SizedBox(width: 80, child: Text('${proc.connections} conns', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B949E)))),
        ],
      ),
    );
  }
}
