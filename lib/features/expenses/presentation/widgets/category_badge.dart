import 'package:flutter/material.dart';

import '../../data/expense_model.dart';

/// Soft-tinted icon badge for an [ExpenseCategory].
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 42,
    this.iconSize = 20,
  });

  final ExpenseCategory category;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(category.icon, color: category.color, size: iconSize),
    );
  }
}
