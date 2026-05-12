import 'dart:convert';
import 'package:uuid/uuid.dart';

class BillItem {
  final String itemId;
  final String itemName;
  final double unitPrice;
  final int quantity;
  final double taxRate;
  final String unit;

  BillItem({
    required this.itemId,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.taxRate,
    this.unit = 'pcs',
  });

  double get subtotal => unitPrice * quantity;
  double get taxAmount => subtotal * taxRate / 100;
  double get total => subtotal + taxAmount;
  // GST split (intra-state)
  double get cgst => taxAmount / 2;
  double get sgst => taxAmount / 2;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'taxRate': taxRate,
      'unit': unit,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      itemId: map['itemId'] as String,
      itemName: map['itemName'] as String,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      taxRate: (map['taxRate'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'pcs',
    );
  }
}

enum PaymentMethod { cash, upi, card, bank, credit }

enum BillStatus { paid, unpaid, partial }

class Bill {
  final String id;
  final String billNumber;
  String? customerId;
  String? customerName;
  String? customerPhone;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double totalTax;
  final double totalAmount;
  double paidAmount;
  final PaymentMethod paymentMethod;
  BillStatus status;
  String? notes;
  final DateTime createdAt;

  Bill({
    String? id,
    required this.billNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.totalTax,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.paymentMethod = PaymentMethod.cash,
    this.status = BillStatus.paid,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  double get balanceDue => totalAmount - paidAmount;
  double get totalCgst => totalTax / 2;
  double get totalSgst => totalTax / 2;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billNumber': billNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'totalTax': totalTax,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod.name,
      'status': status.name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    // Handle items being either a List or a JSON string
    var rawItems = map['items'];
    if (rawItems is String) {
      rawItems = jsonDecode(rawItems);
    }
    final itemsList = (rawItems as List?)
        ?.map((e) => BillItem.fromMap(Map<String, dynamic>.from(e)))
        .toList() ?? [];

    return Bill(
      id: map['id'] as String,
      billNumber: map['billNumber'] as String? ?? 'BILL-0',
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      items: itemsList,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalTax: (map['totalTax'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      status: BillStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BillStatus.paid,
      ),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
    );
  }
}
