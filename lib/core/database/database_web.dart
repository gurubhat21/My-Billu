import 'dart:convert';
import 'package:web/web.dart' as web;
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/purchase.dart';

/// Web storage wrapper using localStorage
class WebDB {
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  WebDB() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    for (final table in ['items', 'customers', 'bills', 'purchases', 'settings']) {
      final data = web.window.localStorage.getItem('mybillu_$table');
      if (data != null) {
        _tables[table] = List<Map<String, dynamic>>.from(
            jsonDecode(data).map((e) => Map<String, dynamic>.from(e)));
      } else {
        _tables[table] = [];
      }
    }
  }

  void _saveTable(String table) {
    web.window.localStorage.setItem('mybillu_$table', jsonEncode(_tables[table]));
  }

  List<Map<String, dynamic>> getAll(String table) => _tables[table] ?? [];

  void insert(String table, Map<String, dynamic> data) {
    final list = _tables[table] ?? [];
    // Replace if exists (match by id OR by key, but only if the field is non-null)
    list.removeWhere((row) =>
      (data['id'] != null && row['id'] == data['id']) ||
      (data['key'] != null && row['key'] == data['key']));
    list.add(data);
    _tables[table] = list;
    _saveTable(table);
  }

  void update(String table, Map<String, dynamic> data, String id) {
    final list = _tables[table] ?? [];
    final idx = list.indexWhere((row) => row['id'] == id);
    if (idx >= 0) list[idx] = data;
    _saveTable(table);
  }

  void delete(String table, String id) {
    _tables[table]?.removeWhere((row) => row['id'] == id);
    _saveTable(table);
  }
}

Future<WebDB> initDatabase(String fileName) async {
  return WebDB();
}

// ===== ITEMS =====
Future<int> insertItem(WebDB db, Item item) async {
  db.insert('items', item.toMap());
  return 1;
}

Future<List<Item>> getAllItems(WebDB db) async {
  final items = db.getAll('items').map((m) => Item.fromMap(m)).toList();
  items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return items;
}

Future<Item?> getItem(WebDB db, String id) async {
  final list = db.getAll('items').where((m) => m['id'] == id);
  return list.isNotEmpty ? Item.fromMap(list.first) : null;
}

Future<int> updateItem(WebDB db, Item item) async {
  db.update('items', item.toMap(), item.id);
  return 1;
}

Future<int> deleteItem(WebDB db, String id) async {
  db.delete('items', id);
  return 1;
}

Future<List<Item>> searchItems(WebDB db, String query) async {
  final q = query.toLowerCase();
  return db.getAll('items')
      .where((m) =>
          (m['name'] as String).toLowerCase().contains(q) ||
          (m['category'] as String? ?? '').toLowerCase().contains(q))
      .map((m) => Item.fromMap(m))
      .toList();
}

// ===== CUSTOMERS =====
Future<int> insertCustomer(WebDB db, Customer customer) async {
  db.insert('customers', customer.toMap());
  return 1;
}

Future<List<Customer>> getAllCustomers(WebDB db) async {
  final customers = db.getAll('customers').map((m) => Customer.fromMap(m)).toList();
  customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return customers;
}

Future<int> updateCustomer(WebDB db, Customer customer) async {
  db.update('customers', customer.toMap(), customer.id);
  return 1;
}

Future<int> deleteCustomer(WebDB db, String id) async {
  db.delete('customers', id);
  return 1;
}

Future<List<Customer>> searchCustomers(WebDB db, String query) async {
  final q = query.toLowerCase();
  return db.getAll('customers')
      .where((m) =>
          (m['name'] as String).toLowerCase().contains(q) ||
          (m['phone'] as String? ?? '').contains(q))
      .map((m) => Customer.fromMap(m))
      .toList();
}

// ===== BILLS =====
Future<int> insertBill(WebDB db, Bill bill) async {
  final map = bill.toMap();
  // Items are already a list of maps, store as-is (web doesn't need JSON string)
  db.insert('bills', map);
  return 1;
}

Future<List<Bill>> getAllBills(WebDB db, {int? limit, int? offset}) async {
  var bills = db.getAll('bills').map((m) => Bill.fromMap(m)).toList();
  bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (offset != null) bills = bills.skip(offset).toList();
  if (limit != null) bills = bills.take(limit).toList();
  return bills;
}

Future<Bill?> getBill(WebDB db, String id) async {
  final list = db.getAll('bills').where((m) => m['id'] == id);
  return list.isNotEmpty ? Bill.fromMap(list.first) : null;
}

Future<List<Bill>> getBillsByDate(WebDB db, DateTime date) async {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return db.getAll('bills')
      .map((m) => Bill.fromMap(m))
      .where((b) => b.createdAt.isAfter(start) && b.createdAt.isBefore(end))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

Future<List<Bill>> getBillsByDateRange(WebDB db, DateTime from, DateTime to) async {
  return db.getAll('bills')
      .map((m) => Bill.fromMap(m))
      .where((b) => b.createdAt.isAfter(from) && b.createdAt.isBefore(to))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

Future<int> deleteBill(WebDB db, String id) async {
  db.delete('bills', id);
  return 1;
}

Future<int> updateBill(WebDB db, Bill bill) async {
  db.update('bills', bill.toMap(), bill.id);
  return 1;
}

Future<String> getNextBillNumber(WebDB db) async {
  final count = db.getAll('bills').length;
  final now = DateTime.now();
  final prefix = 'INV${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
  return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
}

Future<Map<String, dynamic>> getDashboardStats(WebDB db) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final monthStart = DateTime(now.year, now.month, 1);

  final allBills = db.getAll('bills').map((m) => Bill.fromMap(m)).toList();

  final todayBills = allBills.where((b) =>
      b.createdAt.isAfter(today) && b.createdAt.isBefore(tomorrow)).toList();
  final monthBills = allBills.where((b) =>
      b.createdAt.isAfter(monthStart) && b.createdAt.isBefore(tomorrow)).toList();

  double todaySales = 0, monthSales = 0, outstanding = 0;
  for (final b in todayBills) todaySales += b.totalAmount;
  for (final b in monthBills) monthSales += b.totalAmount;
  for (final b in allBills) {
    if (b.status != BillStatus.paid) outstanding += b.balanceDue;
  }

  return {
    'todaySales': todaySales,
    'todayBillCount': todayBills.length,
    'monthSales': monthSales,
    'monthBillCount': monthBills.length,
    'outstanding': outstanding,
    'customerCount': db.getAll('customers').length,
    'itemCount': db.getAll('items').length,
    'dailySales': <Map<String, dynamic>>[],
  };
}

// ===== PURCHASES =====
Future<int> insertPurchase(WebDB db, Purchase purchase) async {
  db.insert('purchases', purchase.toMap());
  return 1;
}

Future<List<Purchase>> getAllPurchases(WebDB db) async {
  final purchases = db.getAll('purchases').map((m) => Purchase.fromMap(m)).toList();
  purchases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return purchases;
}

Future<int> deletePurchase(WebDB db, String id) async {
  db.delete('purchases', id);
  return 1;
}

Future<String> getNextPurchaseNumber(WebDB db) async {
  final count = db.getAll('purchases').length;
  final now = DateTime.now();
  final prefix = 'PO${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
  return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
}

// ===== SETTINGS =====
Future<void> setSetting(WebDB db, String key, String value) async {
  db.insert('settings', {'key': key, 'value': value});
}

Future<String?> getSetting(WebDB db, String key) async {
  final list = db.getAll('settings').where((m) => m['key'] == key);
  return list.isNotEmpty ? list.first['value'] as String : null;
}

Future<Map<String, String>> getAllSettings(WebDB db) async {
  return {for (var m in db.getAll('settings')) m['key'] as String: m['value'] as String};
}
