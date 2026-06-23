import 'package:delime/theme/app_theme.dart';
import 'package:delime/utils/categories.dart';
import 'package:flutter/material.dart';

/// A small icon + label chip showing a purchase's category, used in the
/// purchase list.
class CategoryChip extends StatelessWidget {
  final String category;

  const CategoryChip({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ExpenseCategory.iconFor(category),
            size: 13,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            category,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
