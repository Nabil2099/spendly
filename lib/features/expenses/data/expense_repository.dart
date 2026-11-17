import 'package:cloud_firestore/cloud_firestore.dart';

import 'expense_model.dart';

/// Contract for reading and mutating a user's expenses.
abstract class ExpenseRepository {
  Stream<List<Expense>> watchExpenses(String uid);
  Future<void> addExpense(String uid, Expense expense);
  Future<void> updateExpense(String uid, Expense expense);
  Future<void> deleteExpense(String uid, String expenseId);
}

/// Cloud Firestore implementation scoped under `users/{uid}/expenses/{expenseId}`.
class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('expenses');
  }

  @override
  Stream<List<Expense>> watchExpenses(String uid) {
    return _collection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Expense.fromFirestore).toList());
  }

  @override
  Future<void> addExpense(String uid, Expense expense) async {
    final doc = _collection(uid).doc();
    final now = DateTime.now();
    await doc.set(
      expense
          .copyWith(id: doc.id, createdAt: now, updatedAt: now)
          .toFirestore(),
    );
  }

  @override
  Future<void> updateExpense(String uid, Expense expense) async {
    await _collection(uid)
        .doc(expense.id)
        .update(expense.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  @override
  Future<void> deleteExpense(String uid, String expenseId) async {
    await _collection(uid).doc(expenseId).delete();
  }
}
