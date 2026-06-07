import 'package:uuid/uuid.dart';
import 'bill.dart';

class PurchaseItem {
  final String itemId;
  final String itemName;
  final double unitCost;
  final int quantity;
  final double taxRate;
  final String unit;
  final String? description;
  final String? serialNumber;

  PurchaseItem({
    required this.itemId,
    required this.itemName,
    required this.unitCost,
    required this.quantity,
    required this.taxRate,
    this.unit = 'pcs',
    this.description,
    this.serialNumber,
  });

  double get subtotal => unitCost * quantity;
  double get taxAmount => subtotal * taxRate / 100;
  double get total => subtotal + taxAmount;

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'unitCost': unitCost,
    'quantity': quantity,
    'taxRate': taxRate,
    'unit': unit,
    if (description != null) 'description': description,
    if (serialNumber != null) 'serialNumber': serialNumber,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
    itemId: map['itemId'] as String,
    itemName: map['itemName'] as String,
    unitCost: (map['unitCost'] as num).toDouble(),
    quantity: (map['quantity'] as num).toInt(),
    taxRate: (map['taxRate'] as num).toDouble(),
    unit: map['unit'] as String? ?? 'pcs',
    description: map['description'] as String?,
    serialNumber: map['serialNumber'] as String?,
  );
}

enum PurchaseStatus { received, pending, cancelled }

class Purchase {
  final String id;
  final String purchaseNumber;
  final String supplierName;
  final String? supplierPhone;
  final String? supplierGstin;
  final String? invoiceNumber;
  final List<PurchaseItem> items;
  final double subtotal;
  final double totalTax;
  final double totalAmount;
  double paidAmount;
  PurchaseStatus status;
  PaymentMethod paymentMethod;
  String? notes;
  DateTime createdAt;
  final DateTime updatedAt;

  Purchase({
    String? id,
    required this.purchaseNumber,
    required this.supplierName,
    this.supplierPhone,
    this.supplierGstin,
    this.invoiceNumber,
    required this.items,
    required this.subtotal,
    required this.totalTax,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.status = PurchaseStatus.received,
    this.paymentMethod = PaymentMethod.cash,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get balanceDue => totalAmount - paidAmount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'purchaseNumber': purchaseNumber,
    'supplierName': supplierName,
    'supplierPhone': supplierPhone,
    'supplierGstin': supplierGstin,
    'invoiceNumber': invoiceNumber,
    'items': items.map((e) => e.toMap()).toList(),
    'subtotal': subtotal,
    'totalTax': totalTax,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'status': status.name,
    'paymentMethod': paymentMethod.name,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
    id: map['id'] as String,
    purchaseNumber: map['purchaseNumber'] as String,
    supplierName: map['supplierName'] as String,
    supplierPhone: map['supplierPhone'] as String?,
    supplierGstin: map['supplierGstin'] as String?,
    invoiceNumber: map['invoiceNumber'] as String?,
    items: (map['items'] as List)
        .map((e) => PurchaseItem.fromMap(e as Map<String, dynamic>))
        .toList(),
    subtotal: (map['subtotal'] as num).toDouble(),
    totalTax: (map['totalTax'] as num).toDouble(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
    status: PurchaseStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => PurchaseStatus.received,
    ),
    paymentMethod: PaymentMethod.values.firstWhere(
      (e) => e.name == (map['paymentMethod'] as String? ?? 'cash'),
      orElse: () => PaymentMethod.cash,
    ),
    notes: map['notes'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null),
  );
}


