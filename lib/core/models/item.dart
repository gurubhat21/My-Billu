import 'package:uuid/uuid.dart';

class Item {
  final String id;
  String name;
  String? description;
  double price;
  double taxRate; // GST percentage
  String? hsnCode;
  String? barcode;
  String unit; // pcs, kg, ltr, etc.
  int stockQuantity;
  String? category;
  double purchasePrice;
  DateTime createdAt;
  DateTime updatedAt;

  Item({
    String? id,
    required this.name,
    this.description,
    required this.price,
    this.taxRate = 18.0,
    this.hsnCode,
    this.barcode,
    this.unit = 'pcs',
    this.stockQuantity = 0,
    this.category,
    this.purchasePrice = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'taxRate': taxRate,
      'hsnCode': hsnCode,
      'barcode': barcode,
      'unit': unit,
      'stockQuantity': stockQuantity,
      'category': category,
      'purchasePrice': purchasePrice,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 18.0,
      hsnCode: map['hsnCode'] as String?,
      barcode: map['barcode'] as String?,
      unit: map['unit'] as String? ?? 'pcs',
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
      category: map['category'] as String?,
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Item copyWith({
    String? name,
    String? description,
    double? price,
    double? taxRate,
    String? hsnCode,
    String? barcode,
    String? unit,
    int? stockQuantity,
    String? category,
    double? purchasePrice,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      hsnCode: hsnCode ?? this.hsnCode,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}


