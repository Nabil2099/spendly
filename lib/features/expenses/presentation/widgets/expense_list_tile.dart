import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../data/expense_model.dart';
import 'category_badge.dart';

/// Single expense row (with smooth expand/shrink for itemized receipts).
class ExpenseListTile extends StatefulWidget {
  const ExpenseListTile({
    super.key,
    required this.expense,
    required this.onTap,
    this.onDelete,
    this.showFullDate = false,
  });

  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showFullDate;

  @override
  State<ExpenseListTile> createState() => _ExpenseListTileState();
}

class _ExpenseListTileState extends State<ExpenseListTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final hasItems = expense.items.isNotEmpty;
    final subtitle = widget.showFullDate
        ? _formatRelativeDateTime(expense.date)
        : DateFormat.jm().format(expense.date);

    final detailText = hasItems
        ? '$subtitle · ${expense.items.length} items'
        : (expense.note.isNotEmpty ? '$subtitle · ${expense.note}' : subtitle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: hasItems
              ? () => setState(() => _expanded = !_expanded)
              : widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                CategoryBadge(category: expense.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  MoneyFormatter.formatEgp(expense.amountMinor, signed: true),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasItems) ...[
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: context.textSecondary,
                    ),
                  ),
                ],
                if (widget.onDelete != null) ...[
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: context.textSecondary,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        widget.onTap();
                      } else if (value == 'delete') {
                        widget.onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasItems)
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Container(
                    margin: const EdgeInsets.only(
                      left: 16,
                      right: 8,
                      bottom: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.greenTint.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      children: expense.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CategoryBadge(
                                category: item.category,
                                size: 26,
                                iconSize: 14,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                MoneyFormatter.formatEgp(item.amountMinor),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  static String _formatRelativeDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final time = DateFormat.jm().format(date);
    if (target == today) return 'Today, $time';
    if (target == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${DateFormat.MMMd().format(date)}, $time';
  }
}
