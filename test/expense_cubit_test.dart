import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/utils/money_formatter.dart';
import 'package:spendly/features/budget/data/budget_repository.dart';
import 'package:spendly/features/expenses/data/expense_model.dart';
import 'package:spendly/features/expenses/data/expense_repository.dart';
import 'package:spendly/features/expenses/presentation/expense_cubit.dart';

class FakeExpenseRepository implements ExpenseRepository {
  final _controller = StreamController<List<Expense>>.broadcast();
  final List<Expense> _items = [];
  int _nextId = 1;

  void _emit() => _controller.add(List.unmodifiable(_items));

  @override
  Stream<List<Expense>> watchExpenses(String uid) {
    Future.microtask(_emit);
    return _controller.stream;
  }

  @override
  Future<void> addExpense(String uid, Expense expense) async {
    _items.add(expense.copyWith(id: 'id_${_nextId++}'));
    _emit();
  }

  @override
  Future<void> updateExpense(String uid, Expense expense) async {
    final idx = _items.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      _items[idx] = expense;
      _emit();
    }
  }

  @override
  Future<void> deleteExpense(String uid, String expenseId) async {
    _items.removeWhere((e) => e.id == expenseId);
    _emit();
  }

  Future<void> dispose() => _controller.close();
}

class FakeBudgetRepository implements BudgetRepository {
  final _controller = StreamController<MonthlyBudget?>.broadcast();
  final Map<String, MonthlyBudget> _budgets = {};

  @override
  Stream<MonthlyBudget?> watchBudget(String uid, String monthKey) {
    Future.microtask(() => _controller.add(_budgets[monthKey]));
    return _controller.stream;
  }

  @override
  Future<void> setBudget(String uid, String monthKey, int limitMinor) async {
    final budget = MonthlyBudget(
      monthKey: monthKey,
      limitMinor: limitMinor,
      updatedAt: DateTime.now(),
    );
    _budgets[monthKey] = budget;
    _controller.add(budget);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  late FakeExpenseRepository expenseRepo;
  late FakeBudgetRepository budgetRepo;
  late ExpenseCubit cubit;

  setUp(() {
    expenseRepo = FakeExpenseRepository();
    budgetRepo = FakeBudgetRepository();
    cubit = ExpenseCubit(
      expenseRepository: expenseRepo,
      budgetRepository: budgetRepo,
    );
  });

  tearDown(() async {
    await cubit.close();
    await expenseRepo.dispose();
    await budgetRepo.dispose();
  });

  test('adds, edits, deletes expenses and computes monthly budget', () async {
    await cubit.bindUser('user_1');
    final now = DateTime.now();
    await cubit.selectMonth(DateTime(now.year, now.month, 1));

    final added = await cubit.saveExpense(
      title: 'Coffee',
      amountMinor: 4500,
      category: ExpenseCategory.food,
      date: now,
    );
    expect(added, isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.expenses.length, 1);
    expect(cubit.state.monthlyTotalMinor, 4500);

    await cubit.setMonthlyBudget(20000);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.budgetLimitMinor, 20000);
    expect(cubit.state.remainingBudgetMinor, 15500);

    final existing = cubit.state.expenses.first;
    final updated = await cubit.saveExpense(
      existing: existing,
      title: 'Specialty Coffee',
      amountMinor: 6000,
      category: ExpenseCategory.food,
      date: now,
    );
    expect(updated, isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.expenses.first.title, 'Specialty Coffee');
    expect(cubit.state.monthlyTotalMinor, 6000);
    expect(cubit.state.remainingBudgetMinor, 14000);

    // Search & category filter
    cubit.setSearchQuery('specialty');
    expect(cubit.state.filteredTransactions.length, 1);
    cubit.setCategoryFilter(ExpenseCategory.transport);
    expect(cubit.state.filteredTransactions, isEmpty);
    cubit.setCategoryFilter(null);
    cubit.setSearchQuery('');

    final deleted = await cubit.deleteExpense(existing.id);
    expect(deleted, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.expenses, isEmpty);
    expect(cubit.state.monthlyTotalMinor, 0);
    expect(cubit.state.selectedMonthKey, MoneyFormatter.monthKey(now));
  });

  test(
    'computes 6-month totals, highest day, average, and top title',
    () async {
      await cubit.bindUser('user_1');
      final targetMonth = DateTime(2026, 11, 1);
      await cubit.selectMonth(targetMonth);

      await cubit.saveExpense(
        title: 'Coffee',
        amountMinor: 5000,
        category: ExpenseCategory.food,
        date: DateTime(2026, 11, 10, 9),
      );
      await cubit.saveExpense(
        title: 'coffee',
        amountMinor: 7000,
        category: ExpenseCategory.food,
        date: DateTime(2026, 11, 10, 14),
      );
      await cubit.saveExpense(
        title: 'Uber',
        amountMinor: 9000,
        category: ExpenseCategory.transport,
        date: DateTime(2026, 11, 12, 18),
      );
      await cubit.saveExpense(
        title: 'Internet',
        amountMinor: 30000,
        category: ExpenseCategory.bills,
        date: DateTime(2026, 9, 5),
      );
      await Future<void>.delayed(Duration.zero);

      final sixMonths = cubit.state.sixMonthTotalsMinor;
      expect(sixMonths.length, 6);
      expect(sixMonths.first.month, DateTime(2026, 6, 1));
      expect(sixMonths.last.month, DateTime(2026, 11, 1));
      expect(sixMonths[3].totalMinor, 30000); // Sep 2026
      expect(sixMonths.last.totalMinor, 21000); // Nov 2026

      expect(cubit.state.highestSpendingDay?.day, DateTime(2026, 11, 10));
      expect(cubit.state.highestSpendingDay?.totalMinor, 12000);
      expect(cubit.state.averageTransactionMinor, 7000);
      expect(cubit.state.topExpenseTitle?.title.toLowerCase(), 'coffee');
      expect(cubit.state.topExpenseTitle?.totalMinor, 12000);
      expect(cubit.state.topExpenseTitle?.count, 2);
    },
  );
}
