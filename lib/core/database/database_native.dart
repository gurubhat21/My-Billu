import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/purchase.dart';

Future<Database> initDatabase(String fileName) async {
  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, fileName);
  return await openDatabase(path, version: 8,
    onCreate: _createDB,
    onUpgrade: _upgradeDB,
  );
}

/// Open database at a custom directory path (for Windows data path setting)
Future<Database> initDatabaseAtPath(String dirPath, [String fileName = 'my_billu.db']) async {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final dbFile = p.join(dirPath, fileName);
  return await openDatabase(dbFile, version: 8,
    onCreate: _createDB,
    onUpgrade: _upgradeDB,
  );
}

Future<void> _createDB(Database db, int version) async {
  await db.execute('''
    CREATE TABLE items (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT,
      price REAL NOT NULL, purchasePrice REAL DEFAULT 0, marginPercent REAL DEFAULT 0, taxRate REAL DEFAULT 18.0, hsnCode TEXT, barcode TEXT,
      unit TEXT DEFAULT 'pcs', stockQuantity INTEGER DEFAULT 0,
      category TEXT, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, email TEXT,
      address TEXT, gstin TEXT, totalPurchases REAL DEFAULT 0.0,
      outstandingBalance REAL DEFAULT 0.0, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE bills (
      id TEXT PRIMARY KEY, billNumber TEXT NOT NULL UNIQUE, customerId TEXT,
      customerName TEXT, customerPhone TEXT, items TEXT NOT NULL, subtotal REAL NOT NULL,
      discount REAL DEFAULT 0.0,
      totalTax REAL NOT NULL, totalAmount REAL NOT NULL,
      paidAmount REAL DEFAULT 0.0, paymentMethod TEXT DEFAULT 'cash',
      status TEXT DEFAULT 'paid', notes TEXT, createdAt TEXT NOT NULL,
      updatedAt TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
  ''');
  await db.execute('''
    CREATE TABLE purchases (
      id TEXT PRIMARY KEY, purchaseNumber TEXT NOT NULL UNIQUE, supplierName TEXT NOT NULL,
      supplierPhone TEXT, supplierGstin TEXT, invoiceNumber TEXT,
      items TEXT NOT NULL, subtotal REAL NOT NULL, totalTax REAL NOT NULL,
      totalAmount REAL NOT NULL, paidAmount REAL DEFAULT 0.0,
      status TEXT DEFAULT 'received', paymentMethod TEXT DEFAULT 'cash',
      notes TEXT, createdAt TEXT NOT NULL,
      updatedAt TEXT
    )
  ''');
}

Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    try {
      await db.execute('ALTER TABLE bills ADD COLUMN discount REAL DEFAULT 0.0');
    } catch (_) {}
  }
  if (oldVersion < 3) {
    try {
      await db.execute('ALTER TABLE items ADD COLUMN barcode TEXT');
    } catch (_) {}
  }
  if (oldVersion < 4) {
    try {
      await db.execute('ALTER TABLE bills ADD COLUMN customerPhone TEXT');
    } catch (_) {}
  }
  if (oldVersion < 5) {
    try {
      await db.execute('ALTER TABLE items ADD COLUMN purchasePrice REAL DEFAULT 0');
    } catch (_) {}
  }
  if (oldVersion < 6) {
    try {
      await db.execute("ALTER TABLE purchases ADD COLUMN paymentMethod TEXT DEFAULT 'cash'");
    } catch (_) {}
  }
  if (oldVersion < 7) {
    try {
      await db.execute('ALTER TABLE items ADD COLUMN marginPercent REAL DEFAULT 0');
    } catch (_) {}
  }
  if (oldVersion < 8) {
    try {
      await db.execute('ALTER TABLE bills ADD COLUMN updatedAt TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE purchases ADD COLUMN updatedAt TEXT');
    } catch (_) {}
    try {
      await db.execute('UPDATE bills SET updatedAt = createdAt WHERE updatedAt IS NULL');
    } catch (_) {}
    try {
      await db.execute('UPDATE purchases SET updatedAt = createdAt WHERE updatedAt IS NULL');
    } catch (_) {}
  }
}

// ===== ITEMS =====
Future<int> insertItem(Database db, Item item) async =>
    db.insert('items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

Future<List<Item>> getAllItems(Database db) async {
  final maps = await db.query('items', orderBy: 'name ASC');
  return maps.map((m) => Item.fromMap(m)).toList();
}

Future<Item?> getItem(Database db, String id) async {
  final maps = await db.query('items', where: 'id = ?', whereArgs: [id]);
  return maps.isNotEmpty ? Item.fromMap(maps.first) : null;
}

Future<int> updateItem(Database db, Item item) async =>
    db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);

Future<int> deleteItem(Database db, String id) async =>
    db.delete('items', where: 'id = ?', whereArgs: [id]);

Future<List<Item>> searchItems(Database db, String query) async {
  final maps = await db.query('items',
      where: 'name LIKE ? OR category LIKE ?', whereArgs: ['%$query%', '%$query%']);
  return maps.map((m) => Item.fromMap(m)).toList();
}

// ===== CUSTOMERS =====
Future<int> insertCustomer(Database db, Customer customer) async =>
    db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

Future<List<Customer>> getAllCustomers(Database db) async {
  final maps = await db.query('customers', orderBy: 'name ASC');
  return maps.map((m) => Customer.fromMap(m)).toList();
}

Future<int> updateCustomer(Database db, Customer customer) async =>
    db.update('customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);

Future<int> deleteCustomer(Database db, String id) async =>
    db.delete('customers', where: 'id = ?', whereArgs: [id]);

Future<List<Customer>> searchCustomers(Database db, String query) async {
  final maps = await db.query('customers',
      where: 'name LIKE ? OR phone LIKE ?', whereArgs: ['%$query%', '%$query%']);
  return maps.map((m) => Customer.fromMap(m)).toList();
}

// ===== BILLS =====
Future<int> insertBill(Database db, Bill bill) async {
  final map = bill.toMap();
  map['items'] = jsonEncode(map['items']);
  return db.insert('bills', map, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<Bill>> getAllBills(Database db, {int? limit, int? offset}) async {
  final maps = await db.query('bills', orderBy: 'createdAt DESC', limit: limit, offset: offset);
  return maps.map((map) {
    final m = Map<String, dynamic>.from(map);
    m['items'] = jsonDecode(m['items'] as String);
    return Bill.fromMap(m);
  }).toList();
}

Future<Bill?> getBill(Database db, String id) async {
  final maps = await db.query('bills', where: 'id = ?', whereArgs: [id]);
  if (maps.isNotEmpty) {
    final m = Map<String, dynamic>.from(maps.first);
    m['items'] = jsonDecode(m['items'] as String);
    return Bill.fromMap(m);
  }
  return null;
}

Future<List<Bill>> getBillsByDate(Database db, DateTime date) async {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  final maps = await db.query('bills',
      where: 'createdAt >= ? AND createdAt < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'createdAt DESC');
  return maps.map((map) {
    final m = Map<String, dynamic>.from(map);
    m['items'] = jsonDecode(m['items'] as String);
    return Bill.fromMap(m);
  }).toList();
}

Future<List<Bill>> getBillsByDateRange(Database db, DateTime from, DateTime to) async {
  final maps = await db.query('bills',
      where: 'createdAt >= ? AND createdAt <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'createdAt DESC');
  return maps.map((map) {
    final m = Map<String, dynamic>.from(map);
    m['items'] = jsonDecode(m['items'] as String);
    return Bill.fromMap(m);
  }).toList();
}

Future<int> deleteBill(Database db, String id) async =>
    db.delete('bills', where: 'id = ?', whereArgs: [id]);

Future<int> updateBill(Database db, Bill bill) async {
  final map = bill.toMap();
  map['items'] = jsonEncode(map['items']);
  return db.update('bills', map, where: 'id = ?', whereArgs: [bill.id]);
}

Future<String> getNextBillNumber(Database db) async {
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM bills');
  final count = Sqflite.firstIntValue(result) ?? 0;
  final now = DateTime.now();
  final prefix = 'INV${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
  return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
}

Future<Map<String, dynamic>> getDashboardStats(Database db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final monthStart = DateTime(now.year, now.month, 1);

  final todayResult = await db.rawQuery(
    'SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(*) as count FROM bills WHERE createdAt >= ? AND createdAt < ?',
    [today.toIso8601String(), tomorrow.toIso8601String()]);
  final monthResult = await db.rawQuery(
    'SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(*) as count FROM bills WHERE createdAt >= ? AND createdAt < ?',
    [monthStart.toIso8601String(), tomorrow.toIso8601String()]);
  final outstandingResult = await db.rawQuery(
    "SELECT COALESCE(SUM(totalAmount - paidAmount), 0) as total FROM bills WHERE status != 'paid'");
  final customerCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
  final itemCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM items')) ?? 0;

  return {
    'todaySales': (todayResult.first['total'] as num?)?.toDouble() ?? 0.0,
    'todayBillCount': (todayResult.first['count'] as num?)?.toInt() ?? 0,
    'monthSales': (monthResult.first['total'] as num?)?.toDouble() ?? 0.0,
    'monthBillCount': (monthResult.first['count'] as num?)?.toInt() ?? 0,
    'outstanding': (outstandingResult.first['total'] as num?)?.toDouble() ?? 0.0,
    'customerCount': customerCount,
    'itemCount': itemCount,
    'dailySales': <Map<String, dynamic>>[],
  };
}

// ===== PURCHASES =====
Future<int> insertPurchase(Database db, Purchase purchase) async {
  final map = purchase.toMap();
  map['items'] = jsonEncode(map['items']);
  return db.insert('purchases', map, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<List<Purchase>> getAllPurchases(Database db) async {
  final maps = await db.query('purchases', orderBy: 'createdAt DESC');
  return maps.map((map) {
    final m = Map<String, dynamic>.from(map);
    m['items'] = jsonDecode(m['items'] as String);
    return Purchase.fromMap(m);
  }).toList();
}

Future<int> deletePurchase(Database db, String id) async =>
    db.delete('purchases', where: 'id = ?', whereArgs: [id]);

Future<int> updatePurchase(Database db, Purchase purchase) async {
  final map = purchase.toMap();
  map['items'] = jsonEncode(map['items']);
  return db.update('purchases', map, where: 'id = ?', whereArgs: [purchase.id]);
}

Future<String> getNextPurchaseNumber(Database db) async {
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM purchases');
  final count = Sqflite.firstIntValue(result) ?? 0;
  final now = DateTime.now();
  final prefix = 'PO${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
  return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
}

// ===== SETTINGS =====
Future<void> setSetting(Database db, String key, String value) async =>
    db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

Future<String?> getSetting(Database db, String key) async {
  final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
  return maps.isNotEmpty ? maps.first['value'] as String : null;
}

Future<Map<String, String>> getAllSettings(Database db) async {
  final maps = await db.query('settings');
  return {for (var m in maps) m['key'] as String: m['value'] as String};
}


