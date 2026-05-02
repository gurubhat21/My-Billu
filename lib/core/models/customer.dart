import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  String name;
  String? phone;
  String? email;
  String? address;
  String? gstin;
  double totalPurchases;
  double outstandingBalance;
  DateTime createdAt;
  DateTime updatedAt;

  Customer({
    String? id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.totalPurchases = 0.0,
    this.outstandingBalance = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gstin': gstin,
      'totalPurchases': totalPurchases,
      'outstandingBalance': outstandingBalance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      gstin: map['gstin'] as String?,
      totalPurchases: (map['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (map['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    double? totalPurchases,
    double? outstandingBalance,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
