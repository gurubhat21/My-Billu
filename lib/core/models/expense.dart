import 'package:uuid/uuid.dart';

enum ExpenseCategory {
  rent,
  salary,
  electricity,
  water,
  internet,
  transport,
  packaging,
  maintenance,
  marketing,
  insurance,
  tax,
  office,
  misc,
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.rent: return 'Rent';
      case ExpenseCategory.salary: return 'Salary / Wages';
      case ExpenseCategory.electricity: return 'Electricity';
      case ExpenseCategory.water: return 'Water';
      case ExpenseCategory.internet: return 'Internet / Phone';
      case ExpenseCategory.transport: return 'Transport / Fuel';
      case ExpenseCategory.packaging: return 'Packaging';
      case ExpenseCategory.maintenance: return 'Maintenance / Repair';
      case ExpenseCategory.marketing: return 'Marketing / Ads';
      case ExpenseCategory.insurance: return 'Insurance';
      case ExpenseCategory.tax: return 'Tax / License Fee';
      case ExpenseCategory.office: return 'Office Supplies';
      case ExpenseCategory.misc: return 'Miscellaneous';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseCategory.rent: return '🏠';
      case ExpenseCategory.salary: return '👤';
      case ExpenseCategory.electricity: return '⚡';
      case ExpenseCategory.water: return '💧';
      case ExpenseCategory.internet: return '📶';
      case ExpenseCategory.transport: return '🚗';
      case ExpenseCategory.packaging: return '📦';
      case ExpenseCategory.maintenance: return '🔧';
      case ExpenseCategory.marketing: return '📢';
      case ExpenseCategory.insurance: return '🛡️';
      case ExpenseCategory.tax: return '🏛️';
      case ExpenseCategory.office: return '📎';
      case ExpenseCategory.misc: return '📋';
    }
  }
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;

  Expense({
    String? id,
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
    DateTime? date,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category.name,
    'notes': notes,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as String,
    title: map['title'] as String,
    amount: (map['amount'] as num).toDouble(),
    category: ExpenseCategory.values.firstWhere(
      (e) => e.name == map['category'],
      orElse: () => ExpenseCategory.misc,
    ),
    notes: map['notes'] as String?,
    date: DateTime.parse(map['date'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}


