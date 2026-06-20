import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AnimatedMetric extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final int decimals;
  final String suffix;
  final Duration duration;

  const AnimatedMetric({
    super.key,
    required this.value,
    this.style,
    this.decimals = 1,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = decimals == 0
            ? v.round().toString()
            : v.toStringAsFixed(decimals);
        return Text(
          suffix.isEmpty ? text : '$text$suffix',
          style: style ?? ZText.metric,
        );
      },
    );
  }
}

class AnimatedMetricInt extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  const AnimatedMetricInt({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: value, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = v.toString();
        return Text(
          suffix.isEmpty ? text : '$text$suffix',
          style: style ?? ZText.metric,
        );
      },
    );
  }
}
