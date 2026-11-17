import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Allowed expense categories from `Agentic/PROJECT_SCOPE.md`.
enum ExpenseCategory {
  food(
    'food',
    'Food',
    Icons.restaurant_rounded,
    Color(0xFFE1B07E),
    Color(0xFFF6EBDF),
  ),
  transport(
    'transport',
    'Transport',
    Icons.directions_bus_rounded,
    Color(0xFF4D8EA8),
    Color(0xFFE6F1F5),
  ),
  bills(
    'bills',
    'Bills',
    Icons.receipt_long_rounded,
    Color(0xFF8C7DBB),
    Color(0xFFEEEAF7),
  ),
  shopping(
    'shopping',
    'Shopping',
    Icons.shopping_bag_rounded,
    Color(0xFFD9879C),
    Color(0xFFFAECF0),
  ),
  health(
    'health',
    'Health',
    Icons.favorite_rounded,
    Color(0xFFC96868),
    Color(0xFFF9EAEA),
  ),
  entertainment(
    'entertainment',
    'Entertainment',
    Icons.play_circle_rounded,
    Color(0xFF6B7AA1),
    Color(0xFFEAEEF5),
  ),
  other(
    'other',
    'Other',
    Icons.category_rounded,
    Color(0xFF86A397),
    Color(0xFFEBF1EE),
  );

  const ExpenseCategory(
    this.id,
    this.label,
    this.icon,
    this.color,
    this.backgroundColor,
  );

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  static ExpenseCategory fromId(String? id) {
    return ExpenseCategory.values.firstWhere(
      (cat) => cat.id == id,
      orElse: () => ExpenseCategory.other,
    );
  }

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case ExpenseCategory.food:
        return l10n.catFood;
      case ExpenseCategory.transport:
        return l10n.catTransport;
      case ExpenseCategory.bills:
        return l10n.catBills;
      case ExpenseCategory.shopping:
        return l10n.catShopping;
      case ExpenseCategory.health:
        return l10n.catHealth;
      case ExpenseCategory.entertainment:
        return l10n.catEntertainment;
      case ExpenseCategory.other:
        return l10n.catOther;
    }
  }
}

/// Individual line item inside an itemized receipt [Expense].
class ExpenseItem {
  const ExpenseItem({
    required this.title,
    required this.amountMinor,
    this.category = ExpenseCategory.other,
  });

  final String title;
  final int amountMinor;
  final ExpenseCategory category;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amountMinor': amountMinor,
      'category': category.id,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      title: (map['title'] as String?) ?? '',
      amountMinor: (map['amountMinor'] as num?)?.toInt() ?? 0,
      category: ExpenseCategory.fromId(map['category'] as String?),
    );
  }
}

/// Expense record stored in `users/{uid}/expenses/{expenseId}`.
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amountMinor,
    this.currency = 'EGP',
    required this.category,
    required this.date,
    this.note = '',
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int amountMinor;
  final String currency;
  final ExpenseCategory category;
  final DateTime date;
  final String note;
  final List<ExpenseItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense copyWith({
    String? id,
    String? title,
    int? amountMinor,
    String? currency,
    ExpenseCategory? category,
    DateTime? date,
    String? note,
    List<ExpenseItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amountMinor': amountMinor,
      'currency': currency,
      'category': category.id,
      'date': Timestamp.fromDate(date),
      'note': note,
      'items': items.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(ExpenseItem.fromMap)
              .toList()
        : const <ExpenseItem>[];

    return Expense(
      id: id,
      title: (map['title'] as String?) ?? '',
      amountMinor: (map['amountMinor'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String?) ?? 'EGP',
      category: ExpenseCategory.fromId(map['category'] as String?),
      date: _readDate(map['date']),
      note: (map['note'] as String?) ?? '',
      items: items,
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Expense.fromMap(doc.id, doc.data() ?? const {});
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
