import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/models/supplier.dart';
import '../../core/models/bill.dart';
import '../../core/models/purchase.dart';
import '../../core/models/expense.dart';
import '../../core/models/credit_note.dart';
import '../../core/models/purchase_return.dart';
import '../../core/models/cash_book.dart';
import '../../core/models/quotation.dart';
import '../../core/database/full_backup_exporter.dart';
import '../../core/utils/excel_importer.dart';
import '../../core/utils/web_helper_stub.dart' if (dart.library.html) '../../core/utils/web_helper.dart' as web_helper;
import '../../widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});
  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _busy = false;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import & Export', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(controller: _tabCtrl, tabs: const [
          Tab(icon: Icon(Icons.upload), text: 'Import'),
          Tab(icon: Icon(Icons.download), text: 'Export'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildImportTab(context, isDark),
        _buildExportTab(context, isDark),
      ]),
    );
  }

  // ===== IMPORT TAB =====
  Widget _buildImportTab(BuildContext ctx, bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // JSON Full Restore
      _sectionCard(ctx, isDark, Icons.restore, 'Restore Full Backup (JSON)', 'Restore all data from a JSON backup file',
        [Color(0xFF7C3AED), Color(0xFF6D28D9)], [
        _actionBtn('Import JSON Backup', Icons.file_open, const Color(0xFF7C3AED), () => _restoreJson(ctx)),
      ]),
      const SizedBox(height: 16),

      // Excel Import
      _sectionCard(ctx, isDark, Icons.table_chart, 'Import from Excel (.xlsx)', 'Upload Excel files. First row = headers.',
        [AppColors.primary, Color(0xFF3730A3)], [
        _importRow(ctx, Icons.inventory_2, 'Items', 'Name, Price, Tax%, HSN, Unit, Stock, Category', () => _importExcel(ctx, 'items')),
        _importRow(ctx, Icons.people, 'Customers', 'Name, Phone, Email, Address, GSTIN', () => _importExcel(ctx, 'customers')),
        _importRow(ctx, Icons.local_shipping, 'Suppliers', 'Name, Phone, Email, Address, GSTIN', () => _importExcel(ctx, 'suppliers')),
        _importRow(ctx, Icons.receipt_long, 'Bills/Ledger', 'BillNo, Date, Customer, Subtotal, Tax, Total, Paid, Status', () => _importExcel(ctx, 'bills')),
      ]),
      const SizedBox(height: 16),

      // CSV Import
      _sectionCard(ctx, isDark, Icons.description, 'Import from CSV', 'Import comma-separated data files',
        [Color(0xFF059669), Color(0xFF047857)], [
        _importRow(ctx, Icons.inventory_2, 'Items (CSV)', 'Name, Price, Tax, HSN, Unit, Stock', () => _importCsv(ctx, 'items')),
        _importRow(ctx, Icons.people, 'Customers (CSV)', 'Name, Phone, Email, Address, GSTIN', () => _importCsv(ctx, 'customers')),
      ]),
    ]));
  }

  // ===== EXPORT TAB =====
  Widget _buildExportTab(BuildContext ctx, bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Full Backup
      _sectionCard(ctx, isDark, Icons.backup, 'Full Backup', 'Export everything as JSON or Excel',
        [Color(0xFF7C3AED), Color(0xFF6D28D9)], [
        _actionBtn('Export Full Backup (JSON)', Icons.data_object, const Color(0xFF7C3AED), () => _exportJson(ctx)),
        const SizedBox(height: 8),
        _actionBtn('Export Full Backup (Excel)', Icons.grid_on, const Color(0xFF6D28D9), () => _exportExcel(ctx)),
      ]),
      const SizedBox(height: 16),

      // Individual Excel Exports
      _sectionCard(ctx, isDark, Icons.table_chart, 'Export Individual Excel', 'Export each data type as separate .xlsx file',
        [AppColors.primary, Color(0xFF3730A3)], [
        _actionBtn('Export Items', Icons.inventory_2, AppColors.primary, () => _exportSingleExcel(ctx, 'items')),
        const SizedBox(height: 8),
        _actionBtn('Export Customers', Icons.people, AppColors.primary, () => _exportSingleExcel(ctx, 'customers')),
        const SizedBox(height: 8),
        _actionBtn('Export Sales / Bills', Icons.receipt_long, AppColors.primary, () => _exportSingleExcel(ctx, 'bills')),
        const SizedBox(height: 8),
        _actionBtn('Export Purchases', Icons.shopping_bag, AppColors.primary, () => _exportSingleExcel(ctx, 'purchases')),
        const SizedBox(height: 8),
        _actionBtn('Export Suppliers', Icons.local_shipping, AppColors.primary, () => _exportSingleExcel(ctx, 'suppliers')),
        const SizedBox(height: 8),
        _actionBtn('Export Expenses', Icons.money_off, AppColors.primary, () => _exportSingleExcel(ctx, 'expenses')),
        const SizedBox(height: 8),
        _actionBtn('Export Quotations', Icons.description, AppColors.primary, () => _exportSingleExcel(ctx, 'quotations')),
      ]),
    ]));
  }

  // ===== UI HELPERS =====
  Widget _sectionCard(BuildContext ctx, bool isDark, IconData icon, String title, String sub, List<Color> colors, List<Widget> children) {
    return GlassCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 22, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          Text(sub, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
        ])),
      ]),
      const SizedBox(height: 16),
      ...children,
    ]));
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14)),
      onPressed: _busy ? null : onTap,
      icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon, size: 18),
      label: Text(label),
    ));
  }

  Widget _importRow(BuildContext ctx, IconData icon, String label, String hint, VoidCallback onTap) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))),
        child: Row(children: [
          Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(hint, style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black26)),
          ])),
          Icon(Icons.upload_file, size: 18, color: isDark ? Colors.white30 : Colors.black26),
        ]),
      ),
    ));
  }

  void _msg(String text, {bool ok = true}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text), backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  // ===== IMPORT LOGIC =====
  Future<void> _restoreJson(BuildContext ctx) async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (result == null || result.files.isEmpty) { setState(() => _busy = false); return; }
      final bytes = result.files.first.bytes ?? (await _readFileBytes(result.files.first.path));
      if (bytes == null) { setState(() => _busy = false); _msg('Could not read file', ok: false); return; }
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() => _busy = false);
      if (!mounted) return;

      final confirm = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This will ADD data to your current data.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Items: ${(data['items'] as List?)?.length ?? 0}'),
          Text('Customers: ${(data['customers'] as List?)?.length ?? 0}'),
          Text('Bills: ${(data['bills'] as List?)?.length ?? 0}'),
          Text('Purchases: ${(data['purchases'] as List?)?.length ?? 0}'),
          Text('Expenses: ${(data['expenses'] as List?)?.length ?? 0}'),
          Text('Settings: ${(data['settings'] as Map?)?.length ?? 0} keys'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
        ],
      ));
      if (confirm != true || !mounted) return;

      setState(() => _busy = true);
      final appState = ctx.read<AppState>();
      int total = 0;
      total += await _bulkAdd(data, 'items', (m) => appState.addItem(Item.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'customers', (m) => appState.addCustomer(Customer.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'bills', (m) => appState.createBill(Bill.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'purchases', (m) => appState.createPurchase(Purchase.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'quotations', (m) => appState.addQuotation(Quotation.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'expenses', (m) => appState.addExpense(Expense.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'creditNotes', (m) => appState.addCreditNote(CreditNote.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'purchaseReturns', (m) => appState.addPurchaseReturn(PurchaseReturn.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'suppliers', (m) => appState.addSupplier(Supplier.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'cashBookEntries', (m) => appState.addCashBookEntry(CashBookEntry.fromMap(Map<String, dynamic>.from(m))));
      total += await _bulkAdd(data, 'bankAccounts', (m) => appState.addBankAccount(BankAccount.fromMap(Map<String, dynamic>.from(m))));
      if (data['settings'] != null) {
        for (final e in (data['settings'] as Map<String, dynamic>).entries) {
          await appState.saveSetting(e.key, e.value.toString());
        }
      }
      await appState.loadAll();
      setState(() => _busy = false);
      _msg('✅ Restored $total records successfully!');
    } catch (e) {
      setState(() => _busy = false);
      _msg('Restore failed: $e', ok: false);
    }
  }

  Future<int> _bulkAdd(Map<String, dynamic> data, String key, Future<void> Function(dynamic) addFn) async {
    final list = data[key] as List?;
    if (list == null) return 0;
    int count = 0;
    for (final m in list) { try { await addFn(m); count++; } catch (_) {} }
    return count;
  }

  Future<void> _importExcel(BuildContext ctx, String type) async {
    setState(() => _busy = true);
    try {
      final appState = ctx.read<AppState>();
      int added = 0, total = 0;
      switch (type) {
        case 'items':
          final items = await ExcelImporter.importItems();
          if (items == null) { setState(() => _busy = false); return; }
          total = items.length;
          for (final i in items) { try { await appState.addItem(i); added++; } catch (_) {} }
        case 'customers':
          final list = await ExcelImporter.importCustomers();
          if (list == null) { setState(() => _busy = false); return; }
          total = list.length;
          for (final c in list) { try { await appState.addCustomer(c); added++; } catch (_) {} }
        case 'suppliers':
          final list = await ExcelImporter.importSuppliers();
          if (list == null) { setState(() => _busy = false); return; }
          total = list.length;
          for (final s in list) { try { await appState.addSupplier(s); added++; } catch (_) {} }
        case 'bills':
          final list = await ExcelImporter.importLedger();
          if (list == null) { setState(() => _busy = false); return; }
          total = list.length;
          for (final b in list) { try { await appState.createBill(b); added++; } catch (_) {} }
      }
      setState(() => _busy = false);
      _msg('Imported $added / $total $type');
    } catch (e) {
      setState(() => _busy = false);
      _msg('Import failed: $e', ok: false);
    }
  }

  Future<void> _importCsv(BuildContext ctx, String type) async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (result == null || result.files.isEmpty) { setState(() => _busy = false); return; }
      final bytes = result.files.first.bytes ?? (await _readFileBytes(result.files.first.path));
      if (bytes == null) { setState(() => _busy = false); _msg('Could not read file', ok: false); return; }
      final csvStr = utf8.decode(bytes);
      final lines = csvStr.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) { setState(() => _busy = false); _msg('CSV must have header + data rows', ok: false); return; }

      final appState = ctx.read<AppState>();
      int added = 0;
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',').map((c) => c.trim()).toList();
        try {
          if (type == 'items' && cols.length >= 2) {
            await appState.addItem(Item(name: cols[0], price: double.tryParse(cols[1]) ?? 0,
              taxRate: cols.length > 2 ? double.tryParse(cols[2]) ?? 0 : 0,
              hsnCode: cols.length > 3 ? cols[3] : '', unit: cols.length > 4 ? cols[4] : 'pcs',
              stockQuantity: cols.length > 5 ? int.tryParse(cols[5]) ?? 0 : 0));
            added++;
          } else if (type == 'customers' && cols.length >= 1) {
            await appState.addCustomer(Customer(name: cols[0],
              phone: cols.length > 1 ? cols[1] : '', email: cols.length > 2 ? cols[2] : '',
              address: cols.length > 3 ? cols[3] : '', gstin: cols.length > 4 ? cols[4] : ''));
            added++;
          }
        } catch (_) {}
      }
      setState(() => _busy = false);
      _msg('Imported $added / ${lines.length - 1} $type from CSV');
    } catch (e) {
      setState(() => _busy = false);
      _msg('CSV import failed: $e', ok: false);
    }
  }

  // ===== EXPORT LOGIC =====
  Future<void> _exportJson(BuildContext ctx) async {
    setState(() => _busy = true);
    try {
      final appState = ctx.read<AppState>();
      final settings = await appState.getAllSettings();
      final backup = {
        'version': '2.0.0', 'timestamp': DateTime.now().toIso8601String(), 'app': 'My Billu - Full Backup',
        'items': appState.items.map((i) => i.toMap()).toList(),
        'customers': appState.customers.map((c) => c.toMap()).toList(),
        'bills': appState.bills.map((b) => b.toMap()).toList(),
        'purchases': appState.purchases.map((p) => p.toMap()).toList(),
        'quotations': appState.quotations.map((q) => q.toMap()).toList(),
        'expenses': appState.expenses.map((e) => e.toMap()).toList(),
        'creditNotes': appState.creditNotes.map((c) => c.toMap()).toList(),
        'purchaseReturns': appState.purchaseReturns.map((p) => p.toMap()).toList(),
        'suppliers': appState.suppliers.map((s) => s.toMap()).toList(),
        'recurringBills': appState.recurringBills.map((r) => r.toMap()).toList(),
        'cashBookEntries': appState.cashBookEntries.map((e) => e.toMap()).toList(),
        'bankAccounts': appState.bankAccounts.map((a) => a.toMap()).toList(),
        'settings': settings,
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      web_helper.downloadJson(jsonStr, 'mybillu_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      setState(() => _busy = false);
      _msg('✅ Full backup exported!');
    } catch (e) {
      setState(() => _busy = false);
      _msg('Export failed: $e', ok: false);
    }
  }

  Future<void> _exportExcel(BuildContext ctx) async {
    setState(() => _busy = true);
    try {
      final appState = ctx.read<AppState>();
      final bytes = await FullBackupExporter.exportAll(
        items: appState.items, customers: appState.customers, bills: appState.bills,
        purchases: appState.purchases, expenses: appState.expenses, suppliers: appState.suppliers);
      await Printing.sharePdf(bytes: bytes, filename: 'MyBillu_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      setState(() => _busy = false);
      _msg('✅ Excel exported!');
    } catch (e) {
      setState(() => _busy = false);
      _msg('Excel export failed: $e', ok: false);
    }
  }

  Future<void> _exportSingleExcel(BuildContext ctx, String type) async {
    setState(() => _busy = true);
    try {
      final appState = ctx.read<AppState>();
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      String filename = type;

      switch (type) {
        case 'items':
          sheet.appendRow([TextCellValue('Name'), TextCellValue('Price'), TextCellValue('Tax %'), TextCellValue('HSN'), TextCellValue('Unit'), TextCellValue('Stock'), TextCellValue('Category')]);
          for (final i in appState.items) {
            sheet.appendRow([TextCellValue(i.name), DoubleCellValue(i.price), DoubleCellValue(i.taxRate),
              TextCellValue(i.hsnCode ?? ''), TextCellValue(i.unit), IntCellValue(i.stockQuantity), TextCellValue(i.category ?? '')]);
          }
          filename = 'Items_${appState.items.length}';
        case 'customers':
          sheet.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Email'), TextCellValue('Address'), TextCellValue('GSTIN'), TextCellValue('Total Purchases'), TextCellValue('Outstanding')]);
          for (final c in appState.customers) {
            sheet.appendRow([TextCellValue(c.name), TextCellValue(c.phone ?? ''), TextCellValue(c.email ?? ''),
              TextCellValue(c.address ?? ''), TextCellValue(c.gstin ?? ''), DoubleCellValue(c.totalPurchases), DoubleCellValue(c.outstandingBalance)]);
          }
          filename = 'Customers_${appState.customers.length}';
        case 'bills':
          sheet.appendRow([TextCellValue('Bill No'), TextCellValue('Date'), TextCellValue('Customer'), TextCellValue('Subtotal'), TextCellValue('Tax'), TextCellValue('Total'), TextCellValue('Paid'), TextCellValue('Balance'), TextCellValue('Status'), TextCellValue('Payment')]);
          for (final b in appState.bills) {
            sheet.appendRow([TextCellValue(b.billNumber), TextCellValue(b.createdAt.toIso8601String().substring(0, 10)),
              TextCellValue(b.customerName ?? 'Walk-in'), DoubleCellValue(b.subtotal), DoubleCellValue(b.totalTax),
              DoubleCellValue(b.totalAmount), DoubleCellValue(b.paidAmount), DoubleCellValue(b.balanceDue),
              TextCellValue(b.status.name), TextCellValue(b.paymentMethod.name)]);
          }
          filename = 'Sales_${appState.bills.length}';
        case 'purchases':
          sheet.appendRow([TextCellValue('Purchase No'), TextCellValue('Date'), TextCellValue('Supplier'), TextCellValue('Subtotal'), TextCellValue('Tax'), TextCellValue('Total'), TextCellValue('Status')]);
          for (final p in appState.purchases) {
            sheet.appendRow([TextCellValue(p.purchaseNumber), TextCellValue(p.createdAt.toIso8601String().substring(0, 10)),
              TextCellValue(p.supplierName), DoubleCellValue(p.subtotal), DoubleCellValue(p.totalTax),
              DoubleCellValue(p.totalAmount), TextCellValue(p.status.name)]);
          }
          filename = 'Purchases_${appState.purchases.length}';
        case 'suppliers':
          sheet.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Email'), TextCellValue('Address'), TextCellValue('GSTIN'), TextCellValue('Total Purchases'), TextCellValue('Outstanding')]);
          for (final s in appState.suppliers) {
            sheet.appendRow([TextCellValue(s.name), TextCellValue(s.phone ?? ''), TextCellValue(s.email ?? ''),
              TextCellValue(s.address ?? ''), TextCellValue(s.gstin ?? ''), DoubleCellValue(s.totalPurchases), DoubleCellValue(s.outstandingBalance)]);
          }
          filename = 'Suppliers_${appState.suppliers.length}';
        case 'expenses':
          sheet.appendRow([TextCellValue('Date'), TextCellValue('Category'), TextCellValue('Title'), TextCellValue('Amount'), TextCellValue('Notes')]);
          for (final e in appState.expenses) {
            sheet.appendRow([TextCellValue(e.date.toIso8601String().substring(0, 10)),
              TextCellValue(e.category.label), TextCellValue(e.title), DoubleCellValue(e.amount), TextCellValue(e.notes ?? '')]);
          }
          filename = 'Expenses_${appState.expenses.length}';
        case 'quotations':
          sheet.appendRow([TextCellValue('Quotation No'), TextCellValue('Date'), TextCellValue('Customer'), TextCellValue('Total'), TextCellValue('Status'), TextCellValue('Valid Until')]);
          for (final q in appState.quotations) {
            sheet.appendRow([TextCellValue(q.quotationNumber), TextCellValue(q.createdAt.toIso8601String().substring(0, 10)),
              TextCellValue(q.customerName ?? ''), DoubleCellValue(q.totalAmount), TextCellValue(q.status.name),
              TextCellValue(q.validUntil?.toIso8601String().substring(0, 10) ?? '')]);
          }
          filename = 'Quotations_${appState.quotations.length}';
      }

      final bytes = Uint8List.fromList(excel.encode()!);
      await Printing.sharePdf(bytes: bytes, filename: 'MyBillu_${filename}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      setState(() => _busy = false);
      _msg('✅ $type Excel exported!');
    } catch (e) {
      setState(() => _busy = false);
      _msg('Export failed: $e', ok: false);
    }
  }

  Future<List<int>?> _readFileBytes(String? path) async {
    if (path == null) return null;
    // On mobile, re-pick with withData to get bytes
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      return result?.files.first.bytes?.toList();
    } catch (_) { return null; }
  }
}

