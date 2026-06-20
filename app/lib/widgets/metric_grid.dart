import 'package:flutter/material.dart';

import 'metric_card.dart';

class MetricGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const MetricGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  int _columnCount(double width) {
    if (width >= 1000) return 4;
    if (width >= 640) return 3;
    return 2;
  }

  Widget _normalize(Widget child) {
    if (child is MetricCard && child.expand) {
      return MetricCard(
        key: child.key,
        label: child.label,
        value: child.value,
        unit: child.unit,
        percent: child.percent,
        icon: child.icon,
        gradient: child.gradient,
        expand: false,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = _columnCount(constraints.maxWidth);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final end = (i + cols > children.length) ? children.length : i + cols;
          final rowChildren = children.sublist(i, end).map(_normalize).toList();
          while (rowChildren.length < cols) {
            rowChildren.add(const SizedBox.shrink());
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < rowChildren.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(child: rowChildren[j]),
                ],
              ],
            ),
          );
          if (end < children.length) {
            rows.add(SizedBox(height: runSpacing));
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
