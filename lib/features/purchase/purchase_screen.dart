import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/item.dart';
import '../../core/models/purchase.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _supplierCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_CartEntry> _cart = [];
  Item? _selectedItem;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();

  double get _subtotal => _cart.fold(0, (sum, e) => sum + e.subtotal);
  double get _totalTax => _cart.fold(0, (sum, e) => sum + e.taxAmount);
  double get _total => _subtotal + _totalTax;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New Purchase Entry', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 20),

            // Supplier Info
            GlassCard(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Supplier Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                if (isWide) Row(children: [
                  Expanded(child: TextField(controller: _supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier Name *', prefixIcon: Icon(Icons.business)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _supplierPhoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _invoiceCtrl,
                    decoration: const InputDecoration(labelText: 'Invoice #', prefixIcon: Icon(Icons.receipt)))),
                ]) else ...[
                  TextField(controller: _supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier Name *', prefixIcon: Icon(Icons.business))),
                  const SizedBox(height: 12),
                  TextField(controller: _supplierPhoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 12),
                  TextField(controller: _invoiceCtrl,
                    decoration: const InputDecoration(labelText: 'Invoice #', prefixIcon: Icon(Icons.receipt))),
                ],
              ])),
            const SizedBox(height: 16),

            // Add Items
            GlassCard(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Add Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: isWide ? 250 : double.infinity,
                    child: DropdownButtonFormField<Item>(
                      value: _selectedItem,
                      hint: const Text('Select Item'),
                      isExpanded: true,
                      items: appState.items.map((item) => DropdownMenuItem(
                        value: item, child: Text('${item.name} (${item.unit})'))).toList(),
                      onChanged: (item) {
                        setState(() { _selectedItem = item; _costCtrl.text = item?.price.toStringAsFixed(2) ?? ''; });
                      },
                    )),
                  SizedBox(width: isWide ? 120 : 140,
                    child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty'))),
                  SizedBox(width: isWide ? 150 : 140,
                    child: TextField(controller: _costCtrl, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost Price (₹)'))),
                  ElevatedButton.icon(
                    onPressed: _addToCart,
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                    label: const Text('Add'),
                  ),
                ]),
              ])),
            const SizedBox(height: 16),

            // Cart
            if (_cart.isNotEmpty) ...[
              GlassCard(padding: const EdgeInsets.all(16), child: Column(children: [
                Row(children: [
                  const Expanded(child: Text('Purchase Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  Text('${_cart.length} items', style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 12),
                ..._cart.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${e.qty} × ${AppFormatters.currency(e.costPrice)} + ${e.item.taxRate}% GST',
                          style: Theme.of(context).textTheme.bodySmall),
                      ])),
                      Text(AppFormatters.currency(e.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                        onPressed: () => setState(() => _cart.removeAt(i))),
                    ]));
                }),
                const Divider(),
                _totalRow('Subtotal', AppFormatters.currency(_subtotal)),
                _totalRow('GST', AppFormatters.currency(_totalTax)),
                _totalRow('Total', AppFormatters.currency(_total), bold: true),
              ])),
              const SizedBox(height: 16),

              // Notes
              TextField(controller: _notesCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes))),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () => _savePurchase(context, appState),
                  icon: const Icon(Icons.save, size: 22),
                  label: const Text('Save Purchase & Update Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )),
            ],
          ]),
        );
      });
    });
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize: bold ? 18 : 14)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: bold ? 18 : 14, color: bold ? AppColors.primary : null)),
      ]));
  }

  void _addToCart() {
    if (_selectedItem == null) return;
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    if (qty <= 0 || cost <= 0) return;

    setState(() {
      _cart.add(_CartEntry(item: _selectedItem!, qty: qty, costPrice: cost));
      _selectedItem = null;
      _qtyCtrl.text = '1';
      _costCtrl.clear();
    });
  }

  Future<void> _savePurchase(BuildContext context, AppState appState) async {
    if (_supplierCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier name is required')));
      return;
    }
    if (_cart.isEmpty) return;

    try {
      final poNumber = await appState.getNextPurchaseNumber();
      final purchaseItems = _cart.map((e) => PurchaseItem(
        itemId: e.item.id, itemName: e.item.name,
        unitCost: e.costPrice, quantity: e.qty,
        taxRate: e.item.taxRate, unit: e.item.unit,
      )).toList();

      final purchase = Purchase(
        purchaseNumber: poNumber,
        supplierName: _supplierCtrl.text.trim(),
        supplierPhone: _supplierPhoneCtrl.text.trim().isEmpty ? null : _supplierPhoneCtrl.text.trim(),
        invoiceNumber: _invoiceCtrl.text.trim().isEmpty ? null : _invoiceCtrl.text.trim(),
        items: purchaseItems,
        subtotal: _subtotal,
        totalTax: _totalTax,
        totalAmount: _total,
        paidAmount: _total,
        status: PurchaseStatus.received,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await appState.createPurchase(purchase);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text('Purchase $poNumber saved! Stock updated.'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        setState(() {
          _cart.clear();
          _supplierCtrl.clear();
          _supplierPhoneCtrl.clear();
          _invoiceCtrl.clear();
          _notesCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

class _CartEntry {
  final Item item;
  final int qty;
  final double costPrice;

  _CartEntry({required this.item, required this.qty, required this.costPrice});

  double get subtotal => costPrice * qty;
  double get taxAmount => subtotal * item.taxRate / 100;
  double get total => subtotal + taxAmount;
}
