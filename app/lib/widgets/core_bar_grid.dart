import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'glass_card.dart';

class CoreBarGrid extends StatelessWidget {
  final List<double> percentPerCore;

  const CoreBarGrid({super.key, required this.percentPerCore});

  @override
  Widget build(BuildContext context) {
    if (percentPerCore.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(18),
      glowColor: ZColors.gradientCpu.last,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ZColors.gradientCpu.first,
                  borderRadius: ZRadii.pill,
                  boxShadow: ZShadows.hairlineGlow(ZColors.gradientCpu.first),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PER-CORE CPU',
                style: ZText.micro.copyWith(
                  color: ZColors.textTertiary,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${percentPerCore.length} cores',
                style: ZText.caption.copyWith(color: ZColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(percentPerCore.length, (i) {
            final value = percentPerCore[i];
            final color = ZColors.usageColor(value);
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < percentPerCore.length - 1 ? 8 : 0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      'C$i',
                      style: ZText.caption.copyWith(
                        color: ZColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, c) {
                        return Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: ZColors.border.withValues(alpha: 0.35),
                            borderRadius: ZRadii.sm,
                          ),
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: value / 100,
                              end: value / 100,
                            ),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) {
                              return Container(
                                width:
                                    (c.maxWidth * v.clamp(0.0, 1.0))
                                        .clamp(0, c.maxWidth),
                                height: 18,
                                decoration: BoxDecoration(
                                  borderRadius: ZRadii.sm,
                                  color: color,
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 6),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${value.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: ZText.micro.copyWith(
                        color: ZColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
