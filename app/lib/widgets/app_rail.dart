import 'package:flutter/material.dart';

import '../core/nav_items.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';

/// Compact icon-only navigation rail for narrow windows.
class AppRail extends StatelessWidget {
  final String selectedNav;
  final ValueChanged<String> onNavSelected;
  final Widget bottom;

  const AppRail({
    super.key,
    required this.selectedNav,
    required this.onNavSelected,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: const BoxDecoration(
        color: ZColors.surface,
        border: Border(right: BorderSide(color: ZColors.border, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          // Logo mark
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              color: ZColors.accent.withValues(alpha: 0.15),
              border: Border.all(color: ZColors.accent.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.monitor_heart_rounded,
              size: 16,
              color: ZColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: ZColors.border, height: 1, thickness: 1),
          const SizedBox(height: 8),
          ...kNavItems.map(
            (item) => _RailTile(
              item: item,
              isSelected: item.label == selectedNav,
              onTap: () => onNavSelected(item.label),
            ),
          ),
          const Spacer(),
          const Divider(color: ZColors.border, height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
            child: bottom,
          ),
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ZRadii.inner,
          child: Tooltip(
            message: item.label,
            waitDuration: const Duration(milliseconds: 400),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: ZRadii.inner,
                color: isSelected
                    ? item.gradient.first.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: isSelected
                    ? Border.all(
                        color: item.gradient.first.withValues(alpha: 0.28),
                      )
                    : Border.all(color: Colors.transparent),
              ),
              child: Column(
                children: [
                  Icon(
                    item.icon,
                    size: 19,
                    color: isSelected
                        ? item.gradient.first
                        : ZColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: ZText.micro.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? ZColors.textPrimary
                          : ZColors.textTertiary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
