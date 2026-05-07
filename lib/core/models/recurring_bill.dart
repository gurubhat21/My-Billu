import 'package:uuid/uuid.dart';
import 'bill.dart';

enum RecurringFrequency { weekly, monthly, quarterly, yearly }

class RecurringBill {
  final String id;
  final String? customerId;
  final String? customerName;
  final List<BillItem> items;
  final double totalAmount;
  final RecurringFrequency frequency;
  final PaymentMethod paymentMethod;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final bool isActive;
  final String? notes;

  RecurringBill({
    String? id,
    this.customerId,
    this.customerName,
    required this.items,
    required this.totalAmount,
    required this.frequency,
    this.paymentMethod = PaymentMethod.cash,
    required this.startDate,
    this.endDate,
    required this.nextDueDate,
    this.isActive = true,
    this.notes,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id, 'customerId': customerId, 'customerName': customerName,
    'items': items.map((e) => e.toMap()).toList(),
    'totalAmount': totalAmount, 'frequency': frequency.name,
    'paymentMethod': paymentMethod.name, 'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(), 'nextDueDate': nextDueDate.toIso8601String(),
    'isActive': isActive, 'notes': notes,
  };

  factory RecurringBill.fromMap(Map<String, dynamic> map) => RecurringBill(
    id: map['id'] as String,
    customerId: map['customerId'] as String?,
    customerName: map['customerName'] as String?,
    items: (map['items'] as List).map((e) => BillItem.fromMap(e as Map<String, dynamic>)).toList(),
    totalAmount: (map['totalAmount'] as num).toDouble(),
    frequency: RecurringFrequency.values.firstWhere((e) => e.name == map['frequency']),
    paymentMethod: PaymentMethod.values.firstWhere((e) => e.name == map['paymentMethod'], orElse: () => PaymentMethod.cash),
    startDate: DateTime.parse(map['startDate'] as String),
    endDate: map['endDate'] != null ? DateTime.parse(map['endDate'] as String) : null,
    nextDueDate: DateTime.parse(map['nextDueDate'] as String),
    isActive: map['isActive'] as bool? ?? true,
    notes: map['notes'] as String?,
  );

  RecurringBill copyWith({DateTime? nextDueDate, bool? isActive}) => RecurringBill(
    id: id, customerId: customerId, customerName: customerName,
    items: items, totalAmount: totalAmount, frequency: frequency,
    paymentMethod: paymentMethod, startDate: startDate, endDate: endDate,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    isActive: isActive ?? this.isActive, notes: notes,
  );
}
