import 'dart:convert';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../core/utils/input_formatters.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_generator.dart';
import '../../widgets/common_widgets.dart';

// Cart item for fake quotation – matches billing's cart item
class _FakeCartItem {
  final Item item;
  int quantity;
  double price;
  String description;
  List<String> serialNumbers;
  _FakeCartItem({required this.item, required this.quantity, double? price, this.description = '', List<String>? serialNumbers})
    : price = price ?? item.price,
      serialNumbers = serialNumbers ?? [''];
}

class _FakeQuoteRecord {
  final String id;
  final String billNumber;
  final String companyName;
  final String? customerName;
  final double totalAmount;
  final int itemCount;
  final DateTime createdAt;
  final Map<String, dynamic> billData; // full Bill.toMap() for reprinting

  _FakeQuoteRecord({
    required this.id,
    required this.billNumber,
    required this.companyName,
    this.customerName,
    required this.totalAmount,
    required this.itemCount,
    required this.createdAt,
    required this.billData,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'billNumber': billNumber, 'companyName': companyName,
    'customerName': customerName, 'totalAmount': totalAmount,
    'itemCount': itemCount, 'createdAt': createdAt.toIso8601String(),
    'billData': billData,
  };

  factory _FakeQuoteRecord.fromMap(Map<String, dynamic> m) => _FakeQuoteRecord(
    id: m['id'] as String,
    billNumber: m['billNumber'] as String,
    companyName: m['companyName'] as String? ?? '',
    customerName: m['customerName'] as String?,
    totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
    itemCount: (m['itemCount'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    billData: Map<String, dynamic>.from(m['billData'] as Map? ?? {}),
  );
}

class FakeQuoteScreen extends StatefulWidget {
  const FakeQuoteScreen({super.key});
  @override
  State<FakeQuoteScreen> createState() => _FakeQuoteScreenState();
}

class _FakeQuoteScreenState extends State<FakeQuoteScreen> {
  // Selected company profile (1 or 2)
  int _selectedProfile = 1;
  String _company1Name = '';
  String _company1Phone = '';
  String _company1Address = '';
  String _company1Gstin = '';
  String _company2Name = '';
  String _company2Phone = '';
  String _company2Address = '';
  String _company2Gstin = '';

  List<_FakeQuoteRecord> _history = [];
  DateTime _fakeQuoteDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _loadHistory();
  }

  Future<void> _loadProfiles() async {
    final appState = context.read<AppState>();
    final c1n = await appState.getSetting('fake_company_1_name') ?? '';
    final c1p = await appState.getSetting('fake_company_1_phone') ?? '';
    final c1a = await appState.getSetting('fake_company_1_address') ?? '';
    final c1g = await appState.getSetting('fake_company_1_gstin') ?? '';
    final c2n = await appState.getSetting('fake_company_2_name') ?? '';
    final c2p = await appState.getSetting('fake_company_2_phone') ?? '';
    final c2a = await appState.getSetting('fake_company_2_address') ?? '';
    final c2g = await appState.getSetting('fake_company_2_gstin') ?? '';
    if (mounted) setState(() {
      _company1Name = c1n; _company1Phone = c1p; _company1Address = c1a; _company1Gstin = c1g;
      _company2Name = c2n; _company2Phone = c2p; _company2Address = c2a; _company2Gstin = c2g;
    });
  }

  Future<void> _loadHistory() async {
    final appState = context.read<AppState>();
    final raw = await appState.getSetting('fake_quote_history');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        if (mounted) setState(() {
          _history = list.map((e) => _FakeQuoteRecord.fromMap(Map<String, dynamic>.from(e))).toList();
          _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      } catch (_) {}
    }
  }

  Future<void> _saveHistory() async {
    final appState = context.read<AppState>();
    await appState.saveSetting('fake_quote_history', jsonEncode(_history.map((e) => e.toMap()).toList()));
  }

  Future<void> _addToHistory(Bill bill, String companyName) async {
    final record = _FakeQuoteRecord(
      id: bill.id,
      billNumber: bill.billNumber,
      companyName: companyName,
      customerName: bill.customerName,
      totalAmount: bill.totalAmount,
      itemCount: bill.items.length,
      createdAt: bill.createdAt,
      billData: bill.toMap(),
    );
    setState(() => _history.insert(0, record));
    await _saveHistory();
  }

  Future<void> _deleteFromHistory(String id) async {
    setState(() => _history.removeWhere((r) => r.id == id));
    await _saveHistory();
  }

  String get _currentCompanyName => _selectedProfile == 1 ? _company1Name : _company2Name;
  String get _currentCompanyPhone => _selectedProfile == 1 ? _company1Phone : _company2Phone;
  String get _currentCompanyAddress => _selectedProfile == 1 ? _company1Address : _company2Address;
  String get _currentCompanyGstin => _selectedProfile == 1 ? _company1Gstin : _company2Gstin;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        // Filter history by selected company
        final filtered = _history.where((r) => r.companyName == _currentCompanyName).toList();
        return Column(children: [
          Padding(padding: EdgeInsets.all(isWide ? 24 : 16), child: Row(children: [
            Expanded(child: Text('Fake Quotation', style: Theme.of(context).textTheme.headlineLarge)),
            ElevatedButton.icon(
              onPressed: () => _showCreateFakeQuotation(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Fake Quotation'),
            ),
          ])),
          // Company profile selector
          Padding(padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16), child: _buildCompanySelector()),
          const SizedBox(height: 16),
          // History list or empty state
          Expanded(child: filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.description_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                Text(_currentCompanyName.isEmpty ? 'No company selected' : 'No quotes for $_currentCompanyName',
                  style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text('Select a company profile above, then tap "Create Fake Quotation".',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _showCreateFakeQuotation(context, appState),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create one now')),
              ]))
            : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 12, vertical: 4),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _buildHistoryTile(context, filtered[i], appState, isWide),
              ),
          ),
        ]);
      });
    });
  }

  Widget _buildHistoryTile(BuildContext context, _FakeQuoteRecord record, AppState appState, bool isWide) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.description, size: 18, color: Color(0xFFEF4444))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.billNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(record.companyName, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(AppFormatters.currency(record.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
              Text('${record.itemCount} items', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.person_outline, size: 14, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text(record.customerName ?? 'Walk-in', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            const Spacer(),
            Icon(Icons.access_time, size: 14, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text(AppFormatters.dateTime(record.createdAt), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            // Edit button
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => _editQuoteFromHistory(context, appState, record),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit', style: TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 6),
            // Preview / Print
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () {
                try {
                  final bill = Bill.fromMap(record.billData);
                  _showPrintShareDialog(context, appState, bill);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: \$e'), backgroundColor: AppColors.error));
                }
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Print', style: TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 6),
            // Share
            IconButton(
              onPressed: () async {
                try {
                  final bill = Bill.fromMap(record.billData);
                  final s = await appState.getAllSettings();
                  final template = _parseTemplate(s['pdf_template']);
                  final paperSize = (s['pdf_paper_size'] ?? 'a4') == 'a5' ? PaperSize.a5 : PaperSize.a4;
                  // Don't use real logo/seal for fake quotes
                  // final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
                  // final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);
                  await InvoiceGenerator.shareInvoice(bill,
                    businessName: record.companyName,
                    businessAddress: _currentCompanyAddress,
                    businessPhone: _currentCompanyPhone,
                    businessGstin: _currentCompanyGstin,
                    businessBankName: s['businessBankName'] ?? '',
                    businessBankAccount: s['businessBankAccount'] ?? '',
                    businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
                    logoBytes: null, sealBytes: null,
                    template: template, paperSize: paperSize,
                    documentTitle: 'QUOTATION',
                    thankYouMessage: s['pdf_thank_you_message'],
                    termsConditions: s['pdf_terms_conditions'],
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Share error: \$e'), backgroundColor: AppColors.error));
                  }
                }
              },
              icon: const Icon(Icons.share, size: 18, color: Color(0xFF25D366)),
              tooltip: 'Share',
            ),
            // Delete
            IconButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Delete?'),
                  content: Text('Delete ${record.billNumber}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete')),
                  ],
                ));
                if (confirm == true) _deleteFromHistory(record.id);
              },
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              tooltip: 'Delete',
            ),
          ]),
        ]),
      ),
    );
  }

  // ==================== EDIT QUOTE FROM HISTORY ====================
  void _editQuoteFromHistory(BuildContext context, AppState appState, _FakeQuoteRecord record) async {
    final showDesc = (await appState.getSetting('billing_show_description')) == 'true';
    final gstMode = (await appState.getSetting('billing_gst_inclusive')) == 'true';
    if (!context.mounted) return;

    // Rebuild cart from bill data
    Bill existingBill;
    try {
      existingBill = Bill.fromMap(record.billData);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot load this quote for editing'), backgroundColor: AppColors.error));
      return;
    }

    final cart = <_FakeCartItem>[];
    for (final bi in existingBill.items) {
      final item = appState.items.where((it) => it.id == bi.itemId).firstOrNull;
      // When GST inclusive, convert stored base price to inclusive for display
      final displayPrice = gstMode
          ? bi.unitPrice * (1 + bi.taxRate / 100)
          : bi.unitPrice;
      cart.add(_FakeCartItem(
        item: item ?? Item(id: bi.itemId, name: bi.itemName, price: bi.unitPrice, taxRate: bi.taxRate, unit: bi.unit),
        quantity: bi.quantity,
        price: displayPrice,
        description: bi.description ?? '',
      ));
    }

    final customerCtrl = TextEditingController(text: existingBill.customerName ?? '');
    final phoneCtrl = TextEditingController(text: existingBill.customerPhone ?? '');
    final notesCtrl = TextEditingController(text: existingBill.notes ?? '');
    final discountCtrl = TextEditingController(text: existingBill.discount.toString());
    String? selectedCustomerId = existingBill.customerId;
    bool gstInclusive = gstMode;
    Customer? selectedCustomer;
    if (selectedCustomerId != null) {
      selectedCustomer = appState.customers.where((c) => c.id == selectedCustomerId).firstOrNull;
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      double subtotal = 0, totalTax = 0;
      for (final c in cart) {
        if (gstInclusive) {
          subtotal += c.price * c.quantity / (1 + c.item.taxRate / 100);
          final inclTotal = c.price * c.quantity;
          totalTax += inclTotal - inclTotal / (1 + c.item.taxRate / 100);
        } else {
          subtotal += c.price * c.quantity;
          totalTax += c.price * c.quantity * c.item.taxRate / 100;
        }
      }
      final discount = double.tryParse(discountCtrl.text) ?? 0;
      final totalAmount = subtotal + totalTax - discount;

      final displayName = selectedCustomer?.name
          ?? (customerCtrl.text.trim().isNotEmpty ? customerCtrl.text.trim() : 'Walk-in Customer');
      final displayPhone = selectedCustomer?.phone ?? (phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null);

      return AlertDialog(
        title: Text('Edit ${record.billNumber}'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Customer picker
            InkWell(
              onTap: () => _showCustomerPicker(ctx, appState, customerCtrl, phoneCtrl, (cust) {
                setDialogState(() {
                  selectedCustomer = cust;
                  selectedCustomerId = cust?.id;
                  if (cust != null) {
                    customerCtrl.text = cust.name;
                    phoneCtrl.text = cust.phone ?? '';
                  }
                });
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(selectedCustomer != null ? Icons.person : Icons.person_add, size: 18, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    if (displayPhone != null)
                      Text(displayPhone, style: TextStyle(fontSize: 11, color: Theme.of(ctx).textTheme.bodySmall?.color)),
                  ])),
                  const Icon(Icons.chevron_right, size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            // Add items
            Row(children: [
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddItem(ctx, appState, cart, setDialogState),
                icon: const Icon(Icons.add, size: 16), label: const Text('Add Item')),
            ]),
            if (cart.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8)),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_cart_outlined, size: 32, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 8),
                  const Text('No items added', style: TextStyle(fontSize: 12)),
                ])))
            else
              ...cart.asMap().entries.map((e) => _buildCartItem(ctx, e.key, cart, setDialogState, showDesc)),
            const Divider(),
            TextField(controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount \u20B9', prefixIcon: Icon(Icons.local_offer)),
              onChanged: (_) => setDialogState(() {})),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note)),
              maxLines: 2),
            const SizedBox(height: 12),
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient.scale(0.3),
                borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.receipt_long, size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(gstInclusive ? 'GST Inclusive' : 'GST Exclusive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: gstInclusive ? Colors.greenAccent : Colors.cyanAccent)),
                  const Spacer(),
                  SizedBox(height: 24, child: Switch(
                    value: gstInclusive,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) async {
                      // Convert prices between inclusive/exclusive
                      for (final c in cart) {
                        if (v) {
                          c.price = c.price * (1 + c.item.taxRate / 100);
                        } else {
                          c.price = c.price / (1 + c.item.taxRate / 100);
                        }
                      }
                      setDialogState(() => gstInclusive = v);
                      await appState.saveSetting('billing_gst_inclusive', v.toString());
                    },
                  )),
                ]),
                const SizedBox(height: 4),
                _summaryRow('Subtotal', AppFormatters.currency(subtotal)),
                _summaryRow('GST', AppFormatters.currency(totalTax)),
                if (discount > 0) _summaryRow('Discount', '- ${AppFormatters.currency(discount)}'),
                const Divider(color: Colors.white24),
                _summaryRow('Total', AppFormatters.currency(totalAmount), bold: true),
              ])),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: cart.isEmpty ? null : () async {
              Navigator.pop(ctx);
              final billItems = cart.map((c) {
                final serials = c.serialNumbers.where((s) => s.isNotEmpty).toList();
                final basePrice = gstInclusive
                    ? c.price / (1 + c.item.taxRate / 100)
                    : c.price;
                return BillItem(
                  itemId: c.item.id, itemName: c.item.name,
                  unitPrice: basePrice, quantity: c.quantity, taxRate: c.item.taxRate, unit: c.item.unit,
                  description: c.description.isNotEmpty ? c.description : null,
                  serialNumber: serials.isNotEmpty ? serials.join(', ') : null,
                );
              }).toList();

              final bill = Bill(
                id: record.id,
                billNumber: record.billNumber,
                customerId: selectedCustomerId,
                customerName: customerCtrl.text.isEmpty ? null : customerCtrl.text,
                customerPhone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                items: billItems,
                subtotal: subtotal,
                discount: discount,
                totalTax: totalTax,
                totalAmount: totalAmount,
                paidAmount: 0,
                paymentMethod: PaymentMethod.cash,
                status: BillStatus.unpaid,
                notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                createdAt: record.createdAt,
              );

              // Update history record
              await _deleteFromHistory(record.id);
              await _addToHistory(bill, _currentCompanyName);
              if (context.mounted) {
                _showPrintShareDialog(context, appState, bill);
              }
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Update & Print')),
        ],
      );
    }));
  }

  // ==================== COMPANY PROFILE SELECTOR ====================
  Widget _buildCompanySelector() {
    return GlassCard(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.business, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Text('Company Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _profileCard(1, _company1Name, _company1Phone, _company1Gstin)),
          const SizedBox(width: 10),
          Expanded(child: _profileCard(2, _company2Name, _company2Phone, _company2Gstin)),
        ]),
        if (_currentCompanyName.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Using: $_currentCompanyName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.success)),
                if (_currentCompanyPhone.isNotEmpty)
                  Text('Phone: $_currentCompanyPhone', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
                if (_currentCompanyGstin.isNotEmpty)
                  Text('GSTIN: $_currentCompanyGstin', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
              ])),
            ])),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
            child: const Text('\u26A0 Configure company profiles in Settings \u2192 Fake Quote',
              style: TextStyle(fontSize: 11, color: AppColors.warning))),
        ],
      ]));
  }

  Widget _profileCard(int num, String name, String phone, String gstin) {
    final isSelected = _selectedProfile == num;
    final hasData = name.isNotEmpty;
    return InkWell(
      onTap: () => setState(() => _selectedProfile = num),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEF4444).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFFEF4444) : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text('Company $num', style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13,
              color: isSelected ? const Color(0xFFEF4444) : Colors.grey)),
          ]),
          const SizedBox(height: 6),
          if (hasData) ...[
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
            if (gstin.isNotEmpty) Text(gstin, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
          ] else
            Text('Not configured', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
        ]),
      ),
    );
  }

  // ==================== CREATE FAKE QUOTATION DIALOG ====================
  void _showCreateFakeQuotation(BuildContext context, AppState appState) async {
    // Load settings
    final showDesc = (await appState.getSetting('billing_show_description')) == 'true';
    final gstMode = (await appState.getSetting('billing_gst_inclusive')) == 'true';

    if (!context.mounted) return;

    final cart = <_FakeCartItem>[];
    final customerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    String? selectedCustomerId;
    bool gstInclusive = gstMode;
    Customer? selectedCustomer;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      double subtotal = 0, totalTax = 0;
      for (final c in cart) {
        if (gstInclusive) {
          subtotal += c.price * c.quantity / (1 + c.item.taxRate / 100);
          final inclTotal = c.price * c.quantity;
          totalTax += inclTotal - inclTotal / (1 + c.item.taxRate / 100);
        } else {
          subtotal += c.price * c.quantity;
          totalTax += c.price * c.quantity * c.item.taxRate / 100;
        }
      }
      final discount = double.tryParse(discountCtrl.text) ?? 0;
      final totalAmount = subtotal + totalTax - discount;

      final displayName = selectedCustomer?.name
          ?? (customerCtrl.text.trim().isNotEmpty ? customerCtrl.text.trim() : 'Walk-in Customer');
      final displayPhone = selectedCustomer?.phone ?? (phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null);

      return AlertDialog(
        title: const Text('New Fake Quotation'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _fakeQuoteDate,
                  firstDate: DateTime(2020), lastDate: DateTime(2030),
                );
                if (picked != null) setDialogState(() => _fakeQuoteDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Date: ${DateFormat('dd MMM yyyy').format(_fakeQuoteDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            // --- Customer picker ---
            InkWell(
              onTap: () => _showCustomerPicker(ctx, appState, customerCtrl, phoneCtrl, (cust) {
                setDialogState(() {
                  selectedCustomer = cust;
                  selectedCustomerId = cust?.id;
                  if (cust != null) {
                    customerCtrl.text = cust.name;
                    phoneCtrl.text = cust.phone ?? '';
                  }
                });
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(selectedCustomer != null ? Icons.person : Icons.person_add, size: 18, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    if (displayPhone != null)
                      Text(displayPhone, style: TextStyle(fontSize: 11, color: Theme.of(ctx).textTheme.bodySmall?.color)),
                  ])),
                  const Icon(Icons.chevron_right, size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            // --- Add items ---
            Row(children: [
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddItem(ctx, appState, cart, setDialogState),
                icon: const Icon(Icons.add, size: 16), label: const Text('Add Item')),
            ]),
            // --- Cart items ---
            if (cart.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8)),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_cart_outlined, size: 32, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 8),
                  const Text('No items added', style: TextStyle(fontSize: 12)),
                ])))
            else
              ...cart.asMap().entries.map((e) => _buildCartItem(ctx, e.key, cart, setDialogState, showDesc)),
            const Divider(),
            TextField(controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount \u20B9', prefixIcon: Icon(Icons.local_offer)),
              onChanged: (_) => setDialogState(() {})),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note)),
              maxLines: 2),
            const SizedBox(height: 12),
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient.scale(0.3),
                borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.receipt_long, size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(gstInclusive ? 'GST Inclusive' : 'GST Exclusive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: gstInclusive ? Colors.greenAccent : Colors.cyanAccent)),
                  const Spacer(),
                  SizedBox(height: 24, child: Switch(
                    value: gstInclusive,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) async {
                      // Convert prices between inclusive/exclusive
                      for (final c in cart) {
                        if (v) {
                          c.price = c.price * (1 + c.item.taxRate / 100);
                        } else {
                          c.price = c.price / (1 + c.item.taxRate / 100);
                        }
                      }
                      setDialogState(() => gstInclusive = v);
                      await appState.saveSetting('billing_gst_inclusive', v.toString());
                    },
                  )),
                ]),
                const SizedBox(height: 4),
                _summaryRow('Subtotal', AppFormatters.currency(subtotal)),
                _summaryRow('GST', AppFormatters.currency(totalTax)),
                if (discount > 0) _summaryRow('Discount', '- ${AppFormatters.currency(discount)}'),
                const Divider(color: Colors.white24),
                _summaryRow('Total', AppFormatters.currency(totalAmount), bold: true),
              ])),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: cart.isEmpty ? null : () async {
              Navigator.pop(ctx);
              // Build the bill from cart
              final billItems = cart.map((c) {
                final serials = c.serialNumbers.where((s) => s.isNotEmpty).toList();
                final basePrice = gstInclusive
                    ? c.price / (1 + c.item.taxRate / 100)
                    : c.price;
                return BillItem(
                  itemId: c.item.id, itemName: c.item.name,
                  unitPrice: basePrice, quantity: c.quantity, taxRate: c.item.taxRate, unit: c.item.unit,
                  description: c.description.isNotEmpty ? c.description : null,
                  serialNumber: serials.isNotEmpty ? serials.join(', ') : null,
                );
              }).toList();

              final bill = Bill(
                billNumber: 'FQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                customerId: selectedCustomerId,
                customerName: customerCtrl.text.isEmpty ? null : customerCtrl.text,
                customerPhone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                items: billItems,
                subtotal: subtotal,
                discount: discount,
                totalTax: totalTax,
                totalAmount: totalAmount,
                paidAmount: 0,
                paymentMethod: PaymentMethod.cash,
                status: BillStatus.unpaid,
                notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                createdAt: _fakeQuoteDate,
              );

              // Save to history and show print/share/save dialog
              await _addToHistory(bill, _currentCompanyName);
              setState(() => _fakeQuoteDate = DateTime.now());
              if (context.mounted) {
                _showPrintShareDialog(context, appState, bill);
              }
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print / Share')),
        ],
      );
    }));
  }

  // ==================== CART ITEM WIDGET (same as billing) ====================
  Widget _buildCartItem(BuildContext context, int index, List<_FakeCartItem> cart, StateSetter setDialogState, bool showDesc) {
    final c = cart[index];
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              // Tappable price
              GestureDetector(
                onTap: () {
                  final ctrl = TextEditingController(text: c.price.toStringAsFixed(2));
                  showDialog(context: context, builder: (ctx2) => AlertDialog(
                    title: const Text('Edit Price', style: TextStyle(fontSize: 16)),
                    content: TextField(
                      controller: ctrl, autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixText: '\u20B9 ', labelText: 'Unit Price'),
                      onSubmitted: (_) {
                        final p = double.tryParse(ctrl.text);
                        if (p != null && p >= 0) setDialogState(() => c.price = p);
                        Navigator.pop(ctx2);
                      },
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () {
                        final p = double.tryParse(ctrl.text);
                        if (p != null && p >= 0) setDialogState(() => c.price = p);
                        Navigator.pop(ctx2);
                      }, child: const Text('Save')),
                    ],
                  ));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${AppFormatters.currency(c.price)} \u00d7 ${c.quantity}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 11, color: Colors.white.withValues(alpha: 0.25)),
                ]),
              ),
            ])),
            // Quantity +/- buttons
            Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  onPressed: () {
                    setDialogState(() {
                      if (cart[index].quantity > 1) {
                        cart[index].quantity--;
                      } else {
                        cart.removeAt(index);
                      }
                    });
                  },
                  icon: const Icon(Icons.remove, size: 18, color: AppColors.primary),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                // Tappable quantity
                GestureDetector(
                  onTap: () {
                    final ctrl = TextEditingController(text: c.quantity.toString());
                    showDialog(context: context, builder: (ctx2) => AlertDialog(
                      title: const Text('Edit Quantity', style: TextStyle(fontSize: 16)),
                      content: TextField(
                        controller: ctrl, autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        onSubmitted: (_) {
                          final q = int.tryParse(ctrl.text);
                          if (q != null && q > 0) setDialogState(() => cart[index].quantity = q);
                          Navigator.pop(ctx2);
                        },
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () {
                          final q = int.tryParse(ctrl.text);
                          if (q != null && q > 0) setDialogState(() => cart[index].quantity = q);
                          Navigator.pop(ctx2);
                        }, child: const Text('Save')),
                      ],
                    ));
                  },
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${c.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted))),
                ),
                IconButton(
                  onPressed: () => setDialogState(() => cart[index].quantity++),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ])),
            const SizedBox(width: 8),
            SizedBox(width: 65, child: Text(AppFormatters.currency(c.price * c.quantity),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.right)),
          ]),
          // Description field
          if (showDesc)
            Padding(padding: const EdgeInsets.only(top: 6),
              child: TextFormField(
                key: ValueKey('fqdesc_${c.item.id}_$index'),
                initialValue: c.description,
                onChanged: (v) => c.description = v,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Item description...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.description, size: 16)),
              )),
        ])));
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: Colors.white)),
      ]));
  }

  // ==================== CUSTOMER PICKER (same as billing) ====================
  void _showCustomerPicker(BuildContext context, AppState appState,
      TextEditingController nameCtrl, TextEditingController phoneCtrl,
      Function(Customer?) onSelected) {
    showDialog(context: context, builder: (ctx) {
      String search = '';
      return StatefulBuilder(builder: (context, ss) {
        final filtered = search.isEmpty ? appState.customers
            : appState.customers.where((c) =>
                c.name.toLowerCase().contains(search.toLowerCase()) ||
                (c.phone ?? '').contains(search)).toList();
        return AlertDialog(title: const Text('Select Customer'),
          content: SizedBox(width: 400, height: 500, child: Column(children: [
            TextField(onChanged: (v) => ss(() => search = v),
              decoration: const InputDecoration(hintText: 'Search by name or phone...', prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 12),
            // Walk-in with name & phone
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Walk-in Customer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  TextButton(onPressed: () {
                    onSelected(null);
                    Navigator.pop(ctx);
                  }, child: const Text('Use Walk-in', style: TextStyle(fontSize: 12))),
                ]),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (optional)',
                    prefixIcon: Icon(Icons.person, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number (optional)',
                    prefixIcon: Icon(Icons.phone, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () {
                    onSelected(null);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Set Walk-in Details', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact))),
              ])),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Existing Customers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            const SizedBox(height: 8),
            Expanded(child: ListView(children: [
              ...filtered.map((c) => ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(c.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary))),
                title: Text(c.name), subtitle: c.phone != null ? Text(c.phone!) : null,
                onTap: () {
                  nameCtrl.text = c.name;
                  phoneCtrl.text = c.phone ?? '';
                  onSelected(c);
                  Navigator.pop(ctx);
                })),
            ])),
          ])));
      });
    });
  }

  // ==================== ADD ITEM (same as billing) ====================
  void _showAddItem(BuildContext context, AppState appState, List<_FakeCartItem> cart, StateSetter setDialogState) {
    Item? pickedItem;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocalState) => AlertDialog(
      title: const Text('Add Item'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Autocomplete<Item>(
          optionsBuilder: (textValue) {
            if (textValue.text.isEmpty) return appState.items;
            final q = textValue.text.toLowerCase();
            return appState.items.where((i) =>
              i.name.toLowerCase().contains(q) ||
              (i.hsnCode ?? '').toLowerCase().contains(q) ||
              (i.barcode ?? '').toLowerCase().contains(q) ||
              (i.category ?? '').toLowerCase().contains(q));
          },
          displayStringForOption: (item) => item.name,
          fieldViewBuilder: (ctx2, ctrl, focusNode, onSubmit) {
            return TextField(
              controller: ctrl, focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Search Item',
                prefixIcon: Icon(Icons.search),
                hintText: 'Name, HSN, barcode...'),
            );
          },
          onSelected: (item) {
            FocusScope.of(ctx).unfocus();
            setLocalState(() {
              pickedItem = item;
              priceCtrl.text = item.price.toStringAsFixed(2);
            });
          },
          optionsViewBuilder: (ctx2, onSelected, options) {
            return Align(alignment: Alignment.topLeft, child: Material(
              elevation: 8, borderRadius: BorderRadius.circular(12),
              color: Theme.of(ctx2).brightness == Brightness.dark
                  ? const Color(0xFF1E1E2E) : Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true, itemCount: options.length,
                  itemBuilder: (ctx2, i) {
                    final item = options.elementAt(i);
                    return ListTile(dense: true,
                      leading: CircleAvatar(radius: 16,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        child: Text(item.name[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.accent))),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('\u20b9${item.price.toStringAsFixed(2)} \u00b7 ${item.unit}',
                        style: const TextStyle(fontSize: 11)),
                      onTap: () => onSelected(item),
                    );
                  }),
              ),
            ));
          },
        ),
        if (pickedItem != null)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text('Selected: ${pickedItem!.name}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Price (\u20b9)', prefixIcon: Icon(Icons.currency_rupee, size: 18))),
        const SizedBox(height: 12),
        TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (pickedItem == null) return;
          final item = pickedItem!;
          final qty = int.tryParse(qtyCtrl.text) ?? 1;
          final price = double.tryParse(priceCtrl.text) ?? item.price;
          setDialogState(() {
            cart.add(_FakeCartItem(item: item, quantity: qty, price: price));
          });
          Navigator.pop(ctx);
        }, child: const Text('Add')),
      ],
    )));
  }

  // ==================== PRINT / SHARE / SAVE DIALOG ====================
  void _showPrintShareDialog(BuildContext context, AppState appState, Bill bill) async {
    final settings = await appState.getAllSettings();
    String selectedSize = settings['pdf_paper_size'] ?? 'a4';
    String selectedTemplate = settings['pdf_template'] ?? 'modern';

    if (!context.mounted) return;
    final action = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.print, color: AppColors.primary), const SizedBox(width: 10),
          const Text('Fake Quotation'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Quotation for ${bill.customerName ?? 'customer'}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.business, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Expanded(child: Text('Company: $_currentCompanyName',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)))),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.description, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Paper: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              _paperChip('A4', 'a4', selectedSize, (v) async {
                setDialogState(() => selectedSize = v);
                await appState.saveSetting('pdf_paper_size', v);
              }),
              const SizedBox(width: 6),
              _paperChip('A5', 'a5', selectedSize, (v) async {
                setDialogState(() => selectedSize = v);
                await appState.saveSetting('pdf_paper_size', v);
              }),
            ]),
          ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.style, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Template: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    ...[('Modern', 'modern'), ('Classic', 'classic'), ('Minimal', 'minimal'), ('GST', 'gstInvoice'), ('Simple', 'simple')].map((t) => InkWell(
                      onTap: () async {
                        setDialogState(() => selectedTemplate = t.$2);
                        await appState.saveSetting('pdf_template', t.$2);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedTemplate == t.$2 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: selectedTemplate == t.$2 ? AppColors.primary : Colors.grey.withValues(alpha: 0.4)),
                        ),
                        child: Text(t.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: selectedTemplate == t.$2 ? Colors.white : Colors.grey)),
                      ),
                    )),
                  ]),
                ]),
              ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'preview'),
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Preview'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'save'),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save PDF'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF25D366)),
            onPressed: () => Navigator.pop(ctx, 'share'),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'print'),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
          ),
        ],
      ),
    ));

    if (action == null || !context.mounted) return;

    final s = await appState.getAllSettings();
    final template = _parseTemplate(selectedTemplate);
    final paperSize = selectedSize == 'a5' ? PaperSize.a5 : PaperSize.a4;
    // Don't use real logo/seal for fake quotes
    // final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
    // final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);

    // Use FAKE company details instead of real ones
    final businessName = _currentCompanyName.isNotEmpty ? _currentCompanyName : 'Company';
    final businessPhone = _currentCompanyPhone;
    final businessGstin = _currentCompanyGstin;
    // Use address from settings if available, but override name/phone/gstin
    final businessAddress = _currentCompanyAddress;

    if (action == 'preview') {
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FakeQuotePreviewPage(
          bill: bill,
          businessName: businessName,
          businessAddress: businessAddress,
          businessPhone: businessPhone,
          businessGstin: businessGstin,
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
          businessUpiId: s['businessUpiId'] ?? '',
          template: template, paperSize: paperSize,
          documentTitle: 'QUOTATION',
          thankYouMessage: s['pdf_thank_you_message'],
          termsConditions: s['pdf_terms_conditions'],
        ),
      ));
    } else if (action == 'print') {
      await InvoiceGenerator.generateAndPrint(bill,
        businessName: businessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessGstin: businessGstin,
        businessBankName: s['businessBankName'] ?? '',
        businessBankAccount: s['businessBankAccount'] ?? '',
        businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
        logoBytes: null, sealBytes: null,
        template: template, paperSize: paperSize,
        documentTitle: 'QUOTATION',
        thankYouMessage: s['pdf_thank_you_message'],
        termsConditions: s['pdf_terms_conditions'],
      );
    } else if (action == 'share') {
      try {
        await InvoiceGenerator.shareInvoice(bill,
          businessName: businessName,
          businessAddress: businessAddress,
          businessPhone: businessPhone,
          businessGstin: businessGstin,
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
          logoBytes: null, sealBytes: null,
          template: template, paperSize: paperSize,
          documentTitle: 'QUOTATION',
          thankYouMessage: s['pdf_thank_you_message'],
          termsConditions: s['pdf_terms_conditions'],
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Share error: $e'), backgroundColor: AppColors.error));
        }
      }
    } else if (action == 'save') {
      try {
        final savedPath = await InvoiceGenerator.savePdfToFile(bill,
          businessName: businessName,
          businessAddress: businessAddress,
          businessPhone: businessPhone,
          businessGstin: businessGstin,
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
          logoBytes: null, sealBytes: null,
          template: template, paperSize: paperSize,
          documentTitle: 'QUOTATION',
          thankYouMessage: s['pdf_thank_you_message'],
          termsConditions: s['pdf_terms_conditions'],
          savePath: s['pdf_save_path'],
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8),
              Expanded(child: Text('PDF saved: $savedPath', overflow: TextOverflow.ellipsis)),
            ]),
            backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Save error: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

  // ==================== HELPERS ====================
  Widget _paperChip(String label, String value, String current, Function(String) onTap) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppColors.primary)),
      ),
    );
  }

  InvoiceTemplate _parseTemplate(String? value) {
    switch (value) {
      case 'classic': return InvoiceTemplate.classic;
      case 'minimal': return InvoiceTemplate.minimal;
      case 'gstInvoice': return InvoiceTemplate.gstInvoice;
      case 'simple': return InvoiceTemplate.simple;
      default: return InvoiceTemplate.modern;
    }
  }
}

// ========== FAKE QUOTE PREVIEW PAGE ==========

class _FakeQuotePreviewPage extends StatefulWidget {
  final Bill bill;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String businessGstin;
  final String businessBankName;
  final String businessBankAccount;
  final String businessBankIfsc;
  final String businessUpiId;
  final InvoiceTemplate template;
  final PaperSize paperSize;
  final String? documentTitle;
  final String? thankYouMessage;
  final String? termsConditions;

  const _FakeQuotePreviewPage({
    required this.bill,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.businessGstin,
    required this.businessBankName,
    required this.businessBankAccount,
    required this.businessBankIfsc,
    this.businessUpiId = '',
    required this.template,
    required this.paperSize,
    this.documentTitle,
    this.thankYouMessage,
    this.termsConditions,
  });

  @override
  State<_FakeQuotePreviewPage> createState() => _FakeQuotePreviewPageState();
}

class _FakeQuotePreviewPageState extends State<_FakeQuotePreviewPage> {
  Uint8List? _pdfBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    final bytes = await InvoiceGenerator.generatePdfBytes(
      widget.bill,
      businessName: widget.businessName,
      businessAddress: widget.businessAddress,
      businessPhone: widget.businessPhone,
      businessGstin: widget.businessGstin,
      businessBankName: widget.businessBankName,
      businessBankAccount: widget.businessBankAccount,
      businessBankIfsc: widget.businessBankIfsc,
      businessUpiId: widget.businessUpiId,
      logoBytes: null, sealBytes: null,
      template: widget.template,
      paperSize: widget.paperSize,
      documentTitle: widget.documentTitle,
      thankYouMessage: widget.thankYouMessage,
      termsConditions: widget.termsConditions,
    );
    if (mounted) setState(() { _pdfBytes = bytes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentTitle ?? 'Quotation Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _pdfBytes == null ? null : () async {
              try {
                await InvoiceGenerator.shareInvoice(
                  widget.bill,
                  businessName: widget.businessName,
                  businessAddress: widget.businessAddress,
                  businessPhone: widget.businessPhone,
                  businessGstin: widget.businessGstin,
                  businessBankName: widget.businessBankName,
                  businessBankAccount: widget.businessBankAccount,
                  businessBankIfsc: widget.businessBankIfsc,
                  businessUpiId: widget.businessUpiId,
                  logoBytes: null, sealBytes: null,
                  template: widget.template,
                  paperSize: widget.paperSize,
                  documentTitle: widget.documentTitle,
                  thankYouMessage: widget.thankYouMessage,
                  termsConditions: widget.termsConditions,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _pdfBytes == null ? null : () async {
                await Printing.layoutPdf(onLayout: (_) async => _pdfBytes!);
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating preview...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ]))
          : _pdfBytes != null
              ? PdfPreview(
                  build: (_) async => _pdfBytes!,
                  allowSharing: true,
                  allowPrinting: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  pdfFileName: '${widget.documentTitle ?? "Quotation"}_${widget.bill.billNumber}.pdf',
                )
              : const Center(child: Text('Error generating preview')),
    );
  }
}