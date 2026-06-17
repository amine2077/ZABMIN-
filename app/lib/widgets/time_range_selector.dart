import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/zcolors.dart';

class TimeRangeSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;

  const TimeRangeSelector({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button('1m', 1),
        const SizedBox(width: 6),
        _button('15m', 15),
        const SizedBox(width: 6),
        _button('1h', 60),
      ],
    );
  }

  Widget _button(String label, int minutes) {
    final isSelected = selectedMinutes == minutes;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(minutes),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? ZColors.accent : ZColors.border,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isSelected ? ZColors.accent : ZColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
