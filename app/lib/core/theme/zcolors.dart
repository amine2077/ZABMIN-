import 'package:flutter/material.dart';

class ZColors {
  // --- Base palette (rich deep darks, crisp executive slate) ---
  static const Color background = Color(0xFF0F131C);
  static const Color backgroundDeep = Color(0xFF0B0E15);
  static const Color surface = Color(0xFF161B26);
  static const Color surfaceElevated = Color(0xFF1E2536);
  static const Color surfaceGlass = Color(0x99161B26); // 60% alpha for glass

  // --- Borders (solid crisp slate borders & hairlines) ---
  static const Color border = Color(0xFF262F40);
  static const Color borderStrong = Color(0xFF334057);
  static const Color hairline = Color(0xFF1F2736);

  // --- Primary accent (electric cyan/blue) ---
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentDeep = Color(0xFF2563EB);
  static const Color accentSoft = Color(0xFF60A5FA);

  // --- Semantic status colors ---
  static const Color green = Color(0xFF10B981);
  static const Color greenSoft = Color(0xFF34D399);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color redSoft = Color(0xFFF87171);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleSoft = Color(0xFFA78BFA);
  static const Color pink = Color(0xFFEC4899);
  static const Color teal = Color(0xFF06B6D4);
  static const Color indigo = Color(0xFF6366F1);
  static const Color amber = Color(0xFFF59E0B);

  // --- Typography ---
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF475569);

  // --- Chart / table surfaces ---
  static const Color gridBg = Color(0xFF111723);
  static const Color rowAlt = Color(0xFF131A26);
  static const Color rowHover = Color(0xFF1C2433);

  // --- Metric-specific gradient pairs ---
  static const List<Color> gradientCpu = [Color(0xFF22D3EE), Color(0xFF3B82F6)];
  static const List<Color> gradientRam = [Color(0xFFA855F7), Color(0xFFEC4899)];
  static const List<Color> gradientDisk = [
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];
  static const List<Color> gradientNet = [Color(0xFF14B8A6), Color(0xFF22D3EE)];
  static const List<Color> gradientGpu = [Color(0xFF10B981), Color(0xFF14B8A6)];
  static const List<Color> gradientAccent = [
    Color(0xFF22D3EE),
    Color(0xFF6366F1),
  ];

  // --- Convenience helpers ---
  static Color usageColor(double percent) {
    if (percent < 60) return green;
    if (percent < 85) return orange;
    return red;
  }

  static List<Color> usageGradient(double percent) {
    if (percent < 60) return [green, greenSoft];
    if (percent < 85) return [orange, amber];
    return [red, redSoft];
  }

  static Color tempColor(double t) {
    if (t < 60) return green;
    if (t < 80) return orange;
    return red;
  }
}

class ZShadows {
  static List<BoxShadow> glow(
    Color color, {
    double blur = 24,
    double spread = -8,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.25),
        blurRadius: blur,
        spreadRadius: spread,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> softElevation = const [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 24,
      spreadRadius: -12,
      offset: Offset(0, 12),
    ),
  ];

  static List<BoxShadow> hairlineGlow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: 8,
        spreadRadius: 0,
        offset: Offset.zero,
      ),
    ];
  }
}

class ZRadii {
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius inner = BorderRadius.all(Radius.circular(8));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(6));
}
