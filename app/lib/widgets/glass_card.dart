import 'package:flutter/material.dart';

import '../core/theme/zcolors.dart';

/// Crisp minimal glass card for Minimalist Executive Pro design.
/// Backdrop blur is intentionally removed for a sharper, data-dense aesthetic.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final bool hoverable;
  final Color? glowColor;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.hoverable = true,
    this.glowColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? ZRadii.card;

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: r,
        gradient:
            gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ZColors.surfaceElevated, ZColors.surface],
            ),
        border: Border.all(color: ZColors.border),
      ),
      child: child,
    );

    if (!hoverable) return content;

    return _HoverLift(radius: r, child: content);
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;

  const _HoverLift({required this.child, required this.radius});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: ZColors.accent.withValues(alpha: 0.10),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        transform: _hover
            ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
