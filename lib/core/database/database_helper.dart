import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('my_billu.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        taxRate REAL DEFAULT 18.0,
        hsnCode TEXT,
        unit TEXT DEFAULT 'pcs',
        stockQuantity INTEGER DEFAULT 0,
        category TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        gstin TEXT,
        totalPurchases REAL DEFAULT 0.0,
        outstandingBalance REAL DEFAULT 0.0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY,
        billNumber TEXT NOT NULL UNIQUE,
        customerId TEXT,
        customerName TEXT,
        items TEXT NOT NULL,
        subtotal REAL NOT NULL,
        totalTax REAL NOT NULL,
        totalAmount REAL NOT NULL,
        paidAmount REAL DEFAULT 0.0,
        paymentMethod TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'paid',
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ===== ITEMS =====

  Future<int> insertItem(Item item) async {
    final db = await database;
    return await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query('items', orderBy: 'name ASC');
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<Item?> getItem(String id) async {
    final db = await database;
    final maps = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Item.fromMap(maps.first);
    return null;
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return await db
        .update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(String id) async {
    final db = await database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Item>> searchItems(String query) async {
    final db = await database;
    final maps = await db.query('items',
        where: 'name LIKE ? OR category LIKE ?',
        whereArgs: ['%$query%', '%$query%']);
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  // ===== CUSTOMERS =====

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update('customers', customer.toMap(),
        where: 'id = ?', whereArgs: [customer.id]);
  }

  Future<int> deleteCustomer(String id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await database;
    final maps = await db.query('customers',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$query%', '%$query%']);
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  // ===== BILLS =====

  Future<int> insertBill(Bill bill) async {
    final db = await database;
    final map = bill.toMap();
    map['items'] = jsonEncode(map['items']);
    return await db.insert('bills', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Bill>> getAllBills({int? limit, int? offset}) async {
    final db = await database;
    final maps = await db.query('bills',
        orderBy: 'createdAt DESC', limit: limit, offset: offset);
    return maps.map((map) {
      final m = Map<String, dynamic>.from(map);
      m['items'] = jsonDecode(m['items'] as String);
      return Bill.fromMap(m);
    }).toList();
  }

  Future<Bill?> getBill(String id) async {
    final db = await database;
    final maps = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final m = Map<String, dynamic>.from(maps.first);
      m['items'] = jsonDecode(m['items'] as String);
      return Bill.fromMap(m);
    }
    return null;
  }

  Future<List<Bill>> getBillsByDate(DateTime date) async {
    final db = await database;
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

  Future<List<Bill>> getBillsByDateRange(DateTime from, DateTime to) async {
    final db = await database;
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

  Future<int> deleteBill(String id) async {
    final db = await database;
    return await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  // ===== BILL NUMBER =====

  Future<String> getNextBillNumber() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM bills');
    final count = Sqflite.firstIntValue(result) ?? 0;
    final now = DateTime.now();
    final prefix =
        'INV${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }

  // ===== DASHBOARD STATS =====

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month, 1);

    // Today's sales
    final todayResult = await db.rawQuery(
      'SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(*) as count FROM bills WHERE createdAt >= ? AND createdAt < ?',
      [today.toIso8601String(), tomorrow.toIso8601String()],
    );

    // This month's sales
    final monthResult = await db.rawQuery(
      'SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(*) as count FROM bills WHERE createdAt >= ? AND createdAt < ?',
      [monthStart.toIso8601String(), tomorrow.toIso8601String()],
    );

    // Outstanding balance
    final outstandingResult = await db.rawQuery(
      "SELECT COALESCE(SUM(totalAmount - paidAmount), 0) as total FROM bills WHERE status != 'paid'",
    );

    // Total customers
    final customerCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;

    // Total items
    final itemCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM items')) ?? 0;

    // Last 7 days sales for chart
    final List<Map<String, dynamic>> dailySales = [];
    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(totalAmount), 0) as total FROM bills WHERE createdAt >= ? AND createdAt < ?',
        [day.toIso8601String(), nextDay.toIso8601String()],
      );
      dailySales.add({
        'date': day,
        'total': (result.first['total'] as num?)?.toDouble() ?? 0.0,
      });
    }

    return {
      'todaySales': (todayResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'todayBillCount': (todayResult.first['count'] as num?)?.toInt() ?? 0,
      'monthSales': (monthResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'monthBillCount': (monthResult.first['count'] as num?)?.toInt() ?? 0,
      'outstanding':
          (outstandingResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'customerCount': customerCount,
      'itemCount': itemCount,
      'dailySales': dailySales,
    };
  }

  // ===== SETTINGS =====

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) return maps.first['value'] as String;
    return null;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }
}
