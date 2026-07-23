import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/history_service.dart';
import '../core/services/report_exporter.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';

class _Range {
  final String label;
  final Duration duration;
  const _Range(this.label, this.duration);
}

const _recent = <_Range>[
  _Range('1h', Duration(hours: 1)),
  _Range('6h', Duration(hours: 6)),
  _Range('24h', Duration(hours: 24)),
];

const _days = <_Range>[
  _Range('7d', Duration(days: 7)),
  _Range('30d', Duration(days: 30)),
  _Range('60d', Duration(days: 60)),
  _Range('90d', Duration(days: 90)),
];

const _long = <_Range>[
  _Range('6mo', Duration(days: 182)),
  _Range('1y', Duration(days: 365)),
  _Range('5y', Duration(days: 365 * 5)),
];

const _allRanges = <_Range>[..._recent, ..._days, ..._long];

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  int _rangeIndex = 2; // 24h default
  ReportFormat _format = ReportFormat.csv;
  bool _busy = false;
  String? _message;
  bool _error = false;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    final history = context.read<HistoryService>();
    final now = DateTime.now();
    final from = now.subtract(_allRanges[_rangeIndex].duration);
    final rows = await history.fetchRange(from: from, to: now);
    if (rows.isEmpty) {
      setState(() {
        _busy = false;
        _message = 'No data recorded in this window yet.';
        _error = true;
      });
      return;
    }
    final summary = await history.summarize(from: from, to: now);
    final bytes = ReportExporter.export(
      rows: rows,
      summary: summary,
      format: _format,
    );

    String? outPath;
    try {
      outPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Zabmin report',
        fileName: ReportExporter.suggestedFilename(_format),
        type: FileType.custom,
        allowedExtensions: [_format == ReportFormat.csv ? 'csv' : 'json'],
      );
    } catch (e) {
      outPath = null;
    }

    if (!mounted) return;
    if (outPath == null) {
      setState(() {
        _busy = false;
        _message = 'Export cancelled.';
      });
      return;
    }

    try {
      await File(outPath).writeAsBytes(bytes, flush: true);
      final fileName = outPath.split(Platform.pathSeparator).last;
      setState(() {
        _busy = false;
        _message = 'Saved ${rows.length} samples to $fileName';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _message = 'Write failed: $e';
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ZColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: ZRadii.card,
        side: BorderSide(color: ZColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: ZRadii.inner,
                      gradient: const LinearGradient(
                        colors: ZColors.gradientAccent,
                      ),
                      boxShadow: ZShadows.hairlineGlow(ZColors.accent),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export report', style: ZText.title),
                        Text(
                          'CSV or JSON snapshot of recent metrics',
                          style: ZText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Time range', style: ZText.section),
              const SizedBox(height: 10),
              _RangeGroup(
                label: 'Recent',
                ranges: _recent,
                allRanges: _allRanges,
                selectedIndex: _rangeIndex,
                onSelected: (i) => setState(() => _rangeIndex = i),
              ),
              const SizedBox(height: 10),
              _RangeGroup(
                label: 'Days',
                ranges: _days,
                allRanges: _allRanges,
                selectedIndex: _rangeIndex,
                onSelected: (i) => setState(() => _rangeIndex = i),
              ),
              const SizedBox(height: 10),
              _RangeGroup(
                label: 'Months & years',
                ranges: _long,
                allRanges: _allRanges,
                selectedIndex: _rangeIndex,
                onSelected: (i) => setState(() => _rangeIndex = i),
              ),
              const SizedBox(height: 18),
              Text('Format', style: ZText.section),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('CSV'),
                    selected: _format == ReportFormat.csv,
                    onSelected: (_) =>
                        setState(() => _format = ReportFormat.csv),
                    selectedColor: ZColors.accent.withValues(alpha: 0.22),
                    side: BorderSide(color: ZColors.border),
                  ),
                  ChoiceChip(
                    label: const Text('JSON'),
                    selected: _format == ReportFormat.json,
                    onSelected: (_) =>
                        setState(() => _format = ReportFormat.json),
                    selectedColor: ZColors.accent.withValues(alpha: 0.22),
                    side: BorderSide(color: ZColors.border),
                  ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  style: ZText.caption.copyWith(
                    color: _error ? ZColors.red : ZColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 16),
                    label: Text(_busy ? 'Exporting...' : 'Export'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeGroup extends StatelessWidget {
  final String label;
  final List<_Range> ranges;
  final List<_Range> allRanges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _RangeGroup({
    required this.label,
    required this.ranges,
    required this.allRanges,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: ZText.caption.copyWith(color: ZColors.textTertiary),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final r in ranges)
                ChoiceChip(
                  label: Text(r.label),
                  selected: allRanges[selectedIndex] == r,
                  onSelected: (_) => onSelected(allRanges.indexOf(r)),
                  selectedColor: ZColors.accent.withValues(alpha: 0.22),
                  side: BorderSide(color: ZColors.border),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
