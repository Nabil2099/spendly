import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../data/expense_model.dart';

enum _ChartMode { bars, donut, trend }

/// Spending charts and statistics card powered by `fl_chart`.
class SpendingCategoryChart extends StatefulWidget {
  const SpendingCategoryChart({
    super.key,
    required this.expenses,
    required this.categoryTotalsMinor,
    required this.totalMinor,
    required this.selectedMonth,
    required this.onSeeAll,
  });

  final List<Expense> expenses;
  final Map<ExpenseCategory, int> categoryTotalsMinor;
  final int totalMinor;
  final DateTime selectedMonth;
  final VoidCallback onSeeAll;

  @override
  State<SpendingCategoryChart> createState() => _SpendingCategoryChartState();
}

class _SpendingCategoryChartState extends State<SpendingCategoryChart> {
  _ChartMode _mode = _ChartMode.bars;

  @override
  Widget build(BuildContext context) {
    final entries = widget.categoryTotalsMinor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visibleEntries = entries.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Spending & Statistics',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ModeSwitcher(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(height: 14),
            if (visibleEntries.isEmpty || widget.totalMinor <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No category data for this month yet.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              )
            else ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: switch (_mode) {
                  _ChartMode.bars => _CategoryBarChart(
                    key: const ValueKey('bars'),
                    entries: visibleEntries,
                    totalMinor: widget.totalMinor,
                  ),
                  _ChartMode.donut => _CategoryDonutChart(
                    key: const ValueKey('donut'),
                    entries: visibleEntries,
                    totalMinor: widget.totalMinor,
                  ),
                  _ChartMode.trend => _DailyTrendLineChart(
                    key: const ValueKey('trend'),
                    expenses: widget.expenses,
                    selectedMonth: widget.selectedMonth,
                  ),
                },
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: context.borderColor),
              const SizedBox(height: 12),
              _QuickStatsRow(
                expenses: widget.expenses,
                totalMinor: widget.totalMinor,
                topCategory: entries.first.key,
                selectedMonth: widget.selectedMonth,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});

  final _ChartMode mode;
  final ValueChanged<_ChartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.greenTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Bars',
            selected: mode == _ChartMode.bars,
            onTap: () => onChanged(_ChartMode.bars),
          ),
          _TabButton(
            label: 'Donut',
            selected: mode == _ChartMode.donut,
            onTap: () => onChanged(_ChartMode.donut),
          ),
          _TabButton(
            label: 'Trend',
            selected: mode == _ChartMode.trend,
            onTap: () => onChanged(_ChartMode.trend),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? context.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.primaryGreen : context.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  const _CategoryBarChart({
    super.key,
    required this.entries,
    required this.totalMinor,
  });

  final List<MapEntry<ExpenseCategory, int>> entries;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 165,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.darkPlum,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final cat = entries[group.x].key;
                return BarTooltipItem(
                  '${cat.label}: ${rod.toY.round()}%',
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
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final pct = (entries[idx].value / totalMinor * 100).round();
                  return Text(
                    '$pct%',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      entries[idx].key.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(entries.length, (i) {
            final entry = entries[i];
            final pct = (entry.value / totalMinor) * 100;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: pct.clamp(4, 100).toDouble(),
                  width: 34,
                  color: entry.key.color,
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
    );
  }
}

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({
    super.key,
    required this.entries,
    required this.totalMinor,
  });

  final List<MapEntry<ExpenseCategory, int>> entries;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 165,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 36,
                sectionsSpace: 3,
                sections: entries.map((entry) {
                  final pct = (entry.value / totalMinor * 100).round();
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: entry.key.color,
                    radius: 32,
                    title: pct >= 10 ? '$pct%' : '',
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
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.key.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key.label,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendLineChart extends StatelessWidget {
  const _DailyTrendLineChart({
    super.key,
    required this.expenses,
    required this.selectedMonth,
  });

  final List<Expense> expenses;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
      selectedMonth.year,
      selectedMonth.month,
    );
    final dailyTotals = List<double>.filled(daysInMonth + 1, 0);
    for (final e in expenses) {
      if (e.date.day >= 1 && e.date.day <= daysInMonth) {
        dailyTotals[e.date.day] += e.amountMinor / 100.0;
      }
    }

    final spots = <FlSpot>[];
    var maxVal = 0.0;
    for (var day = 1; day <= daysInMonth; day++) {
      final val = dailyTotals[day];
      if (val > maxVal) maxVal = val;
      spots.add(FlSpot(day.toDouble(), val));
    }

    return SizedBox(
      height: 165,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: daysInMonth.toDouble(),
          minY: 0,
          maxY: math.max(maxVal * 1.2, 10),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.borderColor, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false),
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
                interval: 7,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final d = value.toInt();
                  if (d < 1 || d > daysInMonth) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$d',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primaryGreen,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primaryGreen.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.expenses,
    required this.totalMinor,
    required this.topCategory,
    required this.selectedMonth,
  });

  final List<Expense> expenses;
  final int totalMinor;
  final ExpenseCategory topCategory;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        now.year == selectedMonth.year && now.month == selectedMonth.month;
    final elapsedDays = isCurrentMonth
        ? now.day
        : DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
    final dailyAvgMinor = (totalMinor / math.max(elapsedDays, 1)).round();

    return Row(
      children: [
        Expanded(
          child: _StatPill(
            label: 'Daily Avg',
            value: MoneyFormatter.formatEgp(dailyAvgMinor),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(label: 'Top Category', value: topCategory.label),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(label: 'Expenses', value: '${expenses.length}'),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.greenTint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
