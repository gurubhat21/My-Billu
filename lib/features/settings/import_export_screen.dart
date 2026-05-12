import 'dart:convert';
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
      // JSON Full Backup
      _sectionCard(ctx, isDark, Icons.backup, 'Full Backup (JSON)', 'Export all data including settings as JSON',
        [Color(0xFF7C3AED), Color(0xFF6D28D9)], [
        _actionBtn('Export Full Backup', Icons.download, const Color(0xFF7C3AED), () => _exportJson(ctx)),
      ]),
      const SizedBox(height: 16),

      // Excel Export
      _sectionCard(ctx, isDark, Icons.table_chart, 'Export to Excel (.xlsx)', 'Export data as Excel spreadsheet',
        [AppColors.primary, Color(0xFF3730A3)], [
        _actionBtn('Export All Data (Excel)', Icons.grid_on, AppColors.primary, () => _exportExcel(ctx)),
      ]),
      const SizedBox(height: 16),

      // Individual CSV Export
      _sectionCard(ctx, isDark, Icons.description, 'Export Individual CSV', 'Export each data type separately',
        [Color(0xFF059669), Color(0xFF047857)], [
        _actionBtn('Export Items', Icons.inventory_2, const Color(0xFF059669), () => _exportCsv(ctx, 'items')),
        const SizedBox(height: 8),
        _actionBtn('Export Customers', Icons.people, const Color(0xFF059669), () => _exportCsv(ctx, 'customers')),
        const SizedBox(height: 8),
        _actionBtn('Export Bills', Icons.receipt_long, const Color(0xFF059669), () => _exportCsv(ctx, 'bills')),
        const SizedBox(height: 8),
        _actionBtn('Export Suppliers', Icons.local_shipping, const Color(0xFF059669), () => _exportCsv(ctx, 'suppliers')),
        const SizedBox(height: 8),
        _actionBtn('Export Expenses', Icons.money_off, const Color(0xFF059669), () => _exportCsv(ctx, 'expenses')),
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

  Future<void> _exportCsv(BuildContext ctx, String type) async {
    setState(() => _busy = true);
    try {
      final appState = ctx.read<AppState>();
      String csv = '';
      String filename = '';
      switch (type) {
        case 'items':
          csv = 'Name,Price,Tax%,HSN,Unit,Stock,Category\n';
          for (final i in appState.items) { csv += '${i.name},${i.price},${i.taxRate},${i.hsnCode},${i.unit},${i.stockQuantity},${i.category}\n'; }
          filename = 'items';
        case 'customers':
          csv = 'Name,Phone,Email,Address,GSTIN,TotalPurchases,Outstanding\n';
          for (final c in appState.customers) { csv += '${c.name},${c.phone},${c.email},${c.address},${c.gstin},${c.totalPurchases},${c.outstandingBalance}\n'; }
          filename = 'customers';
        case 'bills':
          csv = 'BillNo,Date,Customer,Subtotal,Tax,Total,Paid,Balance,Status\n';
          for (final b in appState.bills) { csv += '${b.billNumber},${b.createdAt.toIso8601String()},${b.customerName ?? "Walk-in"},${b.subtotal},${b.totalTax},${b.totalAmount},${b.paidAmount},${b.balanceDue},${b.status.name}\n'; }
          filename = 'bills';
        case 'suppliers':
          csv = 'Name,Phone,Email,Address,GSTIN\n';
          for (final s in appState.suppliers) { csv += '${s.name},${s.phone},${s.email},${s.address},${s.gstin}\n'; }
          filename = 'suppliers';
        case 'expenses':
          csv = 'Date,Category,Amount,Notes\n';
          for (final e in appState.expenses) { csv += '${e.date.toIso8601String()},${e.category.name},${e.amount},${e.notes ?? ""}\n'; }
          filename = 'expenses';
      }
      web_helper.downloadJson(csv, 'mybillu_${filename}_${DateTime.now().millisecondsSinceEpoch}.csv');
      setState(() => _busy = false);
      _msg('✅ $type CSV exported!');
    } catch (e) {
      setState(() => _busy = false);
      _msg('CSV export failed: $e', ok: false);
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

