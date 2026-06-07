import 'package:uuid/uuid.dart';

enum TransactionType { cashIn, cashOut, bankIn, bankOut, bankTransfer }

class BankAccount {
  String id;
  String bankName;
  String accountNumber;
  String ifscCode;
  String branch;
  String accountHolder;
  double balance;
  final DateTime updatedAt;

  BankAccount({
    String? id,
    required this.bankName,
    required this.accountNumber,
    this.ifscCode = '',
    this.branch = '',
    this.accountHolder = '',
    this.balance = 0.0,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'ifscCode': ifscCode,
    'branch': branch,
    'accountHolder': accountHolder,
    'balance': balance,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BankAccount.fromMap(Map<String, dynamic> map) => BankAccount(
    id: map['id'] as String,
    bankName: map['bankName'] as String? ?? '',
    accountNumber: map['accountNumber'] as String? ?? '',
    ifscCode: map['ifscCode'] as String? ?? '',
    branch: map['branch'] as String? ?? '',
    accountHolder: map['accountHolder'] as String? ?? '',
    balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
  );
}

class CashBookEntry {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final String? reference; // bill number, receipt number, etc.
  final String? bankAccountId;
  final String? category;
  final DateTime date;
  final DateTime updatedAt;

  CashBookEntry({
    String? id,
    required this.type,
    required this.amount,
    required this.description,
    this.reference,
    this.bankAccountId,
    this.category,
    DateTime? date,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isInflow => type == TransactionType.cashIn || type == TransactionType.bankIn;

  String get typeLabel {
    switch (type) {
      case TransactionType.cashIn: return 'Cash In';
      case TransactionType.cashOut: return 'Cash Out';
      case TransactionType.bankIn: return 'Bank Deposit';
      case TransactionType.bankOut: return 'Bank Withdrawal';
      case TransactionType.bankTransfer: return 'Bank Transfer';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'description': description,
    'reference': reference,
    'bankAccountId': bankAccountId,
    'category': category,
    'date': date.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CashBookEntry.fromMap(Map<String, dynamic> map) => CashBookEntry(
    id: map['id'] as String,
    type: TransactionType.values.firstWhere(
      (e) => e.name == map['type'], orElse: () => TransactionType.cashIn),
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    description: map['description'] as String? ?? '',
    reference: map['reference'] as String?,
    bankAccountId: map['bankAccountId'] as String?,
    category: map['category'] as String?,
    date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
  );
}


