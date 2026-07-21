import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import 'glass_card.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int resultCount;
  final int totalCount;
  final String hintText;

  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.resultCount,
    required this.totalCount,
    this.hintText = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverable: false,
      padding: EdgeInsets.zero,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: ZColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: ZText.body,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: hintText,
                  hintStyle:
                      ZText.body.copyWith(color: ZColors.textTertiary),
                ),
              ),
            ),
            if (totalCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZColors.accent.withValues(alpha: 0.1),
                  borderRadius: ZRadii.pill,
                ),
                child: Text(
                  '$resultCount / $totalCount',
                  style: ZText.caption.copyWith(
                    color: ZColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (controller.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  borderRadius: ZRadii.inner,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: ZColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
