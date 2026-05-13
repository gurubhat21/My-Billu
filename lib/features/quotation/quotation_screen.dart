import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/models/bill.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/models/quotation.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_generator.dart';
import '../../widgets/common_widgets.dart';

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});
  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      var quotations = appState.quotations;
      if (_filter != 'All') {
        quotations = quotations.where((q) => q.status.name == _filter.toLowerCase()).toList();
      }

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Column(children: [
          Padding(padding: EdgeInsets.all(isWide ? 24 : 16), child: Row(children: [
            Expanded(child: Text('Quotations / Estimates', style: Theme.of(context).textTheme.headlineLarge)),
            ElevatedButton.icon(
              onPressed: () => _showCreateQuotation(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Quotation'),
            ),
          ])),
          // Filters
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['All', 'Draft', 'Sent', 'Accepted', 'Rejected', 'Converted'].map((f) =>
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                label: Text(f, style: const TextStyle(fontSize: 12)),
                selected: _filter == f,
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _filter = f),
              ))).toList()),
          )),
          const SizedBox(height: 12),
          // List
          Expanded(child: quotations.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.description_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                const Text('No quotations yet'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showCreateQuotation(context, appState),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create your first estimate')),
              ]))
            : ListView.builder(
                padding: EdgeInsets.all(isWide ? 24 : 12),
                itemCount: quotations.length,
                itemBuilder: (ctx, i) => _buildQuotationTile(context, quotations[i], appState, isWide),
              ),
          ),
        ]);
      });
    });
  }

  Widget _buildQuotationTile(BuildContext context, Quotation q, AppState appState, bool isWide) {
    final statusColor = _statusColor(q.status);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.description, size: 18, color: AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.quotationNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(q.customerName ?? 'No customer', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(q.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700))),
        ]),
        const Divider(height: 20),
        Row(children: [
          _infoChip(Icons.calendar_today, AppFormatters.date(q.createdAt)),
          const SizedBox(width: 12),
          _infoChip(Icons.shopping_cart, '${q.items.length} items'),
          const Spacer(),
          Text(AppFormatters.currency(q.totalAmount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ]),
        const SizedBox(height: 10),
        // Actions
        Row(children: [
          if (q.status == QuotationStatus.draft || q.status == QuotationStatus.sent) ...[
            _actionBtn(Icons.edit, 'Edit', () => _showCreateQuotation(context, appState, existing: q)),
            const SizedBox(width: 6),
            _actionBtn(Icons.send, 'Mark Sent', () async {
              q.status = QuotationStatus.sent;
              await appState.updateQuotation(q);
            }),
            const SizedBox(width: 6),
            _actionBtn(Icons.check_circle, 'Accept', () async {
              q.status = QuotationStatus.accepted;
              await appState.updateQuotation(q);
            }),
          ],
          if (q.status == QuotationStatus.accepted)
            _actionBtn(Icons.receipt, 'Convert to Bill', () => _convertToBill(context, appState, q)),
          _actionBtn(Icons.print, 'Print', () => _printQuotation(context, appState, q)),
          const SizedBox(width: 4),
          _actionBtn(Icons.share, 'Share', () => _shareQuotation(context, appState, q), color: const Color(0xFF25D366)),
          const Spacer(),
          if (q.status == QuotationStatus.draft || q.status == QuotationStatus.sent)
            _actionBtn(Icons.cancel, 'Reject', () async {
              q.status = QuotationStatus.rejected;
              await appState.updateQuotation(q);
            }, color: AppColors.error),
          const SizedBox(width: 6),
          _actionBtn(Icons.delete_outline, 'Delete', () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Quotation?'),
              content: Text('Delete ${q.quotationNumber}?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ]));
            if (confirm == true) await appState.deleteQuotation(q.id);
          }, color: AppColors.error),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.4)),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
    ]);
  }

  Widget _actionBtn(IconData icon, String tip, VoidCallback onTap, {Color? color}) {
    return Tooltip(message: tip, child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color ?? AppColors.primary),
          const SizedBox(width: 4),
          Text(tip, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color ?? AppColors.primary)),
        ]),
      ),
    ));
  }

  Color _statusColor(QuotationStatus s) {
    switch (s) {
      case QuotationStatus.draft: return AppColors.info;
      case QuotationStatus.sent: return AppColors.warning;
      case QuotationStatus.accepted: return AppColors.success;
      case QuotationStatus.rejected: return AppColors.error;
      case QuotationStatus.converted: return AppColors.accent;
    }
  }

  void _convertToBill(BuildContext context, AppState appState, Quotation q) async {
    final billNumber = await appState.getNextBillNumber();
    final bill = Bill(
      billNumber: billNumber,
      customerId: q.customerId,
      customerName: q.customerName,
      items: q.items,
      subtotal: q.subtotal,
      discount: q.discount,
      totalTax: q.totalTax,
      totalAmount: q.totalAmount,
      paidAmount: 0,
      status: BillStatus.unpaid,
      notes: 'Converted from ${q.quotationNumber}',
    );
    await appState.createBill(bill);
    q.status = QuotationStatus.converted;
    await appState.updateQuotation(q);
    await appState.loadDashboardStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text('Converted to Bill $billNumber')]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Future<String?> _getNextBillNumber(AppState appState) async {
    return await appState.getNextBillNumber();
  }

  void _showCreateQuotation(BuildContext context, AppState appState, {Quotation? existing}) {
    final isEdit = existing != null;
    final items = <BillItem>[...?existing?.items];
    final customerCtrl = TextEditingController(text: existing?.customerName ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final discountCtrl = TextEditingController(text: (existing?.discount ?? 0).toString());
    String? selectedCustomerId = existing?.customerId;
    bool gstInclusive = false;

    // Load GST mode
    appState.getSetting('billing_gst_inclusive').then((val) {
      if (val == 'true') gstInclusive = true;
    });

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      double subtotal, totalTax;
      if (gstInclusive) {
        subtotal = items.fold<double>(0, (s, i) => s + i.unitPrice * i.quantity / (1 + i.taxRate / 100));
        totalTax = items.fold<double>(0, (s, i) {
          final inclTotal = i.unitPrice * i.quantity;
          return s + inclTotal - inclTotal / (1 + i.taxRate / 100);
        });
      } else {
        subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
        totalTax = items.fold<double>(0, (s, i) => s + i.taxAmount);
      }
      final discount = double.tryParse(discountCtrl.text) ?? 0;
      final totalAmount = subtotal + totalTax - discount;

      return AlertDialog(
        title: Text(isEdit ? 'Edit Quotation' : 'New Quotation'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Customer - Searchable
            Autocomplete<Customer>(
              optionsBuilder: (textValue) {
                final all = appState.customers;
                if (textValue.text.isEmpty) return all;
                final q = textValue.text.toLowerCase();
                return all.where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  (c.phone ?? '').contains(q) ||
                  (c.gstin ?? '').toLowerCase().contains(q));
              },
              displayStringForOption: (c) => c.name,
              fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                if (customerCtrl.text.isNotEmpty && ctrl.text.isEmpty) ctrl.text = customerCtrl.text;
                return TextField(
                  controller: ctrl, focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Search Customer',
                    prefixIcon: Icon(Icons.person_search),
                    hintText: 'Type name / phone / GSTIN...'),
                );
              },
              onSelected: (customer) {
                FocusScope.of(ctx).unfocus();
                setDialogState(() {
                  selectedCustomerId = customer.id;
                  customerCtrl.text = customer.name;
                });
              },
              optionsViewBuilder: (ctx, onSelected, options) {
                return Align(alignment: Alignment.topLeft, child: Material(
                  elevation: 8, borderRadius: BorderRadius.circular(12),
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? const Color(0xFF1E1E2E) : Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true, itemCount: options.length,
                      itemBuilder: (ctx, i) {
                        final c = options.elementAt(i);
                        return ListTile(dense: true,
                          leading: CircleAvatar(radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(c.name[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(c.phone ?? c.gstin ?? '', style: const TextStyle(fontSize: 11)),
                          onTap: () => onSelected(c),
                        );
                      }),
                  ),
                ));
              },
            ),
            const SizedBox(height: 12),
            // Add items
            Row(children: [
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddItem(ctx, appState, items, setDialogState),
                icon: const Icon(Icons.add, size: 16), label: const Text('Add Item')),
            ]),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('No items added', style: TextStyle(fontSize: 12))))
            else
              ...items.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Text('${e.value.quantity} × ${AppFormatters.currency(e.value.unitPrice)} + ${e.value.taxRate}% GST',
                      style: const TextStyle(fontSize: 10)),
                  ])),
                  Text(AppFormatters.currency(e.value.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () {
                    setDialogState(() => items.removeAt(e.key));
                  }),
                ]))),
            const Divider(),
            TextField(controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount ₹', prefixIcon: Icon(Icons.local_offer)),
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
                // GST toggle
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
            onPressed: items.isEmpty ? null : () async {
              final q = Quotation(
                id: existing?.id,
                quotationNumber: existing?.quotationNumber ?? appState.getNextQuotationNumber(),
                customerId: selectedCustomerId,
                customerName: customerCtrl.text.isEmpty ? null : customerCtrl.text,
                items: items,
                subtotal: subtotal,
                discount: discount,
                totalTax: totalTax,
                totalAmount: totalAmount,
                status: existing?.status ?? QuotationStatus.draft,
                notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                createdAt: existing?.createdAt,
              );
              if (isEdit) {
                await appState.updateQuotation(q);
              } else {
                await appState.addQuotation(q);
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.save, size: 18),
            label: Text(isEdit ? 'Update' : 'Save Quotation')),
        ],
      );
    }));
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: Colors.white)),
      ]));
  }

  void _showAddItem(BuildContext context, AppState appState, List<BillItem> items, StateSetter setDialogState) async {
    Item? pickedItem;
    final qtyCtrl = TextEditingController(text: '1');
    final descCtrl = TextEditingController();
    final serialCtrl = TextEditingController();

    final showDesc = (await appState.getSetting('billing_show_description')) == 'true';
    final showSerial = (await appState.getSetting('billing_show_serial_number')) == 'true';

    if (!context.mounted) return;

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
            setLocalState(() => pickedItem = item);
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
            child: Text('Selected: ${pickedItem!.name} \u2014 \u20b9${pickedItem!.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity')),
        if (showDesc) ...[
          const SizedBox(height: 12),
          TextField(controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Item Description',
              prefixIcon: Icon(Icons.description, size: 18),
              hintText: 'Optional description...')),
        ],
        if (showSerial) ...[
          const SizedBox(height: 12),
          TextField(controller: serialCtrl,
            decoration: InputDecoration(
              labelText: 'Serial Number',
              prefixIcon: const Icon(Icons.qr_code, size: 18),
              hintText: 'Optional serial number...',
              suffixIcon: kIsWeb ? null : IconButton(
                icon: const Icon(Icons.camera_alt, size: 18, color: AppColors.primary),
                tooltip: 'Scan barcode/QR',
                onPressed: () {
                  Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (scanCtx) => _QuotationBarcodeScannerPage(onScanned: (code) {
                      Navigator.of(scanCtx).pop();
                      setLocalState(() => serialCtrl.text = code);
                    }),
                  ));
                },
              ))),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (pickedItem == null) return;
          final item = pickedItem!;
          final qty = int.tryParse(qtyCtrl.text) ?? 1;
          setDialogState(() {
            items.add(BillItem(
              itemId: item.id,
              itemName: item.name,
              unitPrice: item.price,
              quantity: qty,
              taxRate: item.taxRate,
              unit: item.unit,
              description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
              serialNumber: serialCtrl.text.trim().isNotEmpty ? serialCtrl.text.trim() : null,
            ));
          });
          Navigator.pop(ctx);
        }, child: const Text('Add')),
      ],
    )));
  }

  // Convert quotation to a temporary Bill for invoice generation
  Bill _quotationAsBill(Quotation q) {
    return Bill(
      id: q.id,
      billNumber: q.quotationNumber,
      customerName: q.customerName,
      items: q.items,
      subtotal: q.subtotal,
      discount: q.discount,
      totalTax: q.totalTax,
      totalAmount: q.totalAmount,
      paidAmount: 0,
      paymentMethod: PaymentMethod.cash,
      status: BillStatus.unpaid,
      createdAt: q.createdAt,
    );
  }

  void _printQuotation(BuildContext context, AppState appState, Quotation q) async {
    final settings = await appState.getAllSettings();
    String selectedSize = settings['pdf_paper_size'] ?? 'a4';

    if (!context.mounted) return;
    final action = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.print, color: AppColors.primary), const SizedBox(width: 10),
          Text('Print ${q.quotationNumber}')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Quotation for ${q.customerName ?? 'customer'}'),
          const SizedBox(height: 16),
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
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'print'),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
          ),
        ],
      ),
    ));

    if (action == 'print' && context.mounted) {
      final s = await appState.getAllSettings();
      final bill = _quotationAsBill(q);
      final template = _parseTemplate(s['pdf_template']);
      final paperSize = selectedSize == 'a5' ? PaperSize.a5 : PaperSize.a4;
      await InvoiceGenerator.generateAndPrint(bill,
        businessName: s['businessName'] ?? 'My Billu',
        businessAddress: s['businessAddress'] ?? '',
        businessPhone: s['businessPhone'] ?? '',
        businessGstin: s['businessGstin'] ?? '',
        businessBankName: s['businessBankName'] ?? '',
        businessBankAccount: s['businessBankAccount'] ?? '',
        businessBankIfsc: s['businessBankIfsc'] ?? '',
        template: template, paperSize: paperSize,
      );
    }
  }

  void _shareQuotation(BuildContext context, AppState appState, Quotation q) async {
    final settings = await appState.getAllSettings();
    String selectedSize = settings['pdf_paper_size'] ?? 'a4';

    if (!context.mounted) return;
    final action = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.share, color: Color(0xFF25D366)), const SizedBox(width: 10),
          Text('Share ${q.quotationNumber}')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Share quotation for ${q.customerName ?? 'customer'}'),
          const SizedBox(height: 16),
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
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () => Navigator.pop(ctx, 'share'),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    ));

    if (action == 'share' && context.mounted) {
      final s = await appState.getAllSettings();
      final bill = _quotationAsBill(q);
      final template = _parseTemplate(s['pdf_template']);
      final paperSize = selectedSize == 'a5' ? PaperSize.a5 : PaperSize.a4;
      try {
        await InvoiceGenerator.shareInvoice(bill,
          businessName: s['businessName'] ?? 'My Billu',
          businessAddress: s['businessAddress'] ?? '',
          businessPhone: s['businessPhone'] ?? '',
          businessGstin: s['businessGstin'] ?? '',
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
          template: template, paperSize: paperSize,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Share error: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

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
      default: return InvoiceTemplate.modern;
    }
  }
}

// ===== Barcode Scanner Page (Android/iOS only) =====
class _QuotationBarcodeScannerPage extends StatefulWidget {
  final void Function(String code) onScanned;
  const _QuotationBarcodeScannerPage({required this.onScanned});
  @override
  State<_QuotationBarcodeScannerPage> createState() => _QuotationBarcodeScannerPageState();
}

class _QuotationBarcodeScannerPageState extends State<_QuotationBarcodeScannerPage> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode / QR Code'),
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
            borderRadius: BorderRadius.circular(20),
          ),
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


