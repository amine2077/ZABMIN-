import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'animated_metric.dart';
import 'circular_progress_arc.dart';
import 'glass_card.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double percent;
  final IconData? icon;
  final List<Color>? gradient;
  final bool expand;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.percent,
    this.icon,
    this.gradient,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final grad = gradient ?? ZColors.usageGradient(percent);
    final pct = percent.clamp(0.0, 100.0);
    final parsedValue = double.tryParse(value) ?? 0.0;

    final body = GlassCard(
      padding: const EdgeInsets.all(18),
      glowColor: grad.last,
      child: Stack(
        children: [
          // Big ghost icon in the back
          if (icon != null)
            Positioned(
              right: -8,
              top: -10,
              child: Icon(
                icon,
                size: 96,
                color: grad.first.withValues(alpha: 0.05),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: grad.first,
                      borderRadius: ZRadii.pill,
                      boxShadow: ZShadows.hairlineGlow(grad.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label.toUpperCase(),
                    style: ZText.micro.copyWith(
                      color: ZColors.textTertiary,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Value + arc row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: AnimatedMetric(
                                value: parsedValue,
                                decimals: value.contains('.') ? 1 : 0,
                                style: ZText.metric.copyWith(fontSize: 26),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                unit,
                                overflow: TextOverflow.ellipsis,
                                style: ZText.caption.copyWith(
                                  color: ZColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Mini linear bar
                        _GradientBar(percent: pct, gradient: grad),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Circular arc
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressArc(
                      percent: pct,
                      gradient: grad,
                      size: 48,
                      strokeWidth: 4,
                      center: Text(
                        '${pct.round()}%',
                        style: ZText.micro.copyWith(
                          color: ZColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return expand ? Expanded(child: body) : body;
  }
}

class _GradientBar extends StatelessWidget {
  final double percent;
  final List<Color> gradient;
  const _GradientBar({required this.percent, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        return Container(
          height: 5,
          decoration: BoxDecoration(
            color: ZColors.border.withValues(alpha: 0.5),
            borderRadius: ZRadii.pill,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: percent / 100, end: percent / 100),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: ZRadii.pill,
                    gradient: LinearGradient(colors: gradient),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
