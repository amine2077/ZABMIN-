import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/services/websocket_service.dart';
import '../core/theme/zcolors.dart';
import '../core/models/system_metrics.dart';

class ProcessesScreen extends StatefulWidget {
  const ProcessesScreen({super.key});

  @override
  State<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends State<ProcessesScreen> {
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  ProcessInfo? _selectedProcess;
  bool _panelVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPanel(ProcessInfo proc) {
    setState(() {
      _selectedProcess = proc;
      _panelVisible = true;
    });
  }

  void _closePanel() {
    setState(() {
      _panelVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, service, _) {
        final metrics = service.latest;
        if (metrics == null) {
          return const Center(
              child: CircularProgressIndicator(color: ZColors.accent));
        }

        final allProcesses = List<ProcessInfo>.from(metrics.processes)
          ..sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

        final filtered = _searchText.isEmpty
            ? allProcesses
            : allProcesses
                .where((p) =>
                    p.name.toLowerCase().contains(_searchText.toLowerCase()))
                .toList();

        return Stack(
          children: [
            _buildMainContent(filtered, allProcesses, metrics),
            if (_selectedProcess != null)
              _ConnectionPanel(
                process: _selectedProcess!,
                visible: _panelVisible,
                onClose: _closePanel,
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(
      List<ProcessInfo> filtered, List<ProcessInfo> all, SystemMetrics metrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Processes',
              style: GoogleFonts.inter(
                  fontSize: 22,
                  color: ZColors.textPrimary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${all.length} running processes',
              style:
                  GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _summaryCard('Total CPU',
                      '${metrics.cpu.percentTotal.toStringAsFixed(1)}%', ZColors.accent)),
              const SizedBox(width: 16),
              Expanded(
                  child: _summaryCard('Total RAM',
                      '${metrics.memory.usedGb.toStringAsFixed(1)} GB', ZColors.purple)),
              const SizedBox(width: 16),
              Expanded(
                  child: _summaryCard(
                      'Processes', '${all.length}', ZColors.green)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchField(),
          const SizedBox(height: 8),
          Text('Showing ${filtered.length} of ${all.length} processes',
              style:
                  GoogleFonts.inter(fontSize: 12, color: ZColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
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
                  child: Text('All Processes',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          color: ZColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ),
                const Divider(color: ZColors.border, height: 1),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _processRow(context, filtered[index], index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ZColors.surface,
        border: Border.all(color: ZColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchText = value),
        style: GoogleFonts.inter(fontSize: 13, color: ZColors.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon:
              const Icon(Icons.search, size: 18, color: ZColors.textSecondary),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 0),
          hintText: 'Search processes...',
          hintStyle:
              GoogleFonts.inter(fontSize: 13, color: ZColors.textSecondary),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      size: 16, color: ZColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 0),
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
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
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: ZColors.textSecondary)),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 22, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _processRow(BuildContext context, ProcessInfo proc, int index) {
    final bgColor = index % 2 == 0 ? ZColors.surface : ZColors.rowAlt;
    final cpuColor = proc.cpuPercent > 10
        ? ZColors.red
        : proc.cpuPercent > 3
            ? ZColors.orange
            : ZColors.textSecondary;

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: () => _openPanel(proc),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: Text(proc.name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: ZColors.textPrimary,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                  width: 80,
                  child: Text(proc.pid.toString(),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: ZColors.textSecondary))),
              SizedBox(
                width: 80,
                child: Text('${proc.cpuPercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: cpuColor,
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                  width: 90,
                  child: Text('${proc.memoryMb.toStringAsFixed(1)} MB',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: ZColors.textTertiary))),
              SizedBox(
                width: 80,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: proc.status == 'running'
                        ? ZColors.green.withValues(alpha: 0.15)
                        : ZColors.textSecondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(proc.status,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: proc.status == 'running'
                              ? ZColors.green
                              : ZColors.textSecondary)),
                ),
              ),
              SizedBox(
                  width: 80,
                  child: Text('${proc.connections} conns',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: ZColors.textSecondary))),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: ZColors.red),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _confirmKill(context, proc),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmKill(BuildContext context, ProcessInfo process) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZColors.surface,
        title: Text('Kill ${process.name}?',
            style:
                GoogleFonts.inter(color: ZColors.textPrimary, fontSize: 16)),
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
            child:
                Text('Kill', style: GoogleFonts.inter(color: ZColors.red)),
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

class _ConnectionPanel extends StatefulWidget {
  final ProcessInfo process;
  final bool visible;
  final VoidCallback onClose;

  const _ConnectionPanel({
    required this.process,
    required this.visible,
    required this.onClose,
  });

  @override
  State<_ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<_ConnectionPanel> {
  List<Map<String, dynamic>>? _connections;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  @override
  void didUpdateWidget(covariant _ConnectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.process.pid != widget.process.pid) {
      _fetchConnections();
    }
  }

  void _fetchConnections() async {
    setState(() {
      _loading = true;
      _connections = null;
    });
    final ws = context.read<WebSocketService>();
    final conns = await ws.fetchConnections(widget.process.pid);
    if (mounted) {
      setState(() {
        _connections = conns;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      right: widget.visible ? 0 : -360,
      top: 0,
      bottom: 0,
      width: 360,
      child: Material(
        elevation: 8,
        color: ZColors.background,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: ZColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(color: ZColors.border, height: 1),
              _buildStatCards(),
              const Divider(color: ZColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Network Connections',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        color: ZColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(child: _buildConnectionsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.process.name,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        color: ZColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('PID ${widget.process.pid}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: ZColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: ZColors.textSecondary),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CPU',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: ZColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                      '${widget.process.cpuPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          color: ZColors.accent,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RAM',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: ZColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                      '${widget.process.memoryMb.toStringAsFixed(1)} MB',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          color: ZColors.purple,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsList() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: ZColors.accent));
    }

    if (_connections == null || _connections!.isEmpty) {
      return Center(
        child: Text('No active connections',
            style: GoogleFonts.inter(
                fontSize: 13, color: ZColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _connections!.length,
      itemBuilder: (context, index) {
        final conn = _connections![index];
        return _connectionRow(conn, index);
      },
    );
  }

  Widget _connectionRow(Map<String, dynamic> conn, int index) {
    final status = conn['status'] as String? ?? 'UNKNOWN';
    final dotColor = status == 'ESTABLISHED'
        ? ZColors.green
        : status == 'TIME_WAIT'
            ? ZColors.orange
            : ZColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: index > 0
            ? Border(top: BorderSide(color: ZColors.border.withValues(alpha: 0.5)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conn['local_addr'] ?? '—',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: ZColors.textSecondary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.arrow_forward,
                        size: 10, color: ZColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(conn['remote_addr'] ?? '—',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: ZColors.textPrimary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status,
                style: GoogleFonts.inter(fontSize: 11, color: dotColor)),
          ),
        ],
      ),
    );
  }
}
