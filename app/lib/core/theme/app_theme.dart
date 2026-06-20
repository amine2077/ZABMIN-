import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'zcolors.dart';

class ZText {
  static TextStyle display = GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -1.2,
    color: ZColors.textPrimary,
  );

  static TextStyle metric = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.8,
    color: ZColors.textPrimary,
  );

  static TextStyle metricSm = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.4,
    color: ZColors.textPrimary,
  );

  static TextStyle title = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: ZColors.textPrimary,
  );

  static TextStyle section = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: ZColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: ZColors.textPrimary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: ZColors.textSecondary,
  );

  static TextStyle micro = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: ZColors.textTertiary,
  );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: ZColors.textPrimary,
      height: 1.2,
    );
  }
}

class ZTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ZColors.background,
    colorScheme: const ColorScheme.dark(
      primary: ZColors.accent,
      secondary: ZColors.purple,
      surface: ZColors.surface,
      error: ZColors.red,
    ),
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}

class ZPaints {
  static BoxDecoration glass({
    Color? surface,
    BorderRadius? radius,
    Color? borderColor,
    List<BoxShadow>? shadow,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: surface ?? ZColors.surface,
      borderRadius: radius ?? ZRadii.card,
      border: Border.all(color: borderColor ?? ZColors.border),
      boxShadow: shadow ?? ZShadows.softElevation,
      gradient: gradient,
    );
  }

  static BoxDecoration gradientCard({
    required List<Color> colors,
    BorderRadius? radius,
    double opacity = 1.0,
  }) {
    return BoxDecoration(
      borderRadius: radius ?? ZRadii.card,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.map((c) => c.withValues(alpha: opacity)).toList(),
      ),
      border: Border.all(color: ZColors.borderStrong),
      boxShadow: ZShadows.glow(colors.last),
    );
  }
}
