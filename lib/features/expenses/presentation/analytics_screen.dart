import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../ai_advisor/presentation/ai_advisor_screen.dart';
import '../../ai_advisor/presentation/ai_chat_cubit.dart';
import '../data/expense_model.dart';
import 'expense_cubit.dart';
import 'widgets/category_badge.dart';
import 'widgets/month_picker_row.dart';

/// Dedicated Analytics & Statistics screen powered by `fl_chart`.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseCubit, ExpenseState>(
      builder: (context, state) {
        final sixMonthData = state.sixMonthTotalsMinor;
        final categoryEntries = state.categoryTotalsMinor.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Analytics',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: MonthSelector(
                  selectedMonth: state.selectedMonth,
                  onChanged: (month) =>
                      context.read<ExpenseCubit>().selectMonth(month),
                ),
              ),
              const SizedBox(height: 14),
              if (state.isLoading && state.expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _KeyMetricsGrid(state: state),
                const SizedBox(height: 16),
                _AiBriefCard(expenseState: state),
                const SizedBox(height: 16),
                _SixMonthComparisonCard(
                  months: sixMonthData,
                  selectedMonth: state.selectedMonth,
                ),
                const SizedBox(height: 16),
                _CategoryBreakdownCard(
                  entries: categoryEntries,
                  totalMinor: state.monthlyTotalMinor,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KeyMetricsGrid extends StatelessWidget {
  const _KeyMetricsGrid({required this.state});

  final ExpenseState state;

  @override
  Widget build(BuildContext context) {
    final highestDay = state.highestSpendingDay;
    final avgMinor = state.averageTransactionMinor;
    final topTitle = state.topExpenseTitle;
    final txCount = state.monthlyExpenses.length;

    final cards = [
      _MetricTile(
        icon: Icons.local_fire_department_rounded,
        iconColor: AppColors.terracotta,
        label: 'Highest Day',
        value: highestDay != null
            ? MoneyFormatter.formatEgp(highestDay.totalMinor)
            : '—',
        subtitle: highestDay != null
            ? DateFormat.MMMd().format(highestDay.day)
            : 'No expenses',
      ),
      _MetricTile(
        icon: Icons.calculate_rounded,
        iconColor: AppColors.slateBlue,
        label: 'Avg Transaction',
        value: txCount > 0 ? MoneyFormatter.formatEgp(avgMinor) : '—',
        subtitle: '$txCount expense${txCount == 1 ? '' : 's'}',
      ),
      _MetricTile(
        icon: Icons.storefront_rounded,
        iconColor: AppColors.mutedSage,
        label: 'Top Expense',
        value: topTitle != null ? topTitle.title : '—',
        subtitle: topTitle != null
            ? '${MoneyFormatter.formatEgp(topTitle.totalMinor)} (${topTitle.count}x)'
            : 'No expenses',
      ),
      _MetricTile(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.primaryGreen,
        label: 'Month Total',
        value: MoneyFormatter.formatEgp(state.monthlyTotalMinor),
        subtitle: DateFormat.yMMM().format(state.selectedMonth),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        final tileWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(width: tileWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBriefCard extends StatefulWidget {
  const _AiBriefCard({required this.expenseState});

  final ExpenseState expenseState;

  @override
  State<_AiBriefCard> createState() => _AiBriefCardState();
}

class _AiBriefCardState extends State<_AiBriefCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiChatCubit>().generateMonthlyBrief(widget.expenseState);
    });
  }

  @override
  void didUpdateWidget(covariant _AiBriefCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenseState.selectedMonthKey !=
        widget.expenseState.selectedMonthKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AiChatCubit>().generateMonthlyBrief(widget.expenseState);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiChatCubit, AiChatState>(
      builder: (context, aiState) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.slateBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.slateBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI Spending Brief',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (aiState.isConfigured)
                      IconButton(
                        tooltip: 'Refresh brief',
                        onPressed: aiState.isLoadingBrief
                            ? null
                            : () => context
                                  .read<AiChatCubit>()
                                  .generateMonthlyBrief(
                                    widget.expenseState,
                                    forceRefresh: true,
                                  ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.assistant),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.slateBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text(
                        'Ask AI',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!aiState.isConfigured)
                  Text(
                    'Add `GEMINI_API_KEY` to `.env` to unlock automatic AI spending briefs and tips.',
                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                  )
                else if (aiState.isLoadingBrief)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Analyzing your month...',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                else if (aiState.briefError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          aiState.briefError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context
                            .read<AiChatCubit>()
                            .generateMonthlyBrief(
                              widget.expenseState,
                              forceRefresh: true,
                            ),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else if (aiState.briefText != null)
                  FormattedAiText(
                    text: aiState.briefText!,
                    baseStyle: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context
                          .read<AiChatCubit>()
                          .generateMonthlyBrief(widget.expenseState),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Generate AI Brief'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SixMonthComparisonCard extends StatelessWidget {
  const _SixMonthComparisonCard({
    required this.months,
    required this.selectedMonth,
  });

  final List<({DateTime month, int totalMinor})> months;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final maxMinor = months.fold<int>(
      0,
      (maxVal, item) => math.max(maxVal, item.totalMinor),
    );
    final hasData = maxMinor > 0;
    final maxY = hasData ? (maxMinor / 100.0) * 1.2 : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '6-Month Comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Monthly spending trend in EGP',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'Add expenses to see your 6-month comparison.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              )
            else
              SizedBox(
                height: 185,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: context.borderColor, strokeWidth: 0.8),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.darkPlum,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = months[group.x];
                          return BarTooltipItem(
                            '${DateFormat.MMM().format(item.month)}: ${MoneyFormatter.formatEgp(item.totalMinor)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= months.length) {
                              return const SizedBox.shrink();
                            }
                            final item = months[idx];
                            final isSelected =
                                item.month.year == selectedMonth.year &&
                                item.month.month == selectedMonth.month;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat.MMM().format(item.month),
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : context.textSecondary,
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(months.length, (i) {
                      final item = months[i];
                      final isSelected =
                          item.month.year == selectedMonth.year &&
                          item.month.month == selectedMonth.month;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: item.totalMinor / 100.0,
                            width: 26,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.mutedSage,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.entries,
    required this.totalMinor,
  });

  final List<MapEntry<ExpenseCategory, int>> entries;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty || totalMinor <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No expenses recorded for this month.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 170,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 42,
                    sectionsSpace: 3,
                    sections: entries.map((entry) {
                      final pct = (entry.value / totalMinor * 100).round();
                      return PieChartSectionData(
                        value: entry.value.toDouble(),
                        color: entry.key.color,
                        radius: 34,
                        title: pct >= 8 ? '$pct%' : '',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...entries.map((entry) {
                final ratio = entry.value / totalMinor;
                final pct = (ratio * 100).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      CategoryBadge(
                        category: entry.key,
                        size: 36,
                        iconSize: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key.label,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${MoneyFormatter.formatEgp(entry.value)} ($pct%)',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: context.borderColor,
                                color: entry.key.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
