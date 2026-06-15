import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/services/alerts_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/cpu_chart.dart';
import '../widgets/process_table.dart';
import 'processes_screen.dart';
import 'network_screen.dart';
import 'disk_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedNav = 'Dashboard';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    final navItems = ['Dashboard', 'Processes', 'Network', 'Disk'];

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          right: BorderSide(color: const Color(0xFF30363D), width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Zabmin',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF58A6FF),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          ...navItems.map((item) {
            final isSelected = item == _selectedNav;
            return Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  _navIcon(item),
                  color: isSelected
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF8B949E),
                ),
                title: Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF58A6FF)
                        : const Color(0xFFC9D1D9),
                  ),
                ),
                selected: isSelected,
                selectedTileColor: const Color(0xFF58A6FF).withOpacity(0.08),
                onTap: () {
                  setState(() => _selectedNav = item);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _navIcon(String item) {
    switch (item) {
      case 'Dashboard':
        return Icons.dashboard_outlined;
      case 'Processes':
        return Icons.memory_outlined;
      case 'Network':
        return Icons.network_check_outlined;
      case 'Disk':
        return Icons.storage_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Widget _buildContent() {
    switch (_selectedNav) {
      case 'Processes':
        return const ProcessesScreen();
      case 'Network':
        return const NetworkScreen();
      case 'Disk':
        return const DiskScreen();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return Consumer2<WebSocketService, AlertsService>(
      builder: (context, wsService, alertsService, _) {
        final metrics = wsService.latest;
        final status = wsService.connectionStatus;

        if (metrics == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF58A6FF),
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'connecting'
                      ? 'Connecting to agent...'
                      : 'Disconnected. Retrying...',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MetricCard(
                    label: 'CPU',
                    value: metrics.cpu.percentTotal.toStringAsFixed(1),
                    unit: '%',
                    percent: metrics.cpu.percentTotal,
                  ),
                  const SizedBox(width: 16),
                  MetricCard(
                    label: 'RAM',
                    value: metrics.memory.usedGb.toStringAsFixed(1),
                    unit: '/ ${metrics.memory.totalGb.toStringAsFixed(0)} GB',
                    percent: metrics.memory.percent,
                  ),
                  const SizedBox(width: 16),
                  MetricCard(
                    label: 'Disk',
                    value: metrics.disk.usedGb.toStringAsFixed(1),
                    unit: '/ ${metrics.disk.totalGb.toStringAsFixed(0)} GB',
                    percent: metrics.disk.percent,
                  ),
                  const SizedBox(width: 16),
                  MetricCard(
                    label: 'Network',
                    value: metrics.network.recvMbS.toStringAsFixed(1),
                    unit: 'MB/s',
                    percent: (metrics.network.recvMbS + metrics.network.sentMbS)
                        .clamp(0, 100),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CPUChart(history: wsService.history),
              const SizedBox(height: 20),
              ProcessTable(processes: metrics.processes),
            ],
          ),
        );
      },
    );
  }
}
