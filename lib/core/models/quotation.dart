import 'package:uuid/uuid.dart';
import 'bill.dart';

enum QuotationStatus { draft, sent, accepted, rejected, converted }

class Quotation {
  final String id;
  final String quotationNumber;
  String? customerId;
  String? customerName;
  String? customerPhone;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double totalTax;
  final double totalAmount;
  QuotationStatus status;
  String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  DateTime? validUntil;

  Quotation({
    String? id,
    required this.quotationNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.totalTax,
    required this.totalAmount,
    this.status = QuotationStatus.draft,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.validUntil,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get totalCgst => totalTax / 2;
  double get totalSgst => totalTax / 2;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quotationNumber': quotationNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'totalTax': totalTax,
      'totalAmount': totalAmount,
      'status': status.name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
    };
  }

  factory Quotation.fromMap(Map<String, dynamic> map) {
    return Quotation(
      id: map['id'] as String,
      quotationNumber: map['quotationNumber'] as String,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      items: (map['items'] as List)
          .map((e) => BillItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      totalTax: (map['totalTax'] as num).toDouble(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      status: QuotationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => QuotationStatus.draft,
      ),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null),
      validUntil: map['validUntil'] != null ? DateTime.parse(map['validUntil'] as String) : null,
    );
  }
}


