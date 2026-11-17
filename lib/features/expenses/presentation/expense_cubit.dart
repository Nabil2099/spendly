import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/preferences_service.dart';
import '../../../core/utils/money_formatter.dart';
import '../../budget/data/budget_repository.dart';
import '../../currency/data/exchange_rate_service.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

class ExpenseState {
  const ExpenseState({
    required this.selectedMonth,
    this.expenses = const [],
    this.budget,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.searchQuery = '',
    this.categoryFilter,
    this.filterBySelectedMonth = true,
    this.lastCategory = ExpenseCategory.food,
    this.exchangeRate,
  });

  final DateTime selectedMonth;
  final List<Expense> expenses;
  final MonthlyBudget? budget;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String searchQuery;
  final ExpenseCategory? categoryFilter;
  final bool filterBySelectedMonth;
  final ExpenseCategory lastCategory;
  final ExchangeRate? exchangeRate;

  String get selectedMonthKey => MoneyFormatter.monthKey(selectedMonth);

  /// Expenses belonging to [selectedMonth], sorted newest first.
  List<Expense> get monthlyExpenses {
    return expenses
        .where(
          (e) =>
              e.date.year == selectedMonth.year &&
              e.date.month == selectedMonth.month,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Total spending in minor units (piasters) for [selectedMonth].
  int get monthlyTotalMinor =>
      monthlyExpenses.fold(0, (sum, e) => sum + e.amountMinor);

  int? get budgetLimitMinor => budget?.limitMinor;

  int? get remainingBudgetMinor {
    final limit = budgetLimitMinor;
    if (limit == null) return null;
    return limit - monthlyTotalMinor;
  }

  /// Ratio in `[0.0, ...]` where `1.0` means 100% of budget used.
  double? get budgetRatio {
    final limit = budgetLimitMinor;
    if (limit == null || limit <= 0) return null;
    return monthlyTotalMinor / limit;
  }

  /// Up to 4 most recent expenses for the Dashboard.
  List<Expense> get recentExpenses => monthlyExpenses.take(4).toList();

  /// Spending breakdown by category for [selectedMonth].
  Map<ExpenseCategory, int> get categoryTotalsMinor {
    final totals = <ExpenseCategory, int>{};
    for (final expense in monthlyExpenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amountMinor;
    }
    return totals;
  }

  /// 6-month spending window ending at [selectedMonth] (oldest to newest).
  List<({DateTime month, int totalMinor})> get sixMonthTotalsMinor {
    final result = <({DateTime month, int totalMinor})>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(
        selectedMonth.year,
        selectedMonth.month - offset,
        1,
      );
      final total = expenses
          .where(
            (e) => e.date.year == month.year && e.date.month == month.month,
          )
          .fold<int>(0, (sum, e) => sum + e.amountMinor);
      result.add((month: month, totalMinor: total));
    }
    return result;
  }

  /// Calendar day in [selectedMonth] with the highest total spending.
  ({DateTime day, int totalMinor})? get highestSpendingDay {
    if (monthlyExpenses.isEmpty) return null;
    final dayTotals = <DateTime, int>{};
    for (final e in monthlyExpenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      dayTotals[day] = (dayTotals[day] ?? 0) + e.amountMinor;
    }
    MapEntry<DateTime, int>? best;
    for (final entry in dayTotals.entries) {
      if (best == null || entry.value > best.value) {
        best = entry;
      }
    }
    if (best == null) return null;
    return (day: best.key, totalMinor: best.value);
  }

  /// Average spending per transaction in [selectedMonth].
  int get averageTransactionMinor {
    final count = monthlyExpenses.length;
    if (count == 0) return 0;
    return (monthlyTotalMinor / count).round();
  }

  /// Highest-total expense title/merchant in [selectedMonth].
  ({String title, int totalMinor, int count})? get topExpenseTitle {
    if (monthlyExpenses.isEmpty) return null;
    final totals = <String, ({String display, int totalMinor, int count})>{};
    for (final e in monthlyExpenses) {
      final normalized = e.title.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      final existing = totals[normalized];
      if (existing == null) {
        totals[normalized] = (
          display: e.title.trim(),
          totalMinor: e.amountMinor,
          count: 1,
        );
      } else {
        totals[normalized] = (
          display: existing.display,
          totalMinor: existing.totalMinor + e.amountMinor,
          count: existing.count + 1,
        );
      }
    }
    ({String display, int totalMinor, int count})? best;
    for (final entry in totals.values) {
      if (best == null || entry.totalMinor > best.totalMinor) {
        best = entry;
      }
    }
    if (best == null) return null;
    return (
      title: best.display,
      totalMinor: best.totalMinor,
      count: best.count,
    );
  }

  /// Filtered list for the Transactions screen.
  List<Expense> get filteredTransactions {
    final query = searchQuery.trim().toLowerCase();
    final list = expenses.where((expense) {
      if (filterBySelectedMonth &&
          (expense.date.year != selectedMonth.year ||
              expense.date.month != selectedMonth.month)) {
        return false;
      }
      if (categoryFilter != null && expense.category != categoryFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final inTitle = expense.title.toLowerCase().contains(query);
        final inNote = expense.note.toLowerCase().contains(query);
        if (!inTitle && !inNote) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  ExpenseState copyWith({
    DateTime? selectedMonth,
    List<Expense>? expenses,
    MonthlyBudget? budget,
    bool clearBudget = false,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    ExpenseCategory? categoryFilter,
    bool clearCategoryFilter = false,
    bool? filterBySelectedMonth,
    ExpenseCategory? lastCategory,
    ExchangeRate? exchangeRate,
  }) {
    return ExpenseState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      expenses: expenses ?? this.expenses,
      budget: clearBudget ? null : (budget ?? this.budget),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: clearCategoryFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      filterBySelectedMonth:
          filterBySelectedMonth ?? this.filterBySelectedMonth,
      lastCategory: lastCategory ?? this.lastCategory,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }
}

class ExpenseCubit extends Cubit<ExpenseState> {
  ExpenseCubit({
    required this._expenseRepository,
    required this._budgetRepository,
    this._exchangeRateService,
    PreferencesService? preferencesService,
  }) : _preferencesService = preferencesService,
       super(
         ExpenseState(
           selectedMonth: _initialMonth(preferencesService),
           lastCategory: ExpenseCategory.fromId(
             preferencesService?.getLastCategoryId(),
           ),
         ),
       );

  final ExpenseRepository _expenseRepository;
  final BudgetRepository _budgetRepository;
  final ExchangeRateService? _exchangeRateService;
  final PreferencesService? _preferencesService;

  String? _uid;
  StreamSubscription<List<Expense>>? _expensesSub;
  StreamSubscription<MonthlyBudget?>? _budgetSub;

  static DateTime _initialMonth(PreferencesService? prefs) {
    final saved = prefs?.getSelectedMonthKey();
    final parsed = saved != null ? MoneyFormatter.parseMonthKey(saved) : null;
    if (parsed != null) return parsed;
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Binds Firestore streams for [uid], or clears state when [uid] is null.
  Future<void> bindUser(String? uid) async {
    if (_uid == uid && uid != null) return;
    _uid = uid;
    await _cancelSubscriptions();

    if (uid == null) {
      emit(
        ExpenseState(
          selectedMonth: state.selectedMonth,
          lastCategory: state.lastCategory,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    _subscribeExpenses(uid);
    _subscribeBudget(uid, state.selectedMonthKey);
    unawaited(refreshExchangeRate());
  }

  void _subscribeExpenses(String uid) {
    _expensesSub = _expenseRepository
        .watchExpenses(uid)
        .listen(
          (items) {
            emit(
              state.copyWith(
                expenses: items,
                isLoading: false,
                clearError: true,
              ),
            );
          },
          onError: (_) {
            emit(
              state.copyWith(
                isLoading: false,
                errorMessage: 'Could not load expenses. Please try again.',
              ),
            );
          },
        );
  }

  void _subscribeBudget(String uid, String monthKey) {
    _budgetSub?.cancel();
    _budgetSub = _budgetRepository
        .watchBudget(uid, monthKey)
        .listen(
          (budget) {
            emit(state.copyWith(budget: budget, clearBudget: budget == null));
          },
          onError: (_) {
            // Keep current UI usable even if budget listener errors transiently.
          },
        );
  }

  Future<void> selectMonth(DateTime month) async {
    final normalized = DateTime(month.year, month.month, 1);
    final key = MoneyFormatter.monthKey(normalized);
    emit(state.copyWith(selectedMonth: normalized, clearBudget: true));
    await _preferencesService?.setSelectedMonthKey(key);
    final uid = _uid;
    if (uid != null) {
      _subscribeBudget(uid, key);
    }
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setCategoryFilter(ExpenseCategory? category) {
    if (category == null) {
      emit(state.copyWith(clearCategoryFilter: true));
    } else {
      emit(state.copyWith(categoryFilter: category));
    }
  }

  void setFilterBySelectedMonth(bool value) {
    emit(state.copyWith(filterBySelectedMonth: value));
  }

  Future<void> refreshExchangeRate() async {
    final service = _exchangeRateService;
    if (service == null) return;
    final rate = await service.getEgpToUsd();
    if (rate != null && !isClosed) {
      emit(state.copyWith(exchangeRate: rate));
    }
  }

  /// Adds a new expense or updates [existing] when provided.
  /// Returns `true` on success, `false` on error.
  Future<bool> saveExpense({
    Expense? existing,
    required String title,
    required int amountMinor,
    required ExpenseCategory category,
    required DateTime date,
    String note = '',
    List<ExpenseItem> items = const [],
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final now = DateTime.now();
      if (existing == null) {
        final expense = Expense(
          id: '',
          title: title.trim(),
          amountMinor: amountMinor,
          category: category,
          date: date,
          note: note.trim(),
          items: items,
          createdAt: now,
          updatedAt: now,
        );
        await _expenseRepository.addExpense(uid, expense);
      } else {
        final updated = existing.copyWith(
          title: title.trim(),
          amountMinor: amountMinor,
          category: category,
          date: date,
          note: note.trim(),
          items: items,
          updatedAt: now,
        );
        await _expenseRepository.updateExpense(uid, updated);
      }

      await _preferencesService?.setLastCategoryId(category.id);
      emit(state.copyWith(isSaving: false, lastCategory: category));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save expense. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      await _expenseRepository.deleteExpense(uid, expenseId);
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to delete expense. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> setMonthlyBudget(int limitMinor) async {
    final uid = _uid;
    if (uid == null) return false;

    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _budgetRepository.setBudget(
        uid,
        state.selectedMonthKey,
        limitMinor,
      );
      emit(state.copyWith(isSaving: false));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to update budget. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _expensesSub?.cancel();
    _expensesSub = null;
    await _budgetSub?.cancel();
    _budgetSub = null;
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
