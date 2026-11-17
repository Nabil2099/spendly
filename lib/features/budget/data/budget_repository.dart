import 'package:cloud_firestore/cloud_firestore.dart';

/// Monthly budget stored in `users/{uid}/budgets/{yyyy-MM}`.
class MonthlyBudget {
  const MonthlyBudget({
    required this.monthKey,
    required this.limitMinor,
    this.currency = 'EGP',
    required this.updatedAt,
  });

  final String monthKey;
  final int limitMinor;
  final String currency;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'limitMinor': limitMinor,
      'currency': currency,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MonthlyBudget.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawUpdated = data['updatedAt'];
    final updatedAt = rawUpdated is Timestamp
        ? rawUpdated.toDate()
        : DateTime.now();
    return MonthlyBudget(
      monthKey: doc.id,
      limitMinor: (data['limitMinor'] as num?)?.toInt() ?? 0,
      currency: (data['currency'] as String?) ?? 'EGP',
      updatedAt: updatedAt,
    );
  }
}

/// Contract for reading and saving monthly budgets.
abstract class BudgetRepository {
  Stream<MonthlyBudget?> watchBudget(String uid, String monthKey);
  Future<void> setBudget(String uid, String monthKey, int limitMinor);
}

/// Cloud Firestore implementation scoped under `users/{uid}/budgets/{yyyy-MM}`.
class FirestoreBudgetRepository implements BudgetRepository {
  FirestoreBudgetRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String monthKey) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(monthKey);
  }

  @override
  Stream<MonthlyBudget?> watchBudget(String uid, String monthKey) {
    return _doc(uid, monthKey).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return MonthlyBudget.fromFirestore(snapshot);
    });
  }

  @override
  Future<void> setBudget(String uid, String monthKey, int limitMinor) async {
    final budget = MonthlyBudget(
      monthKey: monthKey,
      limitMinor: limitMinor,
      updatedAt: DateTime.now(),
    );
    await _doc(uid, monthKey).set(budget.toFirestore());
  }
}
