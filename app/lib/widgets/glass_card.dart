import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/zcolors.dart';

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
    final radius = this.radius ?? ZRadii.card;
    final glow = glowColor ?? ZColors.accent;

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ZColors.surfaceElevated, ZColors.surface],
            ),
        border: Border.all(color: ZColors.border),
        boxShadow: ZShadows.softElevation,
      ),
      child: child,
    );

    content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );

    if (!hoverable) return content;

    return _HoverLift(glow: glow, radius: radius, child: content);
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;
  final Color glow;
  final BorderRadius radius;
  const _HoverLift({
    required this.child,
    required this.glow,
    required this.radius,
  });

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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: _hover
            ? (Matrix4.identity()..translateByDouble(0.0, -3.0, 0.0, 1.0))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          boxShadow: _hover
              ? [
                  ...ZShadows.softElevation,
                  BoxShadow(
                    color: widget.glow.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ]
              : ZShadows.softElevation,
        ),
        child: widget.child,
      ),
    );
  }
}
