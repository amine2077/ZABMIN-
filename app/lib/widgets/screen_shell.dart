import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';

class ScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> accentGradient;
  final List<Widget> children;
  final List<Widget>? actions;

  const ScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentGradient,
    required this.children,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final narrow = constraints.maxWidth < 720;
        final hPad = narrow ? 16.0 : 28.0;
        final vPad = narrow ? 18.0 : 28.0;
        return Stack(
          children: [
            Positioned(
              top: -100,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentGradient.first.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 5,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: ZRadii.pill,
                          gradient: LinearGradient(colors: accentGradient),
                          boxShadow: ZShadows.hairlineGlow(accentGradient.last),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: ZText.display.copyWith(
                                fontSize: narrow ? 24 : 30,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: ZText.body.copyWith(
                                color: ZColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (actions != null) ...[
                        const SizedBox(width: 12),
                        ...actions!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class DetailStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const DetailStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: ZRadii.card,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ZColors.surfaceElevated, ZColors.surface],
        ),
        border: Border.all(color: ZColors.border),
        boxShadow: ZShadows.softElevation,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              gradient: LinearGradient(
                colors: gradient.map((c) => c.withValues(alpha: 0.18)).toList(),
              ),
              border: Border.all(color: ZColors.border),
            ),
            child: Icon(icon, color: gradient.first, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: ZText.micro),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: ZText.metricSm.copyWith(
                    color: ZColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const InlineStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: ZText.micro),
        const SizedBox(height: 4),
        Text(
          value,
          style: ZText.metricSm.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
