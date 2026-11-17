import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/features/expenses/data/expense_model.dart';

void main() {
  test('Expense.fromMap and toFirestore map fields accurately', () {
    final now = DateTime(2026, 11, 17, 14, 30);
    final expense = Expense(
      id: 'exp_1',
      title: 'Lunch',
      amountMinor: 8500,
      category: ExpenseCategory.food,
      date: now,
      note: 'With team',
      createdAt: now,
      updatedAt: now,
    );

    final firestoreMap = expense.toFirestore();
    expect(firestoreMap['title'], 'Lunch');
    expect(firestoreMap['amountMinor'], 8500);
    expect(firestoreMap['currency'], 'EGP');
    expect(firestoreMap['category'], 'food');
    expect(firestoreMap['date'], isA<Timestamp>());
    expect(firestoreMap['note'], 'With team');

    final restored = Expense.fromMap('exp_1', firestoreMap);
    expect(restored.id, 'exp_1');
    expect(restored.title, 'Lunch');
    expect(restored.amountMinor, 8500);
    expect(restored.category, ExpenseCategory.food);
    expect(restored.note, 'With team');
    expect(restored.date, now);
  });

  test('ExpenseCategory.fromId falls back to other for unknown ids', () {
    expect(ExpenseCategory.fromId('transport'), ExpenseCategory.transport);
    expect(ExpenseCategory.fromId('unknown_cat'), ExpenseCategory.other);
    expect(ExpenseCategory.fromId(null), ExpenseCategory.other);
  });

  test('Expense serializes and restores itemized receipt items', () {
    final now = DateTime(2026, 11, 17, 15, 0);
    final receipt = Expense(
      id: 'rec_1',
      title: 'Carrefour',
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

    final map = receipt.toFirestore();
    final restored = Expense.fromMap('rec_1', map);

    expect(restored.items.length, 2);
    expect(restored.items[0].title, 'Latte');
    expect(restored.items[0].amountMinor, 7500);
    expect(restored.items[1].title, 'Croissant');
    expect(restored.items[1].amountMinor, 4550);
  });
}
