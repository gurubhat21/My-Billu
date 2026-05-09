import 'package:uuid/uuid.dart';

enum AuditAction { created, updated, deleted }
enum AuditEntity { item, customer, supplier, bill, purchase, expense, quotation, creditNote, purchaseReturn, recurringBill, setting }

class AuditEntry {
  final String id;
  final AuditAction action;
  final AuditEntity entity;
  final String entityName;
  final String? details;
  final DateTime timestamp;

  AuditEntry({
    String? id,
    required this.action,
    required this.entity,
    required this.entityName,
    this.details,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action.name,
    'entity': entity.name,
    'entityName': entityName,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AuditEntry.fromMap(Map<String, dynamic> map) => AuditEntry(
    id: map['id'] as String,
    action: AuditAction.values.firstWhere((e) => e.name == map['action'], orElse: () => AuditAction.created),
    entity: AuditEntity.values.firstWhere((e) => e.name == map['entity'], orElse: () => AuditEntity.item),
    entityName: map['entityName'] as String? ?? '',
    details: map['details'] as String?,
    timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
  );

  String get actionLabel {
    switch (action) {
      case AuditAction.created: return 'Created';
      case AuditAction.updated: return 'Updated';
      case AuditAction.deleted: return 'Deleted';
    }
  }

  String get entityLabel {
    switch (entity) {
      case AuditEntity.item: return 'Item';
      case AuditEntity.customer: return 'Customer';
      case AuditEntity.supplier: return 'Supplier';
      case AuditEntity.bill: return 'Bill';
      case AuditEntity.purchase: return 'Purchase';
      case AuditEntity.expense: return 'Expense';
      case AuditEntity.quotation: return 'Quotation';
      case AuditEntity.creditNote: return 'Credit Note';
      case AuditEntity.purchaseReturn: return 'Purchase Return';
      case AuditEntity.recurringBill: return 'Recurring Bill';
      case AuditEntity.setting: return 'Setting';
    }
  }
}
