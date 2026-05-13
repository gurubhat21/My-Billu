import 'package:uuid/uuid.dart';

class Supplier {
  final String id;
  String name;
  String? phone;
  String? email;
  String? address;
  String? gstin;
  double totalPurchases;
  double outstandingBalance;
  DateTime createdAt;

  Supplier({
    String? id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.totalPurchases = 0.0,
    this.outstandingBalance = 0.0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'phone': phone, 'email': email,
    'address': address, 'gstin': gstin, 'totalPurchases': totalPurchases,
    'outstandingBalance': outstandingBalance, 'createdAt': createdAt.toIso8601String(),
  };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
    id: map['id'] as String, name: map['name'] as String,
    phone: map['phone'] as String?, email: map['email'] as String?,
    address: map['address'] as String?, gstin: map['gstin'] as String?,
    totalPurchases: (map['totalPurchases'] as num?)?.toDouble() ?? 0.0,
    outstandingBalance: (map['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}


