import 'package:uuid/uuid.dart';
import 'bill.dart';

class CreditNote {
  final String id;
  final String creditNoteNumber;
  final String? billId;
  final String? billNumber;
  final String? customerId;
  final String? customerName;
  final List<BillItem> items;
  final double subtotal;
  final double totalTax;
  final double totalAmount;
  final String reason;
  final String? notes;
  final CreditNoteStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreditNote({
    String? id,
    required this.creditNoteNumber,
    this.billId,
    this.billNumber,
    this.customerId,
    this.customerName,
    required this.items,
    required this.subtotal,
    required this.totalTax,
    required this.totalAmount,
    required this.reason,
    this.notes,
    this.status = CreditNoteStatus.issued,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'creditNoteNumber': creditNoteNumber,
    'billId': billId,
    'billNumber': billNumber,
    'customerId': customerId,
    'customerName': customerName,
    'items': items.map((e) => e.toMap()).toList(),
    'subtotal': subtotal,
    'totalTax': totalTax,
    'totalAmount': totalAmount,
    'reason': reason,
    'notes': notes,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CreditNote.fromMap(Map<String, dynamic> map) => CreditNote(
    id: map['id'] as String,
    creditNoteNumber: map['creditNoteNumber'] as String,
    billId: map['billId'] as String?,
    billNumber: map['billNumber'] as String?,
    customerId: map['customerId'] as String?,
    customerName: map['customerName'] as String?,
    items: (map['items'] as List).map((e) => BillItem.fromMap(e as Map<String, dynamic>)).toList(),
    subtotal: (map['subtotal'] as num).toDouble(),
    totalTax: (map['totalTax'] as num).toDouble(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    reason: map['reason'] as String? ?? '',
    notes: map['notes'] as String?,
    status: CreditNoteStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => CreditNoteStatus.issued),
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : DateTime.tryParse(map['createdAt'] as String? ?? ''),
  );
}

enum CreditNoteStatus { issued, adjusted, cancelled }


