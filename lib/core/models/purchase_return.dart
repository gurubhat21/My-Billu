import 'package:uuid/uuid.dart';
import 'purchase.dart';

class PurchaseReturn {
  final String id;
  final String returnNumber;
  final String? purchaseId;
  final String? purchaseNumber;
  final String supplierName;
  final List<PurchaseItem> items;
  final double subtotal;
  final double totalTax;
  final double totalAmount;
  final String reason;
  final String? notes;
  final PurchaseReturnStatus status;
  final DateTime createdAt;

  PurchaseReturn({
    String? id,
    required this.returnNumber,
    this.purchaseId,
    this.purchaseNumber,
    required this.supplierName,
    required this.items,
    required this.subtotal,
    required this.totalTax,
    required this.totalAmount,
    required this.reason,
    this.notes,
    this.status = PurchaseReturnStatus.returned,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'returnNumber': returnNumber,
    'purchaseId': purchaseId,
    'purchaseNumber': purchaseNumber,
    'supplierName': supplierName,
    'items': items.map((e) => e.toMap()).toList(),
    'subtotal': subtotal,
    'totalTax': totalTax,
    'totalAmount': totalAmount,
    'reason': reason,
    'notes': notes,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PurchaseReturn.fromMap(Map<String, dynamic> map) => PurchaseReturn(
    id: map['id'] as String,
    returnNumber: map['returnNumber'] as String,
    purchaseId: map['purchaseId'] as String?,
    purchaseNumber: map['purchaseNumber'] as String?,
    supplierName: map['supplierName'] as String? ?? '',
    items: (map['items'] as List).map((e) => PurchaseItem.fromMap(e as Map<String, dynamic>)).toList(),
    subtotal: (map['subtotal'] as num).toDouble(),
    totalTax: (map['totalTax'] as num).toDouble(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    reason: map['reason'] as String? ?? '',
    notes: map['notes'] as String?,
    status: PurchaseReturnStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => PurchaseReturnStatus.returned),
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}

enum PurchaseReturnStatus { returned, refunded, cancelled }
