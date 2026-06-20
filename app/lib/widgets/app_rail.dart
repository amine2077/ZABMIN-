import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/nav_items.dart';
import '../core/theme/zcolors.dart';

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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ZColors.surfaceElevated.withValues(alpha: 0.92),
                ZColors.surface.withValues(alpha: 0.92),
              ],
            ),
            border: const Border(right: BorderSide(color: ZColors.hairline)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: ZRadii.inner,
                  gradient: const LinearGradient(
                    colors: ZColors.gradientAccent,
                  ),
                  boxShadow: ZShadows.hairlineGlow(ZColors.accent),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ...kNavItems.map(
                (item) => _RailTile(
                  item: item,
                  isSelected: item.label == selectedNav,
                  onTap: () => onNavSelected(item.label),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
                child: bottom,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ZRadii.inner,
          child: Tooltip(
            message: item.label,
            waitDuration: const Duration(milliseconds: 400),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: ZRadii.inner,
                gradient: isSelected
                    ? LinearGradient(
                        colors: item.gradient
                            .map((c) => c.withValues(alpha: 0.22))
                            .toList(),
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected
                            ? item.gradient.first
                            : ZColors.textSecondary,
                      ),
                      if (isSelected)
                        Positioned(
                          left: -14,
                          child: Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: ZRadii.pill,
                              gradient: LinearGradient(colors: item.gradient),
                              boxShadow: ZShadows.hairlineGlow(
                                item.gradient.last,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? ZColors.textPrimary
                          : ZColors.textTertiary,
                      letterSpacing: 0.3,
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
