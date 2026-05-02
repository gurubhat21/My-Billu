import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';

// Conditional imports
import 'database_native.dart' if (dart.library.html) 'database_web.dart'
    as platform_db;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static dynamic _db;

  DatabaseHelper._init();

  Future<dynamic> get database async {
    if (_db != null) return _db;
    _db = await platform_db.initDatabase('my_billu.db');
    return _db;
  }

  // ===== ITEMS =====

  Future<int> insertItem(Item item) async {
    return await platform_db.insertItem(await database, item);
  }

  Future<List<Item>> getAllItems() async {
    return await platform_db.getAllItems(await database);
  }

  Future<Item?> getItem(String id) async {
    return await platform_db.getItem(await database, id);
  }

  Future<int> updateItem(Item item) async {
    return await platform_db.updateItem(await database, item);
  }

  Future<int> deleteItem(String id) async {
    return await platform_db.deleteItem(await database, id);
  }

  Future<List<Item>> searchItems(String query) async {
    return await platform_db.searchItems(await database, query);
  }

  // ===== CUSTOMERS =====

  Future<int> insertCustomer(Customer customer) async {
    return await platform_db.insertCustomer(await database, customer);
  }

  Future<List<Customer>> getAllCustomers() async {
    return await platform_db.getAllCustomers(await database);
  }

  Future<int> updateCustomer(Customer customer) async {
    return await platform_db.updateCustomer(await database, customer);
  }

  Future<int> deleteCustomer(String id) async {
    return await platform_db.deleteCustomer(await database, id);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    return await platform_db.searchCustomers(await database, query);
  }

  // ===== BILLS =====

  Future<int> insertBill(Bill bill) async {
    return await platform_db.insertBill(await database, bill);
  }

  Future<List<Bill>> getAllBills({int? limit, int? offset}) async {
    return await platform_db.getAllBills(await database, limit: limit, offset: offset);
  }

  Future<Bill?> getBill(String id) async {
    return await platform_db.getBill(await database, id);
  }

  Future<List<Bill>> getBillsByDate(DateTime date) async {
    return await platform_db.getBillsByDate(await database, date);
  }

  Future<List<Bill>> getBillsByDateRange(DateTime from, DateTime to) async {
    return await platform_db.getBillsByDateRange(await database, from, to);
  }

  Future<int> deleteBill(String id) async {
    return await platform_db.deleteBill(await database, id);
  }

  // ===== BILL NUMBER =====

  Future<String> getNextBillNumber() async {
    return await platform_db.getNextBillNumber(await database);
  }

  // ===== DASHBOARD STATS =====

  Future<Map<String, dynamic>> getDashboardStats() async {
    return await platform_db.getDashboardStats(await database);
  }

  // ===== SETTINGS =====

  Future<void> setSetting(String key, String value) async {
    await platform_db.setSetting(await database, key, value);
  }

  Future<String?> getSetting(String key) async {
    return await platform_db.getSetting(await database, key);
  }

  Future<Map<String, String>> getAllSettings() async {
    return await platform_db.getAllSettings(await database);
  }
}
