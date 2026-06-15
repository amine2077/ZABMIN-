import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
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
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF21262D),
                  ),
                  columns: _headerStyle(const [
                    'PID',
                    'Name',
                    'CPU %',
                    'RAM MB',
                    'Status',
                    'Connections',
                  ]),
                  rows: sorted
                      .asMap()
                      .entries
                      .map((entry) => _buildRow(entry.key, entry.value))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _headerStyle(List<String> titles) {
    return titles.map((title) {
      return DataColumn(
        label: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF8B949E),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }

  DataRow _buildRow(int index, ProcessInfo process) {
    final bgColor = index % 2 == 0
        ? const Color(0xFF161B22)
        : const Color(0xFF1C2128);

    return DataRow(
      color: WidgetStateProperty.all(bgColor),
      cells: [
        _cell(process.pid.toString()),
        _cell(process.name),
        _cell(process.cpuPercent.toStringAsFixed(1)),
        _cell(process.memoryMb.toStringAsFixed(1)),
        _cell(process.status),
        _cell(process.connections.toString()),
      ],
    );
  }

  DataCell _cell(String text) {
    return DataCell(
      Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFFC9D1D9),
        ),
      ),
    );
  }
}
