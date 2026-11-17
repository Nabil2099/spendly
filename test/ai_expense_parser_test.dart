import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/features/ai_advisor/data/gemini_chat_service.dart';
import 'package:spendly/features/expenses/data/expense_model.dart';
import 'package:spendly/features/expenses/presentation/expense_cubit.dart';
import 'package:spendly/features/expenses/presentation/expense_form_screen.dart';
import 'package:spendly/features/expenses/presentation/widgets/expense_list_tile.dart';

import 'expense_cubit_test.dart';

void main() {
  test('ParsedExpenseDraft.fromJsonString parses plain and fenced JSON', () {
    final fallback = DateTime(2026, 11, 17, 10, 30);
    const fenced = '''
```json
{
  "title": "Uber",
  "amount": 145.5,
  "category": "transport",
  "date": "2026-11-16",
  "note": "Airport ride"
}
```
''';

    final draft = ParsedExpenseDraft.fromJsonString(
      fenced,
      fallbackDate: fallback,
    );

    expect(draft.title, 'Uber');
    expect(draft.amountMinor, 14550);
    expect(draft.category, ExpenseCategory.transport);
    expect(draft.date.year, 2026);
    expect(draft.date.month, 11);
    expect(draft.date.day, 16);
    expect(draft.note, 'Airport ride');
  });

  test('ParsedExpenseDraft.fromJsonString falls back safely on invalid date', () {
    final fallback = DateTime(2026, 11, 17, 10, 30);
    const json = '{"title":"Coffee","amount":65,"category":"unknown","date":"bad"}';

    final draft = ParsedExpenseDraft.fromJsonString(
      json,
      fallbackDate: fallback,
    );

    expect(draft.title, 'Coffee');
    expect(draft.amountMinor, 6500);
    expect(draft.category, ExpenseCategory.other);
    expect(draft.date, fallback);
  });

  test('ParsedExpenseDraft.parseReceiptList parses multiple receipt items', () {
    const json = '''
{
  "items": [
    {"title": "Latte", "amount": 75, "category": "food", "date": "2026-11-17"},
    {"title": "Croissant", "amount": 45.5, "category": "food", "date": "2026-11-17"}
  ]
}
''';

    final items = ParsedExpenseDraft.parseReceiptList(json);
    expect(items.length, 2);
    expect(items[0].title, 'Latte');
    expect(items[0].amountMinor, 7500);
    expect(items[1].title, 'Croissant');
    expect(items[1].amountMinor, 4550);
  });

  testWidgets('ExpenseFormScreen prefills fields from initialDraft', (
    tester,
  ) async {
    final expenseRepo = FakeExpenseRepository();
    final budgetRepo = FakeBudgetRepository();
    addTearDown(() async {
      await expenseRepo.dispose();
      await budgetRepo.dispose();
    });

    final draft = ParsedExpenseDraft(
      title: 'Carrefour',
      amountMinor: 32050,
      category: ExpenseCategory.food,
      date: DateTime(2026, 11, 16),
      note: 'Weekly groceries',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ExpenseCubit(
            expenseRepository: expenseRepo,
            budgetRepository: budgetRepo,
          ),
          child: ExpenseFormScreen(initialDraft: draft),
        ),
      ),
    );

    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('320.50'), findsOneWidget);
    expect(find.text('Carrefour'), findsOneWidget);
    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('ExpenseListTile expands and shrinks itemized receipt items', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 17, 12, 0);
    final receipt = Expense(
      id: 'rec_1',
      title: 'Cafe Receipt',
      amountMinor: 12050,
      category: ExpenseCategory.food,
      date: now,
      items: const [
        ExpenseItem(
          title: 'Latte',
          amountMinor: 7500,
          category: ExpenseCategory.food,
        ),
        ExpenseItem(
          title: 'Croissant',
          amountMinor: 4550,
          category: ExpenseCategory.food,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseListTile(expense: receipt, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Cafe Receipt'), findsOneWidget);
    expect(find.text('Latte'), findsNothing);

    await tester.tap(find.text('Cafe Receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('Croissant'), findsOneWidget);

    await tester.tap(find.text('Cafe Receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Latte'), findsNothing);
  });
}

