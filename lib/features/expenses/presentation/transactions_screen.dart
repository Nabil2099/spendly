import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../data/expense_model.dart';
import 'expense_cubit.dart';
import 'expense_form_screen.dart';
import 'widgets/expense_list_tile.dart';

/// All expenses screen with search, category/month filters, and date grouping.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<ExpenseCubit>().state.searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Delete "${expense.title}" (${MoneyFormatter.formatEgp(expense.amountMinor)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ExpenseCubit>().deleteExpense(expense.id);
    }
  }

  void _openEdit(Expense expense) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ExpenseFormScreen(existing: expense),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseCubit, ExpenseState>(
      builder: (context, state) {
        final filtered = state.filteredTransactions;
        final grouped = _groupByDay(filtered);
        final cubit = context.read<ExpenseCubit>();
        final monthChipLabel = DateFormat.MMM().format(state.selectedMonth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transactions',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: cubit.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                cubit.setSearchQuery('');
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: state.categoryFilter == null,
                          onTap: () => cubit.setCategoryFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: state.filterBySelectedMonth
                              ? monthChipLabel
                              : 'All Months',
                          selected: state.filterBySelectedMonth,
                          onTap: () => cubit.setFilterBySelectedMonth(
                            !state.filterBySelectedMonth,
                          ),
                        ),
                        ...ExpenseCategory.values.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterChip(
                              label: cat.label,
                              icon: cat.icon,
                              selected: state.categoryFilter == cat,
                              onTap: () => cubit.setCategoryFilter(
                                state.categoryFilter == cat ? null : cat,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.expenses.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.errorMessage != null && state.expenses.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    );
                  }
                  if (grouped.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: AppColors.mutedSage,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              state.expenses.isEmpty
                                  ? 'No expenses recorded yet.'
                                  : 'No matching transactions.',
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try adjusting your filters or tap + to add an expense.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 116),
                    itemCount: grouped.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final group = grouped[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDayHeader(group.day),
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    MoneyFormatter.formatEgp(
                                      group.totalMinor,
                                      signed: true,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...group.items.map(
                                (expense) => ExpenseListTile(
                                  expense: expense,
                                  onTap: () => _openEdit(expense),
                                  onDelete: () => _confirmDelete(expense),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<_DayGroup> _groupByDay(List<Expense> items) {
    final groups = <DateTime, List<Expense>>{};
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      groups.putIfAbsent(day, () => []).add(item);
    }
    final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedDays.map((day) {
      final list = groups[day]!;
      final total = list.fold<int>(0, (sum, e) => sum + e.amountMinor);
      return _DayGroup(day: day, items: list, totalMinor: total);
    }).toList();
  }

  String _formatDayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final formatted = DateFormat.yMMMd().format(day);
    if (day == today) return 'Today, $formatted';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $formatted';
    }
    return formatted;
  }
}

class _DayGroup {
  const _DayGroup({
    required this.day,
    required this.items,
    required this.totalMinor,
  });

  final DateTime day;
  final List<Expense> items;
  final int totalMinor;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : context.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : context.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
