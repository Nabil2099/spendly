import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/expense_model.dart';

/// Bar chart card displaying monthly spending percentages by category.
class SpendingCategoryChart extends StatelessWidget {
  const SpendingCategoryChart({
    super.key,
    required this.categoryTotalsMinor,
    required this.totalMinor,
    required this.onSeeAll,
  });

  final Map<ExpenseCategory, int> categoryTotalsMinor;
  final int totalMinor;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotalsMinor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Show top 5 categories as bars so labels stay readable on mobile & tablet.
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
                    'Spending by Category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onSeeAll,
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
            const SizedBox(height: 12),
            if (visibleEntries.isEmpty || totalMinor <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No category data for this month yet.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              )
            else
              SizedBox(
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
                          final cat = visibleEntries[group.x].key;
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
                            if (idx < 0 || idx >= visibleEntries.length) {
                              return const SizedBox.shrink();
                            }
                            final pct =
                                (visibleEntries[idx].value / totalMinor * 100)
                                    .round();
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
                            if (idx < 0 || idx >= visibleEntries.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                visibleEntries[idx].key.label,
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
                    barGroups: List.generate(visibleEntries.length, (i) {
                      final entry = visibleEntries[i];
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
              ),
          ],
        ),
      ),
    );
  }
}
