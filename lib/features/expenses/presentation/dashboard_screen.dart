import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/utils/money_formatter.dart';
import '../../ai_advisor/data/gemini_chat_service.dart';
import '../../profile/presentation/profile_cubit.dart';
import '../data/expense_model.dart';
import 'expense_cubit.dart';
import 'widgets/budget_dialog.dart';
import 'widgets/expense_list_tile.dart';
import 'widgets/month_picker_row.dart';
import 'widgets/receipt_scanner_helper.dart';
import 'widgets/spending_category_chart.dart';

/// Main Dashboard screen showing monthly total, budget ring, category chart, and recent expenses.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTransactions});

  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseCubit, ExpenseState>(
      builder: (context, state) {
        return RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => context.read<ExpenseCubit>().refreshExchangeRate(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DashboardHeader(selectedMonth: state.selectedMonth),
                const SizedBox(height: 14),
                if (state.errorMessage != null) ...[
                  _ErrorBanner(message: state.errorMessage!),
                  const SizedBox(height: 14),
                ],
                _FadeSlideIn(delayMs: 40, child: _SummaryCard(state: state)),
                const SizedBox(height: 12),
                const _FadeSlideIn(delayMs: 80, child: _AiQuickAddBar()),
                const SizedBox(height: 16),
                if (state.isLoading && state.expenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _FadeSlideIn(
                    delayMs: 120,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isTablet = constraints.maxWidth >= 680;
                        final chartCard = SpendingCategoryChart(
                          expenses: state.monthlyExpenses,
                          categoryTotalsMinor: state.categoryTotalsMinor,
                          totalMinor: state.monthlyTotalMinor,
                          selectedMonth: state.selectedMonth,
                          onSeeAll: onOpenTransactions,
                        );
                        final recentCard = _RecentTransactionsCard(
                          expenses: state.recentExpenses,
                          onSeeAll: onOpenTransactions,
                          onTapExpense: (expense) =>
                              _openExpenseForm(context, existing: expense),
                        );

                        if (isTablet) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: chartCard),
                              const SizedBox(width: 16),
                              Expanded(child: recentCard),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            chartCard,
                            const SizedBox(height: 16),
                            recentCard,
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openExpenseForm(BuildContext context, {Expense? existing}) {
    if (existing == null) {
      context.push(AppRoutes.expenseNew);
    } else {
      context.push(AppRoutes.expenseEdit, extra: existing);
    }
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.selectedMonth});

  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final profile = context.select((ProfileCubit cubit) => cubit.state.profile);
    final photoBytes = _decodePhoto(profile?.photoBase64);
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spendly',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (profile != null && profile.name.isNotEmpty)
                    Text(
                      'Hi, ${profile.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isDark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: () {
                    context.read<ThemeCubit>().toggleDarkMode(!isDark);
                  },
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => context.push(AppRoutes.profile),
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: context.greenTint,
                    backgroundImage: photoBytes != null
                        ? MemoryImage(photoBytes)
                        : null,
                    child: photoBytes == null
                        ? const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primaryGreen,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        MonthSelector(
          selectedMonth: selectedMonth,
          onChanged: (month) => context.read<ExpenseCubit>().selectMonth(month),
        ),
      ],
    );
  }

  Uint8List? _decodePhoto(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final ExpenseState state;

  Future<void> _editBudget(BuildContext context) async {
    final monthLabel = DateFormat.yMMMM().format(state.selectedMonth);
    final result = await showBudgetDialog(
      context,
      currentLimitMinor: state.budgetLimitMinor,
      monthLabel: monthLabel,
    );
    if (result != null && context.mounted) {
      await context.read<ExpenseCubit>().setMonthlyBudget(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMinor = state.monthlyTotalMinor;
    final budgetMinor = state.budgetLimitMinor;
    final remainingMinor = state.remainingBudgetMinor;
    final ratio = state.budgetRatio;
    final rate = state.exchangeRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreen, Color(0xFF0A5C47)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Spending',
                      style: TextStyle(
                        color: Color(0xFFD6EAE3),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: totalMinor.toDouble()),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Text(
                          MoneyFormatter.formatEgp(value.round()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        );
                      },
                    ),
                    if (rate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Approx. ${MoneyFormatter.formatApproxUsd(totalMinor, rate.rate)} (${rate.date})',
                        style: const TextStyle(
                          color: Color(0xFFC2DFD5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ratio != null) _BudgetProgressRing(ratio: ratio),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 14),
          if (budgetMinor == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'No monthly budget set yet.',
                    style: TextStyle(color: Color(0xFFD6EAE3), fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editBudget(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Set Budget'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _editBudget(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Budget',
                              style: TextStyle(
                                color: Color(0xFFD6EAE3),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: Color(0xFFD6EAE3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MoneyFormatter.formatEgp(budgetMinor),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (remainingMinor ?? 0) >= 0
                            ? 'Remaining'
                            : 'Over Budget',
                        style: const TextStyle(
                          color: Color(0xFFD6EAE3),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        MoneyFormatter.formatEgp((remainingMinor ?? 0).abs()),
                        style: TextStyle(
                          color: (remainingMinor ?? 0) >= 0
                              ? Colors.white
                              : AppColors.sandyAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetProgressRing extends StatelessWidget {
  const _BudgetProgressRing({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final isOver = ratio > 1.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedRatio, _) {
        final clamped = animatedRatio.clamp(0.0, 1.0);
        final pct = (animatedRatio * 100).round();
        return SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: clamped,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: isOver
                      ? AppColors.sandyAccent
                      : const Color(0xFFB7E4C7),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _AiQuickAddBar extends StatefulWidget {
  const _AiQuickAddBar();

  @override
  State<_AiQuickAddBar> createState() => _AiQuickAddBarState();
}

class _AiQuickAddBarState extends State<_AiQuickAddBar> {
  final _controller = TextEditingController();
  bool _isBusy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parseText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isBusy) return;

    setState(() => _isBusy = true);
    try {
      final draft = await getIt<GeminiChatService>().parseExpenseFromText(text);
      if (!mounted) return;
      _controller.clear();
      setState(() => _isBusy = false);
      context.push(AppRoutes.expenseNew, extra: draft);
    } on GeminiFailure catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse expense. Try again.')),
      );
    }
  }

  Future<void> _scanReceipt() async {
    if (_isBusy) return;
    try {
      final drafts = await pickAndScanReceipt(
        context,
        onParsingStarted: () {
          if (mounted) setState(() => _isBusy = true);
        },
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (drafts == null || drafts.isEmpty) return;

      if (drafts.length == 1) {
        context.push(AppRoutes.expenseNew, extra: drafts.first);
      } else {
        await showReceiptItemsSheet(context, drafts);
      }
    } on GeminiFailure catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not scan receipt. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isBusy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _parseText(),
                decoration: const InputDecoration(
                  hintText: 'Quick add: "Coffee 65 yesterday"',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6),
                  isDense: true,
                ),
              ),
            ),
            if (_isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Parse with AI',
                onPressed: _parseText,
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'Scan receipt with AI',
                onPressed: _scanReceipt,
                icon: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.slateBlue,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.expenses,
    required this.onSeeAll,
    required this.onTapExpense,
  });

  final List<Expense> expenses;
  final VoidCallback onSeeAll;
  final ValueChanged<Expense> onTapExpense;

  @override
  Widget build(BuildContext context) {
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
                    'Recent Transactions',
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
            const SizedBox(height: 6),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No expenses recorded for this month.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              )
            else
              ...expenses.map(
                (expense) => ExpenseListTile(
                  expense: expense,
                  showFullDate: true,
                  onTap: () => onTapExpense(expense),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.danger, fontSize: 13),
      ),
    );
  }
}
