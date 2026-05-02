import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Item> _items = [];
  List<Customer> _customers = [];
  List<Bill> _bills = [];
  Map<String, dynamic> _dashboardStats = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Item> get items => _items;
  List<Customer> get customers => _customers;
  List<Bill> get bills => _bills;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ===== INITIALIZATION =====

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadItems(),
        loadCustomers(),
        loadBills(),
        loadDashboardStats(),
      ]);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ===== ITEMS =====

  Future<void> loadItems() async {
    _items = await _db.getAllItems();
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    await _db.insertItem(item);
    await loadItems();
    await loadDashboardStats();
  }

  Future<void> updateItem(Item item) async {
    await _db.updateItem(item);
    await loadItems();
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteItem(id);
    await loadItems();
    await loadDashboardStats();
  }

  Future<List<Item>> searchItems(String query) async {
    if (query.isEmpty) return _items;
    return await _db.searchItems(query);
  }

  // ===== CUSTOMERS =====

  Future<void> loadCustomers() async {
    _customers = await _db.getAllCustomers();
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    await _db.insertCustomer(customer);
    await loadCustomers();
    await loadDashboardStats();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await _db.deleteCustomer(id);
    await loadCustomers();
    await loadDashboardStats();
  }

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return _customers;
    return await _db.searchCustomers(query);
  }

  // ===== BILLS =====

  Future<void> loadBills() async {
    _bills = await _db.getAllBills();
    notifyListeners();
  }

  Future<String> getNextBillNumber() async {
    return await _db.getNextBillNumber();
  }

  Future<void> createBill(Bill bill) async {
    await _db.insertBill(bill);

    // Update stock quantities
    for (final billItem in bill.items) {
      final item = _items.firstWhere(
        (i) => i.id == billItem.itemId,
        orElse: () => Item(name: '', price: 0),
      );
      if (item.name.isNotEmpty) {
        item.stockQuantity -= billItem.quantity;
        if (item.stockQuantity < 0) item.stockQuantity = 0;
        await _db.updateItem(item);
      }
    }

    // Update customer total purchases
    if (bill.customerId != null) {
      final customer = _customers.firstWhere(
        (c) => c.id == bill.customerId,
        orElse: () => Customer(name: ''),
      );
      if (customer.name.isNotEmpty) {
        customer.totalPurchases += bill.totalAmount;
        if (bill.status != BillStatus.paid) {
          customer.outstandingBalance += bill.balanceDue;
        }
        await _db.updateCustomer(customer);
      }
    }

    await Future.wait([
      loadBills(),
      loadItems(),
      loadCustomers(),
      loadDashboardStats(),
    ]);
  }

  Future<void> deleteBill(String id) async {
    await _db.deleteBill(id);
    await loadBills();
    await loadDashboardStats();
  }

  Future<List<Bill>> getBillsByDate(DateTime date) async {
    return await _db.getBillsByDate(date);
  }

  // ===== DASHBOARD =====

  Future<void> loadDashboardStats() async {
    _dashboardStats = await _db.getDashboardStats();
    notifyListeners();
  }

  // ===== SETTINGS =====

  Future<void> saveSetting(String key, String value) async {
    await _db.setSetting(key, value);
  }

  Future<String?> getSetting(String key) async {
    return await _db.getSetting(key);
  }

  Future<Map<String, String>> getAllSettings() async {
    return await _db.getAllSettings();
  }
}
