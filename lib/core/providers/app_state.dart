import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/purchase.dart';
import '../models/quotation.dart';
import '../models/expense.dart';
import '../models/credit_note.dart';
import '../models/purchase_return.dart';
import 'dart:convert';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Item> _items = [];
  List<Customer> _customers = [];
  List<Bill> _bills = [];
  List<Purchase> _purchases = [];
  Map<String, dynamic> _dashboardStats = {};
  List<Quotation> _quotations = [];
  List<Expense> _expenses = [];
  List<CreditNote> _creditNotes = [];
  List<PurchaseReturn> _purchaseReturns = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Item> get items => _items;
  List<Customer> get customers => _customers;
  List<Bill> get bills => _bills;
  List<Purchase> get purchases => _purchases;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<Quotation> get quotations => _quotations;
  List<Expense> get expenses => _expenses;
  List<CreditNote> get creditNotes => _creditNotes;
  List<PurchaseReturn> get purchaseReturns => _purchaseReturns;
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
        loadPurchases(),
        loadDashboardStats(),
        loadQuotations(),
        loadExpenses(),
        loadCreditNotes(),
        loadPurchaseReturns(),
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

  // ===== PURCHASES =====

  Future<void> loadPurchases() async {
    _purchases = await _db.getAllPurchases();
    notifyListeners();
  }

  Future<String> getNextPurchaseNumber() async {
    return await _db.getNextPurchaseNumber();
  }

  Future<void> createPurchase(Purchase purchase) async {
    await _db.insertPurchase(purchase);

    // Update stock quantities for received purchases
    if (purchase.status == PurchaseStatus.received) {
      for (final purchaseItem in purchase.items) {
        final item = _items.firstWhere(
          (i) => i.id == purchaseItem.itemId,
          orElse: () => Item(name: '', price: 0),
        );
        if (item.name.isNotEmpty) {
          item.stockQuantity += purchaseItem.quantity;
          await _db.updateItem(item);
        }
      }
    }

    await Future.wait([
      loadPurchases(),
      loadItems(),
      loadDashboardStats(),
    ]);
  }

  Future<void> deletePurchase(String id) async {
    await _db.deletePurchase(id);
    await loadPurchases();
    await loadDashboardStats();
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

  Future<void> collectPayment(String billId, double amount) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    bill.paidAmount += amount;
    if (bill.paidAmount >= bill.totalAmount) {
      bill.paidAmount = bill.totalAmount;
      bill.status = BillStatus.paid;
    } else {
      bill.status = BillStatus.partial;
    }
    await _db.updateBill(bill);

    // Update customer outstanding
    if (bill.customerId != null) {
      final customer = _customers.firstWhere(
        (c) => c.id == bill.customerId,
        orElse: () => Customer(name: ''),
      );
      if (customer.name.isNotEmpty) {
        customer.outstandingBalance -= amount;
        if (customer.outstandingBalance < 0) customer.outstandingBalance = 0;
        await _db.updateCustomer(customer);
      }
    }

    await Future.wait([loadBills(), loadCustomers(), loadDashboardStats()]);
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

  // ===== QUOTATIONS =====

  Future<void> loadQuotations() async {
    final json = await _db.getSetting('quotations_data');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      _quotations = list.map((e) => Quotation.fromMap(e as Map<String, dynamic>)).toList();
    }
    _quotations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _saveQuotations() async {
    final json = jsonEncode(_quotations.map((q) => q.toMap()).toList());
    await _db.setSetting('quotations_data', json);
  }

  Future<void> addQuotation(Quotation q) async {
    _quotations.insert(0, q);
    await _saveQuotations();
    notifyListeners();
  }

  Future<void> updateQuotation(Quotation q) async {
    final idx = _quotations.indexWhere((e) => e.id == q.id);
    if (idx >= 0) _quotations[idx] = q;
    await _saveQuotations();
    notifyListeners();
  }

  Future<void> deleteQuotation(String id) async {
    _quotations.removeWhere((e) => e.id == id);
    await _saveQuotations();
    notifyListeners();
  }

  String getNextQuotationNumber() {
    final count = _quotations.length + 1;
    return 'QT-${count.toString().padLeft(4, '0')}';
  }

  // ===== EXPENSES =====

  Future<void> loadExpenses() async {
    final json = await _db.getSetting('expenses_data');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      _expenses = list.map((e) => Expense.fromMap(e as Map<String, dynamic>)).toList();
    }
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> _saveExpenses() async {
    final json = jsonEncode(_expenses.map((e) => e.toMap()).toList());
    await _db.setSetting('expenses_data', json);
  }

  Future<void> addExpense(Expense e) async {
    _expenses.insert(0, e);
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> updateExpense(Expense e) async {
    final idx = _expenses.indexWhere((x) => x.id == e.id);
    if (idx >= 0) _expenses[idx] = e;
    await _saveExpenses();
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _saveExpenses();
    notifyListeners();
  }

  double get totalExpenses => _expenses.fold(0, (s, e) => s + e.amount);

  // ===== CREDIT NOTES =====

  Future<void> loadCreditNotes() async {
    final json = await _db.getSetting('credit_notes_data');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      _creditNotes = list.map((e) => CreditNote.fromMap(e as Map<String, dynamic>)).toList();
    }
    _creditNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _saveCreditNotes() async {
    final json = jsonEncode(_creditNotes.map((e) => e.toMap()).toList());
    await _db.setSetting('credit_notes_data', json);
  }

  Future<void> addCreditNote(CreditNote cn) async {
    _creditNotes.insert(0, cn);
    // Restore stock for returned items
    for (final item in cn.items) {
      final stockItem = _items.firstWhere((i) => i.id == item.itemId, orElse: () => Item(name: '', price: 0));
      if (stockItem.name.isNotEmpty) {
        stockItem.stockQuantity += item.quantity;
        await _db.updateItem(stockItem);
      }
    }
    await _saveCreditNotes();
    await loadItems();
    notifyListeners();
  }

  Future<void> deleteCreditNote(String id) async {
    _creditNotes.removeWhere((e) => e.id == id);
    await _saveCreditNotes();
    notifyListeners();
  }

  String getNextCreditNoteNumber() {
    final count = _creditNotes.length + 1;
    return 'CN-${count.toString().padLeft(4, '0')}';
  }

  // ===== PURCHASE RETURNS =====

  Future<void> loadPurchaseReturns() async {
    final json = await _db.getSetting('purchase_returns_data');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      _purchaseReturns = list.map((e) => PurchaseReturn.fromMap(e as Map<String, dynamic>)).toList();
    }
    _purchaseReturns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _savePurchaseReturns() async {
    final json = jsonEncode(_purchaseReturns.map((e) => e.toMap()).toList());
    await _db.setSetting('purchase_returns_data', json);
  }

  Future<void> addPurchaseReturn(PurchaseReturn pr) async {
    _purchaseReturns.insert(0, pr);
    // Deduct returned stock
    for (final item in pr.items) {
      final stockItem = _items.firstWhere((i) => i.id == item.itemId, orElse: () => Item(name: '', price: 0));
      if (stockItem.name.isNotEmpty) {
        stockItem.stockQuantity -= item.quantity;
        if (stockItem.stockQuantity < 0) stockItem.stockQuantity = 0;
        await _db.updateItem(stockItem);
      }
    }
    await _savePurchaseReturns();
    await loadItems();
    notifyListeners();
  }

  Future<void> deletePurchaseReturn(String id) async {
    _purchaseReturns.removeWhere((e) => e.id == id);
    await _savePurchaseReturns();
    notifyListeners();
  }

  String getNextPurchaseReturnNumber() {
    final count = _purchaseReturns.length + 1;
    return 'PR-${count.toString().padLeft(4, '0')}';
  }

  // ===== CUSTOMER LEDGER =====

  List<Map<String, dynamic>> getCustomerLedger(String customerId) {
    final entries = <Map<String, dynamic>>[];
    // Bills (debit)
    for (final b in _bills.where((b) => b.customerId == customerId)) {
      entries.add({'date': b.createdAt, 'type': 'Invoice', 'ref': b.billNumber, 'debit': b.totalAmount, 'credit': 0.0});
      if (b.paidAmount > 0) {
        entries.add({'date': b.createdAt, 'type': 'Payment', 'ref': b.billNumber, 'debit': 0.0, 'credit': b.paidAmount});
      }
    }
    // Credit notes (credit)
    for (final cn in _creditNotes.where((c) => c.customerId == customerId)) {
      entries.add({'date': cn.createdAt, 'type': 'Credit Note', 'ref': cn.creditNoteNumber, 'debit': 0.0, 'credit': cn.totalAmount});
    }
    entries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return entries;
  }
}
