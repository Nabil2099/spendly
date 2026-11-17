import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/l10n/l10n.dart';
import '../../ai_advisor/presentation/ai_advisor_screen.dart';
import '../../ai_advisor/presentation/ai_chat_cubit.dart';
import '../../ai_advisor/presentation/widgets/spendi_avatar.dart';
import '../data/expense_model.dart';
import 'expense_cubit.dart';
import 'widgets/category_badge.dart';
import 'widgets/month_picker_row.dart';

enum _StatsTab { overview, categories }

/// Calm, eye-comfortable Analytics & Statistics screen with 2 focused sub-views.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _StatsTab _tab = _StatsTab.overview;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseCubit, ExpenseState>(
      builder: (context, state) {
        final categoryEntries = state.categoryTotalsMinor.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.analytics,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  MonthSelector(
                    selectedMonth: state.selectedMonth,
                    onChanged: (month) =>
                        context.read<ExpenseCubit>().selectMonth(month),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatsTabBar(
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 18),
              if (state.isLoading && state.expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: switch (_tab) {
                    _StatsTab.overview => _OverviewSection(
                      key: const ValueKey('overview'),
                      state: state,
                      categoryEntries: categoryEntries,
                      onViewAllCategories: () =>
                          setState(() => _tab = _StatsTab.categories),
                    ),
                    _StatsTab.categories => _CategoriesSection(
                      key: const ValueKey('categories'),
                      entries: categoryEntries,
                      totalMinor: state.monthlyTotalMinor,
                    ),
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsTabBar extends StatelessWidget {
  const _StatsTabBar({required this.selected, required this.onChanged});

  final _StatsTab selected;
  final ValueChanged<_StatsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.greenTint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _TabPill(
            label: context.l10n.overview,
            selected: selected == _StatsTab.overview,
            onTap: () => onChanged(_StatsTab.overview),
          ),
          _TabPill(
            label: context.l10n.categories,
            selected: selected == _StatsTab.categories,
            onTap: () => onChanged(_StatsTab.categories),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? context.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.primaryGreen : context.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    super.key,
    required this.state,
    required this.categoryEntries,
    required this.onViewAllCategories,
  });

  final ExpenseState state;
  final List<MapEntry<ExpenseCategory, int>> categoryEntries;
  final VoidCallback onViewAllCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UnifiedSummaryCard(state: state),
        const SizedBox(height: 18),
        _AiBriefCard(expenseState: state),
        const SizedBox(height: 18),
        _TopCategoriesCard(
          entries: categoryEntries.take(3).toList(),
          totalMinor: state.monthlyTotalMinor,
          onViewAll: onViewAllCategories,
        ),
      ],
    );
  }
}

class _UnifiedSummaryCard extends StatelessWidget {
  const _UnifiedSummaryCard({required this.state});

  final ExpenseState state;

  @override
  Widget build(BuildContext context) {
    final highestDay = state.highestSpendingDay;
    final avgMinor = state.averageTransactionMinor;
    final topTitle = state.topExpenseTitle;
    final txCount = state.monthlyExpenses.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month Total',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MoneyFormatter.formatEgp(state.monthlyTotalMinor),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.greenTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$txCount expense${txCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: context.borderColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: AppColors.terracotta,
                    label: 'Highest Day',
                    value: highestDay != null
                        ? MoneyFormatter.formatEgp(highestDay.totalMinor)
                        : '—',
                    hint: highestDay != null
                        ? DateFormat.MMMd().format(highestDay.day)
                        : 'No data',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.calculate_rounded,
                    iconColor: AppColors.slateBlue,
                    label: 'Avg Spend',
                    value: txCount > 0
                        ? MoneyFormatter.formatEgp(avgMinor)
                        : '—',
                    hint: 'Per item',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.storefront_rounded,
                    iconColor: AppColors.mutedSage,
                    label: 'Top Item',
                    value: topTitle != null ? topTitle.title : '—',
                    hint: topTitle != null ? '${topTitle.count}x' : 'No data',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({
    required this.entries,
    required this.totalMinor,
    required this.onViewAll,
  });

  final List<MapEntry<ExpenseCategory, int>> entries;
  final int totalMinor;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Categories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty || totalMinor <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No spending recorded for this month yet.',
                  style: TextStyle(color: context.textSecondary),
                ),
              )
            else
              ...entries.map(
                (entry) =>
                    _CategoryProgressRow(entry: entry, totalMinor: totalMinor),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesSection extends StatefulWidget {
  const _CategoriesSection({
    super.key,
    required this.entries,
    required this.totalMinor,
  });

  final List<MapEntry<ExpenseCategory, int>> entries;
  final int totalMinor;

  @override
  State<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<_CategoriesSection> {
  bool _showDonut = true;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final totalMinor = widget.totalMinor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category Breakdown',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (entries.isNotEmpty && totalMinor > 0)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Donut')),
                      ButtonSegment(value: false, label: Text('Bars')),
                    ],
                    selected: {_showDonut},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onSelectionChanged: (val) =>
                        setState(() => _showDonut = val.first),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty || totalMinor <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No expenses recorded for this month.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              )
            else ...[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showDonut
                    ? SizedBox(
                        key: const ValueKey('donut'),
                        height: 175,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 42,
                            sectionsSpace: 3,
                            sections: entries.map((entry) {
                              final pct = (entry.value / totalMinor * 100)
                                  .round();
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
                      )
                    : SizedBox(
                        key: const ValueKey('bars'),
                        height: 175,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 100,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
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
                                    final pct =
                                        (entries[idx].value / totalMinor * 100)
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
                                  reservedSize: 26,
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
                                    width: 28,
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
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: context.borderColor),
              const SizedBox(height: 12),
              ...entries.map(
                (entry) =>
                    _CategoryProgressRow(entry: entry, totalMinor: totalMinor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({required this.entry, required this.totalMinor});

  final MapEntry<ExpenseCategory, int> entry;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final ratio = entry.value / totalMinor;
    final pct = (ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CategoryBadge(category: entry.key, size: 36, iconSize: 18),
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
  }
}

class _AiBriefCard extends StatefulWidget {
  const _AiBriefCard({required this.expenseState});

  final ExpenseState expenseState;

  @override
  State<_AiBriefCard> createState() => _AiBriefCardState();
}

class _AiBriefCardState extends State<_AiBriefCard> {
  void _requestBrief({bool forceRefresh = false}) {
    final lang = Localizations.localeOf(context).languageCode;
    context.read<AiChatCubit>().generateMonthlyBrief(
      widget.expenseState,
      languageCode: lang,
      forceRefresh: forceRefresh,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestBrief();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    final aiState = context.read<AiChatCubit>().state;
    if (aiState.briefLanguageCode != null &&
        aiState.briefLanguageCode != lang) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestBrief();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AiBriefCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenseState.selectedMonthKey !=
        widget.expenseState.selectedMonthKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestBrief();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiChatCubit, AiChatState>(
      builder: (context, aiState) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SpendiAvatar(
                      pose: aiState.isLoadingBrief
                          ? SpendiPose.thinking
                          : SpendiPose.advising,
                      size: 54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.aiSpendingBrief,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            context.l10n.spendiAiInsights,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (aiState.isConfigured)
                      IconButton(
                        tooltip: 'Refresh brief',
                        onPressed: aiState.isLoadingBrief
                            ? null
                            : () => _requestBrief(forceRefresh: true),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.assistant),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.slateBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        context.l10n.askAi,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.greenTint.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!aiState.isConfigured)
                        Text(
                          'Add `GEMINI_API_KEY` to `.env` to unlock automatic AI spending briefs and tips.',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
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
                              onPressed: () =>
                                  _requestBrief(forceRefresh: true),
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
                            onPressed: () => _requestBrief(),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                            ),
                            label: const Text('Generate AI Brief'),
                          ),
                        ),
                    ],
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
