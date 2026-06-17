import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import '../core/models/system_metrics.dart';

class ProcessTable extends StatelessWidget {
  final List<ProcessInfo> processes;

  const ProcessTable({super.key, required this.processes});

  @override
  Widget build(BuildContext context) {
    final sorted = List<ProcessInfo>.from(processes)
      ..sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

    return Container(
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Top Processes',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: ZColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(color: ZColors.border, height: 1),
          _headerRow(),
          const Divider(color: ZColors.border, height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.3,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  _buildRow(context, index, sorted[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      color: ZColors.gridBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _headerCell('PID', width: 60),
          _headerCell('Name', flex: 3),
          _headerCell('CPU %', width: 60),
          _headerCell('RAM MB', width: 70),
          _headerCell('Status', width: 70),
          _headerCell('Conns', width: 50),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {double? width, int? flex}) {
    final style = GoogleFonts.inter(
      fontSize: 12,
      color: ZColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    if (flex != null) {
      return Expanded(flex: flex, child: Text(text, style: style));
    }
    return SizedBox(width: width, child: Text(text, style: style));
  }

  Widget _buildRow(BuildContext context, int index, ProcessInfo process) {
    final bgColor = index % 2 == 0 ? ZColors.surface : ZColors.rowAlt;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _cell(process.pid.toString(), width: 60),
          _cell(process.name, flex: 3),
          _cell(process.cpuPercent.toStringAsFixed(1), width: 60),
          _cell(process.memoryMb.toStringAsFixed(1), width: 70),
          _cell(process.status, width: 70),
          _cell(process.connections.toString(), width: 50),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16, color: ZColors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _confirmKill(context, process),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {double? width, int? flex}) {
    final widget = Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, color: ZColors.textTertiary),
      overflow: TextOverflow.ellipsis,
    );
    if (flex != null) {
      return Expanded(flex: flex, child: widget);
    }
    return SizedBox(width: width, child: widget);
  }

  void _confirmKill(BuildContext context, ProcessInfo process) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZColors.surface,
        title: Text('Kill ${process.name}?',
            style: GoogleFonts.inter(color: ZColors.textPrimary, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: ZColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _doKill(context, process);
            },
            child: Text('Kill', style: GoogleFonts.inter(color: ZColors.red)),
          ),
        ],
      ),
    );
  }

  void _doKill(BuildContext context, ProcessInfo process) {
    final ws = context.read<WebSocketService>();
    ws.killProcess(process.pid);
    ws.waitForKillResult().then((result) {
      if (!context.mounted) return;
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${process.name} killed'
                : 'Failed: ${result['error'] ?? 'unknown error'}',
          ),
          backgroundColor: success ? ZColors.green : ZColors.red,
        ),
      );
    });
  }
}
