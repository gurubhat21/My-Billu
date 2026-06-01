import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/models/quotation.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_generator.dart';
import '../../widgets/common_widgets.dart';

// Cart item for quotation â€” matches billing's _CartItem
class _QuotCartItem {
  final Item item;
  int quantity;
  double price;
  String description;
  List<String> serialNumbers;
  _QuotCartItem({required this.item, required this.quantity, double? price, this.description = '', List<String>? serialNumbers})
    : price = price ?? item.price,
      serialNumbers = serialNumbers ?? [''];
}

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
          Padding(padding: EdgeInsets.all(isWide ? 24 : 12), child: Row(children: [
            Expanded(child: Text('Quotations / Estimates', style: Theme.of(context).textTheme.headlineLarge)),
            ElevatedButton.icon(
              onPressed: () => _showCreateQuotation(context, appState),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              icon: const Icon(Icons.add, size: 16),
              label: Text(isWide ? 'New Quotation' : 'New', style: const TextStyle(fontSize: 13)),
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
            Text(q.customerName ?? 'Walk-in Customer', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
            if (q.customerPhone != null && q.customerPhone!.isNotEmpty)
              Text('ðŸ“± ${q.customerPhone}', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
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
          _actionBtn(Icons.edit, 'Edit', () => _showCreateQuotation(context, appState, existing: q)),
          const SizedBox(width: 6),
          if (q.status == QuotationStatus.draft || q.status == QuotationStatus.sent) ...[
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
          _actionBtn(Icons.save, 'Save', () => _saveQuotationPdf(context, appState, q), color: const Color(0xFF8B5CF6)),
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
      customerPhone: q.customerPhone,
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

  // ==================== CREATE / EDIT QUOTATION ====================
  void _showCreateQuotation(BuildContext context, AppState appState, {Quotation? existing}) async {
    final isEdit = existing != null;

    // Load settings
    final showDesc = (await appState.getSetting('billing_show_description')) == 'true';
    final gstMode = (await appState.getSetting('billing_gst_inclusive')) == 'true';

    if (!context.mounted) return;

    // Build cart from existing items
    final cart = <_QuotCartItem>[];
    if (existing != null) {
      for (final bi in existing.items) {
        final item = appState.items.where((it) => it.id == bi.itemId).firstOrNull;
        cart.add(_QuotCartItem(
          item: item ?? Item(id: bi.itemId, name: bi.itemName, price: bi.unitPrice, taxRate: bi.taxRate, unit: bi.unit),
          quantity: bi.quantity,
          price: bi.unitPrice,
          description: bi.description ?? '',
          serialNumbers: bi.serialNumber != null ? [...bi.serialNumber!.split(', '), ''] : [''],
        ));
      }
    }

    final customerCtrl = TextEditingController(text: existing?.customerName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.customerPhone ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final discountCtrl = TextEditingController(text: (existing?.discount ?? 0).toString());
    String? selectedCustomerId = existing?.customerId;
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
        title: Text(isEdit ? 'Edit Quotation' : 'New Quotation'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // --- Customer picker (same as billing) ---
            InkWell(
              onTap: () => _showQuotCustomerPicker(ctx, appState, customerCtrl, phoneCtrl, (cust) {
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
                onPressed: () => _showQuotAddItem(ctx, appState, cart, setDialogState),
                icon: const Icon(Icons.add, size: 16), label: const Text('Add Item')),
            ]),
            // --- Cart items (billing style) ---
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
              ...cart.asMap().entries.map((e) => _buildQuotCartItem(ctx, e.key, cart, setDialogState, showDesc)),
            const Divider(),
            TextField(controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount â‚¹', prefixIcon: Icon(Icons.local_offer)),
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
              final billItems = cart.map((c) {
                final serials = c.serialNumbers.where((s) => s.isNotEmpty).toList();
                return BillItem(
                  itemId: c.item.id, itemName: c.item.name,
                  unitPrice: c.price, quantity: c.quantity, taxRate: c.item.taxRate, unit: c.item.unit,
                  description: c.description.isNotEmpty ? c.description : null,
                  serialNumber: serials.isNotEmpty ? serials.join(', ') : null,
                );
              }).toList();

              final q = Quotation(
                id: existing?.id,
                quotationNumber: existing?.quotationNumber ?? appState.getNextQuotationNumber(),
                customerId: selectedCustomerId,
                customerName: customerCtrl.text.isEmpty ? null : customerCtrl.text,
                customerPhone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                items: billItems,
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

  // ==================== CART ITEM WIDGET (same as billing) ====================
  Widget _buildQuotCartItem(BuildContext context, int index, List<_QuotCartItem> cart, StateSetter setDialogState, bool showDesc) {
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
                      decoration: const InputDecoration(prefixText: 'â‚¹ ', labelText: 'Unit Price'),
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
                key: ValueKey('qdesc_${c.item.id}_$index'),
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
  void _showQuotCustomerPicker(BuildContext context, AppState appState,
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
  void _showQuotAddItem(BuildContext context, AppState appState, List<_QuotCartItem> cart, StateSetter setDialogState) {
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
            cart.add(_QuotCartItem(item: item, quantity: qty, price: price));
          });
          Navigator.pop(ctx);
        }, child: const Text('Add')),
      ],
    )));
  }

  // ==================== PRINT / SHARE / HELPERS ====================
  // Convert quotation to a temporary Bill for invoice generation
  Bill _quotationAsBill(Quotation q) {
    return Bill(
      id: q.id,
      billNumber: q.quotationNumber,
      customerName: q.customerName,
      customerPhone: q.customerPhone,
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
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'save'),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save PDF'),
          ),
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
      final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
      await InvoiceGenerator.generateAndPrint(bill,
        businessName: s['businessName'] ?? 'My Billu',
        businessAddress: s['businessAddress'] ?? '',
        businessPhone: s['businessPhone'] ?? '',
        businessGstin: s['businessGstin'] ?? '',
        businessBankName: s['businessBankName'] ?? '',
        businessBankAccount: s['businessBankAccount'] ?? '',
        businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
        logoBytes: logoBytes,
        template: template, paperSize: paperSize,
        documentTitle: 'SALES QUOTATION',
        thankYouMessage: s['pdf_thank_you_message'],
        termsConditions: s['pdf_terms_conditions'],
      );
    } else if (action == 'save' && context.mounted) {
      final s = await appState.getAllSettings();
      final bill = _quotationAsBill(q);
      final template = _parseTemplate(s['pdf_template']);
      final paperSize = selectedSize == 'a5' ? PaperSize.a5 : PaperSize.a4;
      final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
      try {
        final savedPath = await InvoiceGenerator.savePdfToFile(bill,
          businessName: s['businessName'] ?? 'My Billu',
          businessAddress: s['businessAddress'] ?? '',
          businessPhone: s['businessPhone'] ?? '',
          businessGstin: s['businessGstin'] ?? '',
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
          logoBytes: logoBytes,
          template: template, paperSize: paperSize,
          documentTitle: 'SALES QUOTATION',
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

  void _saveQuotationPdf(BuildContext context, AppState appState, Quotation q) async {
    final s = await appState.getAllSettings();
    final bill = _quotationAsBill(q);
    final template = _parseTemplate(s['pdf_template']);
    final paperSize = (s['pdf_paper_size'] ?? 'a4') == 'a5' ? PaperSize.a5 : PaperSize.a4;
    final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
    try {
      final savedPath = await InvoiceGenerator.savePdfToFile(bill,
        businessName: s['businessName'] ?? 'My Billu',
        businessAddress: s['businessAddress'] ?? '',
        businessPhone: s['businessPhone'] ?? '',
        businessGstin: s['businessGstin'] ?? '',
        businessBankName: s['businessBankName'] ?? '',
        businessBankAccount: s['businessBankAccount'] ?? '',
        businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
        logoBytes: logoBytes,
        template: template, paperSize: paperSize,
        documentTitle: 'SALES QUOTATION',
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
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'save'),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save PDF'),
          ),
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
      final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
      try {
        await InvoiceGenerator.shareInvoice(bill,
          businessName: s['businessName'] ?? 'My Billu',
          businessAddress: s['businessAddress'] ?? '',
          businessPhone: s['businessPhone'] ?? '',
          businessGstin: s['businessGstin'] ?? '',
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
          logoBytes: logoBytes,
          template: template, paperSize: paperSize,
          documentTitle: 'SALES QUOTATION',
          thankYouMessage: s['pdf_thank_you_message'],
          termsConditions: s['pdf_terms_conditions'],
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Share error: $e'), backgroundColor: AppColors.error));
        }
      }
    } else if (action == 'save' && context.mounted) {
      final s = await appState.getAllSettings();
      final bill = _quotationAsBill(q);
      final template = _parseTemplate(s['pdf_template']);
      final paperSize = selectedSize == 'a5' ? PaperSize.a5 : PaperSize.a4;
      final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
      try {
        final savedPath = await InvoiceGenerator.savePdfToFile(bill,
          businessName: s['businessName'] ?? 'My Billu',
          businessAddress: s['businessAddress'] ?? '',
          businessPhone: s['businessPhone'] ?? '',
          businessGstin: s['businessGstin'] ?? '',
          businessBankName: s['businessBankName'] ?? '',
          businessBankAccount: s['businessBankAccount'] ?? '',
          businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
          logoBytes: logoBytes,
          template: template, paperSize: paperSize,
          documentTitle: 'SALES QUOTATION',
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