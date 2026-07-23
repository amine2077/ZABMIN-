import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        final hPad = narrow ? 16.0 : 24.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compact Executive Header ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
              decoration: BoxDecoration(
                color: ZColors.surface,
                border: const Border(
                  bottom: BorderSide(color: ZColors.border, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Accent bar
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: ZRadii.pill,
                      gradient: LinearGradient(colors: accentGradient),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Icon badge
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentGradient.first.withValues(alpha: 0.12),
                      borderRadius: ZRadii.inner,
                      border: Border.all(
                        color: accentGradient.first.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      _iconForTitle(title),
                      size: 16,
                      color: accentGradient.first,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: ZColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: ZText.caption.copyWith(
                            color: ZColors.textSecondary,
                            fontSize: 11,
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
            ),
            // ── Scrollable Content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForTitle(String t) {
    switch (t.toLowerCase()) {
      case 'memory':
        return Icons.pie_chart_rounded;
      case 'network':
        return Icons.sensors_rounded;
      case 'disk':
        return Icons.dns_rounded;
      case 'graphics':
        return Icons.videogame_asset_rounded;
      case 'processes':
        return Icons.list_alt_rounded;
      case 'settings':
        return Icons.tune_rounded;
      default:
        return Icons.monitor_heart_rounded;
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: ZRadii.card,
        border: Border.all(color: ZColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: ZRadii.inner,
              color: gradient.first.withValues(alpha: 0.12),
              border: Border.all(color: gradient.first.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: gradient.first, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: ZText.micro.copyWith(letterSpacing: 1.0),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: ZText.section.copyWith(
                    color: ZColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
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
          style: ZText.section.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
