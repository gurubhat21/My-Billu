import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/models/bill.dart';
import '../../core/models/purchase.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class SerialTrackerScreen extends StatefulWidget {
  const SerialTrackerScreen({super.key});
  @override
  State<SerialTrackerScreen> createState() => _SerialTrackerScreenState();
}

class _SerialTrackerScreenState extends State<SerialTrackerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<_SerialResult> _results = [];
  bool _searched = false;

  void _search(AppState appState) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() { _results = []; _searched = false; _query = ''; });
      return;
    }
    setState(() { _query = q; _searched = true; });

    final results = <_SerialResult>[];

    // Search in bills (sales)
    for (final bill in appState.bills) {
      for (final item in bill.items) {
        if (item.serialNumber != null && item.serialNumber!.toLowerCase().contains(q)) {
          results.add(_SerialResult(
            serialNumber: item.serialNumber!,
            itemName: item.itemName,
            type: _ResultType.sale,
            date: bill.createdAt,
            billNumber: bill.billNumber,
            customerName: bill.customerName,
            customerPhone: bill.customerPhone,
            amount: item.total,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            description: item.description,
          ));
        }
      }
    }

    // Search in purchases
    for (final purchase in appState.purchases) {
      for (final item in purchase.items) {
        if (item.serialNumber != null && item.serialNumber!.toLowerCase().contains(q)) {
          results.add(_SerialResult(
            serialNumber: item.serialNumber!,
            itemName: item.itemName,
            type: _ResultType.purchase,
            date: purchase.createdAt,
            purchaseNumber: purchase.purchaseNumber,
            supplierName: purchase.supplierName,
            supplierPhone: purchase.supplierPhone,
            supplierGstin: purchase.supplierGstin,
            amount: item.total,
            quantity: item.quantity,
            unitPrice: item.unitCost,
            description: item.description,
          ));
        }
      }
    }

    // Sort by date (newest first)
    results.sort((a, b) => b.date.compareTo(a.date));
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(children: [
          Padding(
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Serial Number Tracker', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('Search serial numbers to find purchase & sale history',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _search(appState),
                  decoration: InputDecoration(
                    hintText: 'Enter serial number to search...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () { _searchCtrl.clear(); _search(appState); }),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20, color: AppColors.primary),
                          tooltip: 'Scan barcode/QR',
                          onPressed: () => _scanBarcode(context, appState)),
                    ]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                )),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _search(appState),
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ]),
            ]),
          ),
          // Results
          Expanded(child: _searched
            ? _results.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text('No results found for "$_query"',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black45)),
                  const SizedBox(height: 4),
                  Text('Try a different serial number',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black26)),
                ]))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) => _buildResultCard(context, _results[i], isDark))
            : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_scanner, size: 64, color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 16),
                Text('Search for a serial number',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white24 : Colors.black26)),
                const SizedBox(height: 6),
                Text('Find purchase details, supplier info, sale records & customer details',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white12 : Colors.black12)),
              ]))),
        ]);
      });
    });
  }

  Widget _buildResultCard(BuildContext context, _SerialResult r, bool isDark) {
    final isSale = r.type == _ResultType.sale;
    final color = isSale ? AppColors.success : AppColors.accent;
    final icon = isSale ? Icons.sell : Icons.shopping_bag;
    final label = isSale ? 'SOLD' : 'PURCHASED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
              const SizedBox(width: 8),
              Text(AppFormatters.dateTime(r.date),
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
            ]),
            const SizedBox(height: 4),
            Text(r.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ])),
          Text(AppFormatters.currency(r.amount),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Serial & Description
        _detailRow(Icons.qr_code, 'Serial Number', r.serialNumber, isDark),
        if (r.description != null)
          _detailRow(Icons.description, 'Description', r.description!, isDark),
        _detailRow(Icons.tag, 'Quantity', '${r.quantity} × ${AppFormatters.currency(r.unitPrice)}', isDark),

        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Sale details
        if (isSale) ...[
          _sectionTitle('Customer / Billing Details', Icons.person, isDark),
          const SizedBox(height: 6),
          _detailRow(Icons.receipt, 'Bill Number', r.billNumber ?? '-', isDark),
          _detailRow(Icons.person, 'Customer', r.customerName ?? 'Walk-in Customer', isDark),
          if (r.customerPhone != null && r.customerPhone!.isNotEmpty)
            _detailRow(Icons.phone, 'Phone', r.customerPhone!, isDark),
        ],

        // Purchase details
        if (!isSale) ...[
          _sectionTitle('Supplier Details', Icons.local_shipping, isDark),
          const SizedBox(height: 6),
          _detailRow(Icons.receipt, 'Purchase No.', r.purchaseNumber ?? '-', isDark),
          _detailRow(Icons.store, 'Supplier', r.supplierName ?? '-', isDark),
          if (r.supplierPhone != null && r.supplierPhone!.isNotEmpty)
            _detailRow(Icons.phone, 'Phone', r.supplierPhone!, isDark),
          if (r.supplierGstin != null && r.supplierGstin!.isNotEmpty)
            _detailRow(Icons.badge, 'GSTIN', r.supplierGstin!, isDark),
        ],
      ]),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool isDark) {
    return Row(children: [
      Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: isDark ? Colors.white54 : Colors.black54,
        letterSpacing: 0.5)),
    ]);
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 14, color: isDark ? Colors.white24 : Colors.black26),
        const SizedBox(width: 8),
        SizedBox(width: 110, child: Text(label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45))),
        Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  void _scanBarcode(BuildContext context, AppState appState) {
    if (kIsWeb) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => _ScannerPage(onScanned: (code) {
        Navigator.of(ctx).pop();
        _searchCtrl.text = code;
        _search(appState);
      }),
    ));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ===== Result Types =====
enum _ResultType { sale, purchase }

class _SerialResult {
  final String serialNumber;
  final String itemName;
  final _ResultType type;
  final DateTime date;
  final String? billNumber;
  final String? customerName;
  final String? customerPhone;
  final String? purchaseNumber;
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierGstin;
  final double amount;
  final int quantity;
  final double unitPrice;
  final String? description;

  _SerialResult({
    required this.serialNumber,
    required this.itemName,
    required this.type,
    required this.date,
    this.billNumber,
    this.customerName,
    this.customerPhone,
    this.purchaseNumber,
    this.supplierName,
    this.supplierPhone,
    this.supplierGstin,
    required this.amount,
    required this.quantity,
    required this.unitPrice,
    this.description,
  });
}

// ===== Barcode Scanner =====
class _ScannerPage extends StatefulWidget {
  final void Function(String code) onScanned;
  const _ScannerPage({required this.onScanned});
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Serial Number'),
        elevation: 0,
      ),
      body: Stack(children: [
        MobileScanner(
          onDetect: (capture) {
            if (_scanned) return;
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _scanned = true;
              widget.onScanned(barcodes.first.rawValue!);
            }
          },
        ),
        Center(child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 3),
            borderRadius: BorderRadius.circular(20)),
        )),
        Positioned(
          bottom: 80, left: 0, right: 0,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30)),
            child: const Text('Point camera at barcode or QR code',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          )),
        ),
      ]),
    );
  }
}
