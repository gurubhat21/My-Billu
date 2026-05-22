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
import '../models/supplier.dart';
import '../models/recurring_bill.dart';
import '../models/audit_entry.dart';
import '../models/cash_book.dart';
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
  List<Supplier> _suppliers = [];
  List<RecurringBill> _recurringBills = [];
  List<AuditEntry> _auditLog = [];
  List<CashBookEntry> _cashBookEntries = [];
  List<BankAccount> _bankAccounts = [];
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
  List<Supplier> get suppliers => _suppliers;
  List<RecurringBill> get recurringBills => _recurringBills;
  List<AuditEntry> get auditLog => _auditLog;
  List<CashBookEntry> get cashBookEntries => _cashBookEntries;
  List<BankAccount> get bankAccounts => _bankAccounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ===== INITIALIZATION =====

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Load each independently so one failure doesn't block others
      final loaders = <Future<void> Function()>[
        loadItems,
        loadCustomers,
        loadBills,
        loadPurchases,
        loadDashboardStats,
        loadQuotations,
        loadExpenses,
        loadCreditNotes,
        loadPurchaseReturns,
        loadSuppliers,
        loadRecurringBills,
        _loadAuditLog,
        _loadCashBook,
        _loadBankAccounts,
      ];
      await Future.wait(loaders.map((fn) async {
        try { await fn(); } catch (e) { debugPrint('Load error: $e'); }
      }));
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('LoadAll critical error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== AUDIT TRAIL =====

  Future<void> _loadAuditLog() async {
    final json = await _db.getSetting('audit_log');
    if (json != null && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List;
        _auditLog = list.map((e) => AuditEntry.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _auditLog = [];
      }
    }
  }

  Future<void> _saveAuditLog() async {
    // Keep last 500 entries
    if (_auditLog.length > 500) {
      _auditLog = _auditLog.sublist(0, 500);
    }
    final json = jsonEncode(_auditLog.map((e) => e.toMap()).toList());
    await _db.setSetting('audit_log', json);
  }

  Future<void> logAudit(AuditAction action, AuditEntity entity, String name, {String? details}) async {
    _auditLog.insert(0, AuditEntry(
      action: action, entity: entity, entityName: name, details: details));
    await _saveAuditLog();
    notifyListeners();
  }

  Future<void> clearAuditLog() async {
    _auditLog.clear();
    await _saveAuditLog();
    notifyListeners();
  }

  // ===== ITEMS =====

  Future<void> loadItems() async {
    _items = await _db.getAllItems();
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    await _db.insertItem(item);
    await logAudit(AuditAction.created, AuditEntity.item, item.name, details: '₹${item.price.toStringAsFixed(2)}, Stock: ${item.stockQuantity}');
    await loadItems();
    await loadDashboardStats();
  }

  Future<void> updateItem(Item item) async {
    await _db.updateItem(item);
    await logAudit(AuditAction.updated, AuditEntity.item, item.name);
    await loadItems();
  }

  Future<void> deleteItem(String id) async {
    final item = _items.firstWhere((i) => i.id == id, orElse: () => Item(name: 'Unknown', price: 0));
    await _db.deleteItem(id);
    await logAudit(AuditAction.deleted, AuditEntity.item, item.name);
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
    await logAudit(AuditAction.created, AuditEntity.customer, customer.name, details: customer.phone);
    await loadCustomers();
    await loadDashboardStats();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.updateCustomer(customer);
    await logAudit(AuditAction.updated, AuditEntity.customer, customer.name);
    await loadCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    final cust = _customers.firstWhere((c) => c.id == id, orElse: () => Customer(name: 'Unknown'));
    await _db.deleteCustomer(id);
    await logAudit(AuditAction.deleted, AuditEntity.customer, cust.name);
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
    await logAudit(AuditAction.created, AuditEntity.purchase, purchase.purchaseNumber, details: '₹${purchase.totalAmount.toStringAsFixed(2)} from ${purchase.supplierName}');

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
    final p = _purchases.firstWhere((p) => p.id == id, orElse: () => Purchase(purchaseNumber: '?', supplierName: '?', items: [], subtotal: 0, totalTax: 0, totalAmount: 0));
    await _db.deletePurchase(id);
    await logAudit(AuditAction.deleted, AuditEntity.purchase, p.purchaseNumber);
    await loadPurchases();
    await loadDashboardStats();
  }

  Future<void> updatePurchase(Purchase purchase) async {
    await _db.updatePurchase(purchase);
    await logAudit(AuditAction.updated, AuditEntity.purchase, purchase.purchaseNumber, details: 'Paid: ₹${purchase.paidAmount.toStringAsFixed(2)} / ₹${purchase.totalAmount.toStringAsFixed(2)}');
    await loadPurchases();
    notifyListeners();
  }

  // ===== BILLS =====

  Future<void> loadBills() async {
    _bills = await _db.getAllBills();
    notifyListeners();
  }

  Future<String> getNextBillNumber() async {
    final pattern = await getSetting('invoice_pattern');
    final prefix = await getSetting('invoice_prefix') ?? 'INV';
    final startNum = int.tryParse(await getSetting('invoice_start_number') ?? '1') ?? 1;
    final count = _bills.length;
    final num = count + startNum;
    final now = DateTime.now();
    if (pattern == null || pattern.isEmpty) {
      return '$prefix${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}-${num.toString().padLeft(4, '0')}';
    }
    var result = pattern
      .replaceAll('{PREFIX}', prefix)
      .replaceAll('{YYYY}', now.year.toString())
      .replaceAll('{YY}', now.year.toString().substring(2))
      .replaceAll('{MM}', now.month.toString().padLeft(2, '0'))
      .replaceAll('{DD}', now.day.toString().padLeft(2, '0'))
      .replaceAll('{NUM5}', num.toString().padLeft(5, '0'))
      .replaceAll('{NUM4}', num.toString().padLeft(4, '0'))
      .replaceAll('{NUM3}', num.toString().padLeft(3, '0'))
      .replaceAll('{NUM}', num.toString());
    return result;
  }

  Future<void> createBill(Bill bill) async {
    await _db.insertBill(bill);
    await logAudit(AuditAction.created, AuditEntity.bill, bill.billNumber, details: '₹${bill.totalAmount.toStringAsFixed(2)} - ${bill.customerName ?? "Walk-in"}');

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
    final bill = _bills.firstWhere((b) => b.id == id, orElse: () => Bill(billNumber: '?', items: [], subtotal: 0, totalTax: 0, totalAmount: 0));
    await _db.deleteBill(id);
    await logAudit(AuditAction.deleted, AuditEntity.bill, bill.billNumber);
    await loadBills();
    await loadDashboardStats();
  }

  Future<void> collectPayment(String billId, double amount, {String paymentType = 'cash', String? bankAccountId}) async {
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

    // Auto-create cash/bank book entry
    final TransactionType txType;
    if (paymentType == 'cash') {
      txType = TransactionType.cashIn;
    } else {
      txType = TransactionType.bankIn;
    }
    final entry = CashBookEntry(
      type: txType,
      amount: amount,
      description: 'Payment collected - ${bill.billNumber} (${bill.customerName ?? "Walk-in"})',
      reference: bill.billNumber,
      bankAccountId: paymentType != 'cash' ? bankAccountId : null,
      category: 'Sales Collection',
    );
    await addCashBookEntry(entry);

    await Future.wait([loadBills(), loadCustomers(), loadDashboardStats()]);
  }

  Future<List<Bill>> getBillsByDate(DateTime date) async {
    return await _db.getBillsByDate(date);
  }

  Future<void> updateBillRecord(Bill bill) async {
    await _db.updateBill(bill);
    await Future.wait([loadBills(), loadDashboardStats()]);
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

  // ===== SUPPLIERS =====

  Future<void> loadSuppliers() async {
    final json = await _db.getSetting('suppliers_data');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      _suppliers = list.map((e) => Supplier.fromMap(e as Map<String, dynamic>)).toList();
    }
    notifyListeners();
  }

  Future<void> _saveSuppliers() async {
    final json = jsonEncode(_suppliers.map((e) => e.toMap()).toList());
    await _db.setSetting('suppliers_data', json);
  }

  Future<void> addSupplier(Supplier s) async {
    _suppliers.add(s);
    await _saveSuppliers();
    notifyListeners();
  }

  Future<void> updateSupplier(Supplier s) async {
    final idx = _suppliers.indexWhere((e) => e.id == s.id);
    if (idx >= 0) _suppliers[idx] = s;
    await _saveSuppliers();
    notifyListeners();
  }

  Future<void> deleteSupplier(String id) async {
    _suppliers.removeWhere((e) => e.id == id);
    await _saveSuppliers();
    notifyListeners();
  }

  // ===== RECURRING BILLS =====

  Future<void> loadRecurringBills() async {
    final json = await _db.getSetting('recurring_bills_data');
    if (json != null && json.isNotEmpty) {
      final list = jsonDecode(json) as List;
      _recurringBills = list.map((e) => RecurringBill.fromMap(e as Map<String, dynamic>)).toList();
    }
    notifyListeners();
  }

  Future<void> _saveRecurringBills() async {
    final json = jsonEncode(_recurringBills.map((e) => e.toMap()).toList());
    await _db.setSetting('recurring_bills_data', json);
  }

  Future<void> addRecurringBill(RecurringBill rb) async {
    _recurringBills.add(rb);
    await _saveRecurringBills();
    notifyListeners();
  }

  Future<void> toggleRecurringBill(String id) async {
    final idx = _recurringBills.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _recurringBills[idx] = _recurringBills[idx].copyWith(isActive: !_recurringBills[idx].isActive);
      await _saveRecurringBills();
      notifyListeners();
    }
  }

  Future<void> deleteRecurringBill(String id) async {
    _recurringBills.removeWhere((e) => e.id == id);
    await _saveRecurringBills();
    notifyListeners();
  }

  /// Generate bills for all due recurring bills
  Future<int> processRecurringBills() async {
    int generated = 0;
    final now = DateTime.now();
    for (int i = 0; i < _recurringBills.length; i++) {
      final rb = _recurringBills[i];
      if (!rb.isActive) continue;
      if (rb.endDate != null && now.isAfter(rb.endDate!)) continue;
      if (now.isBefore(rb.nextDueDate)) continue;

      // Generate bill
      final billNum = await getNextBillNumber();
      final bill = Bill(
        billNumber: billNum,
        customerId: rb.customerId,
        customerName: rb.customerName,
        items: rb.items,
        subtotal: rb.items.fold(0.0, (s, i) => s + i.subtotal),
        totalTax: rb.items.fold(0.0, (s, i) => s + i.taxAmount),
        totalAmount: rb.totalAmount,
        discount: 0,
        paymentMethod: rb.paymentMethod,
        status: BillStatus.unpaid,
      );
      await createBill(bill);
      generated++;

      // Advance next due date
      DateTime next = rb.nextDueDate;
      switch (rb.frequency) {
        case RecurringFrequency.weekly: next = next.add(const Duration(days: 7));
        case RecurringFrequency.monthly: next = DateTime(next.year, next.month + 1, next.day);
        case RecurringFrequency.quarterly: next = DateTime(next.year, next.month + 3, next.day);
        case RecurringFrequency.yearly: next = DateTime(next.year + 1, next.month, next.day);
      }
      _recurringBills[i] = rb.copyWith(nextDueDate: next);
    }
    if (generated > 0) await _saveRecurringBills();
    return generated;
  }

  // ===== CASH BOOK =====

  Future<void> _loadCashBook() async {
    final json = await _db.getSetting('cash_book_entries');
    if (json != null && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List;
        _cashBookEntries = list.map((e) => CashBookEntry.fromMap(e as Map<String, dynamic>)).toList();
        _cashBookEntries.sort((a, b) => b.date.compareTo(a.date));
      } catch (_) { _cashBookEntries = []; }
    }
  }

  Future<void> _saveCashBook() async {
    final json = jsonEncode(_cashBookEntries.map((e) => e.toMap()).toList());
    await _db.setSetting('cash_book_entries', json);
  }

  Future<void> addCashBookEntry(CashBookEntry entry) async {
    _cashBookEntries.insert(0, entry);
    // Update bank balance if bank transaction
    if (entry.bankAccountId != null) {
      final idx = _bankAccounts.indexWhere((a) => a.id == entry.bankAccountId);
      if (idx >= 0) {
        if (entry.type == TransactionType.bankIn) {
          _bankAccounts[idx].balance += entry.amount;
        } else if (entry.type == TransactionType.bankOut) {
          _bankAccounts[idx].balance -= entry.amount;
        }
        await _saveBankAccounts();
      }
    }
    await _saveCashBook();
    await logAudit(AuditAction.created, AuditEntity.item, entry.description, details: '${entry.typeLabel}: \u20b9${entry.amount.toStringAsFixed(2)}');
    notifyListeners();
  }

  Future<void> deleteCashBookEntry(String id) async {
    final entry = _cashBookEntries.firstWhere((e) => e.id == id, orElse: () => CashBookEntry(type: TransactionType.cashIn, amount: 0, description: ''));
    // Reverse bank balance
    if (entry.bankAccountId != null) {
      final idx = _bankAccounts.indexWhere((a) => a.id == entry.bankAccountId);
      if (idx >= 0) {
        if (entry.type == TransactionType.bankIn) {
          _bankAccounts[idx].balance -= entry.amount;
        } else if (entry.type == TransactionType.bankOut) {
          _bankAccounts[idx].balance += entry.amount;
        }
        await _saveBankAccounts();
      }
    }
    _cashBookEntries.removeWhere((e) => e.id == id);
    await _saveCashBook();
    notifyListeners();
  }

  // ===== BANK ACCOUNTS =====

  Future<void> _loadBankAccounts() async {
    final json = await _db.getSetting('bank_accounts');
    if (json != null && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List;
        _bankAccounts = list.map((e) => BankAccount.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) { _bankAccounts = []; }
    }
  }

  Future<void> _saveBankAccounts() async {
    final json = jsonEncode(_bankAccounts.map((a) => a.toMap()).toList());
    await _db.setSetting('bank_accounts', json);
  }

  Future<void> addBankAccount(BankAccount account) async {
    _bankAccounts.add(account);
    await _saveBankAccounts();
    await logAudit(AuditAction.created, AuditEntity.setting, account.bankName, details: 'Bank account added');
    notifyListeners();
  }

  Future<void> updateBankAccount(BankAccount account) async {
    final idx = _bankAccounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _bankAccounts[idx] = account;
    await _saveBankAccounts();
    await logAudit(AuditAction.updated, AuditEntity.setting, account.bankName, details: 'Bank account updated');
    notifyListeners();
  }

  Future<void> deleteBankAccount(String id) async {
    final acc = _bankAccounts.firstWhere((a) => a.id == id, orElse: () => BankAccount(bankName: '?', accountNumber: '?'));
    _bankAccounts.removeWhere((a) => a.id == id);
    await _saveBankAccounts();
    await logAudit(AuditAction.deleted, AuditEntity.setting, acc.bankName, details: 'Bank account deleted');
    notifyListeners();
  }
}


