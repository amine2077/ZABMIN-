import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ZColors.backgroundDeep.withValues(alpha: 0.7),
        borderRadius: ZRadii.pill,
        border: Border.all(color: ZColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button('1m', 1),
          const SizedBox(width: 2),
          _button('15m', 15),
          const SizedBox(width: 2),
          _button('1h', 60),
        ],
      ),
    );
  }

  Widget _button(String label, int minutes) {
    final isSelected = selectedMinutes == minutes;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(minutes),
        borderRadius: ZRadii.pill,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: ZRadii.pill,
            gradient: isSelected
                ? LinearGradient(colors: ZColors.gradientAccent)
                : null,
            color: isSelected ? null : Colors.transparent,
            boxShadow: isSelected
                ? ZShadows.hairlineGlow(ZColors.accent)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: ZText.caption.copyWith(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : ZColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
