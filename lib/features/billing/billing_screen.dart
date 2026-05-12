import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/models/item.dart';
import '../../core/models/customer.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_generator.dart';
import '../../core/models/cash_book.dart';
import '../../widgets/common_widgets.dart';

class _CartItem {
  final Item item;
  int quantity;
  _CartItem({required this.item, required this.quantity});
  double get subtotal => item.price * quantity;
  double get taxAmount => subtotal * item.taxRate / 100;
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final List<_CartItem> _cart = [];
  Customer? _selectedCustomer;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String _itemSearch = '';
  final _discountCtrl = TextEditingController(text: '0');
  final _walkInNameCtrl = TextEditingController();
  final _walkInPhoneCtrl = TextEditingController();

  double get _subtotal => _cart.fold(0, (s, c) => s + c.subtotal);
  double get _totalTax => _cart.fold(0, (s, c) => s + c.taxAmount);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _totalAmount => (_subtotal + _totalTax - _discount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return Row(children: [
            Expanded(flex: 3, child: _buildItemPicker(context, appState)),
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(left: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                )),
              ),
              child: _buildCartPanel(context, appState),
            ),
          ]);
        }
        return DefaultTabController(length: 2, child: Column(children: [
          TabBar(tabs: [
            Tab(icon: const Icon(Icons.grid_view_rounded), text: 'Items'),
            Tab(icon: const Icon(Icons.shopping_cart_rounded), text: 'Cart (${_cart.length})'),
          ], indicatorColor: AppColors.primary, labelColor: AppColors.primary),
          Expanded(child: TabBarView(children: [
            _buildItemPicker(context, appState),
            _buildCartPanel(context, appState),
          ])),
        ]));
      });
    });
  }

  Widget _buildItemPicker(BuildContext context, AppState appState) {
    final items = _itemSearch.isEmpty ? appState.items
        : appState.items.where((i) => i.name.toLowerCase().contains(_itemSearch.toLowerCase())).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Create Bill', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => setState(() => _itemSearch = v),
            decoration: const InputDecoration(hintText: 'Search items...', prefixIcon: Icon(Icons.search, color: AppColors.primary))),
        ],
      )),
      Expanded(child: items.isEmpty
          ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No items', subtitle: 'Add items in catalog first')
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200, childAspectRatio: 1.1, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final inCart = _cart.any((c) => c.item.id == item.id);
                return GlassCard(onTap: () => _addToCart(item), padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: inCart ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(inCart ? Icons.check_circle : Icons.inventory_2, size: 20,
                        color: inCart ? AppColors.success : AppColors.primary)),
                    const Spacer(),
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(AppFormatters.currency(item.price),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ]));
              })),
    ]);
  }

  Widget _buildCartPanel(BuildContext context, AppState appState) {
    final displayName = _selectedCustomer?.name
        ?? (_walkInNameCtrl.text.trim().isNotEmpty ? _walkInNameCtrl.text.trim() : 'Walk-in Customer');
    final displayPhone = _selectedCustomer?.phone ?? (_walkInPhoneCtrl.text.trim().isNotEmpty ? _walkInPhoneCtrl.text.trim() : null);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () => _showCustomerPicker(context, appState),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Icon(_selectedCustomer != null ? Icons.person : Icons.person_add, size: 18, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                if (displayPhone != null)
                  Text(displayPhone, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
              ])),
              const Icon(Icons.chevron_right, size: 20),
            ]),
          ),
        ),
      ),
      Expanded(child: _cart.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shopping_cart_outlined, size: 48,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('Cart is empty', style: Theme.of(context).textTheme.bodyMedium),
            ]))
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cart.length, itemBuilder: (ctx, i) => _buildCartItem(context, i))),
      // Summary
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          _row('Subtotal', AppFormatters.currency(_subtotal)),
          const SizedBox(height: 6),
          _row('GST', AppFormatters.currency(_totalTax)),
          const SizedBox(height: 6),
          // Discount input
          Row(children: [
            const Text('Discount', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const Spacer(),
            SizedBox(width: 100, height: 36,
              child: TextField(
                controller: _discountCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                decoration: InputDecoration(
                  prefixText: '- ₹',
                  prefixStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => setState(() {}),
              )),
          ]),
          const Divider(height: 16),
          _row('Total', AppFormatters.currency(_totalAmount), bold: true),
          const SizedBox(height: 12),
          SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
            children: PaymentMethod.values.map((pm) {
              final sel = _paymentMethod == pm;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(AppFormatters.paymentMethod(pm.name)),
                  selected: sel, selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: sel ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w500),
                  onSelected: (_) => setState(() => _paymentMethod = pm)));
            }).toList())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : () => _createBill(context, appState),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle, size: 22), SizedBox(width: 8),
                Text('Create Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]))),
        ])),
    ]);
  }

  Widget _buildCartItem(BuildContext context, int index) {
    final c = _cart[index];
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${AppFormatters.currency(c.item.price)} × ${c.quantity}', style: Theme.of(context).textTheme.bodySmall),
          ])),
          Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(onTap: () => setState(() { if (c.quantity > 1) c.quantity--; else _cart.removeAt(index); }),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 18, color: AppColors.primary))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${c.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              InkWell(onTap: () => setState(() => c.quantity++),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 18, color: AppColors.primary))),
            ])),
          const SizedBox(width: 12),
          SizedBox(width: 70, child: Text(AppFormatters.currency(c.subtotal),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.right)),
        ])));
  }

  Widget _row(String l, String v, {bool bold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 18 : 14)),
      Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 18 : 14, color: bold ? AppColors.primary : null)),
    ]);
  }

  void _addToCart(Item item) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.item.id == item.id);
      if (idx >= 0) _cart[idx].quantity++; else _cart.add(_CartItem(item: item, quantity: 1));
    });
  }

  void _showCustomerPicker(BuildContext context, AppState appState) {
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
                    setState(() { _selectedCustomer = null; });
                    Navigator.pop(ctx);
                  }, child: const Text('Use Walk-in', style: TextStyle(fontSize: 12))),
                ]),
                const SizedBox(height: 8),
                TextField(controller: _walkInNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (optional)',
                    prefixIcon: Icon(Icons.person, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: _walkInPhoneCtrl,
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
                    setState(() { _selectedCustomer = null; });
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
                  setState(() {
                    _selectedCustomer = c;
                    _walkInNameCtrl.clear();
                    _walkInPhoneCtrl.clear();
                  });
                  Navigator.pop(ctx);
                })),
            ])),
          ])));
      });
    });
  }

  Future<void> _createBill(BuildContext context, AppState appState) async {
    final billNumber = await appState.getNextBillNumber();
    final walkInName = _walkInNameCtrl.text.trim();
    final walkInPhone = _walkInPhoneCtrl.text.trim();
    final billItems = _cart.map((c) => BillItem(itemId: c.item.id, itemName: c.item.name,
      unitPrice: c.item.price, quantity: c.quantity, taxRate: c.item.taxRate, unit: c.item.unit)).toList();
    final bill = Bill(billNumber: billNumber, customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? (walkInName.isNotEmpty ? walkInName : null),
      customerPhone: _selectedCustomer?.phone ?? (walkInPhone.isNotEmpty ? walkInPhone : null),
      items: billItems, subtotal: _subtotal,
      discount: _discount,
      totalTax: _totalTax, totalAmount: _totalAmount,
      paidAmount: _paymentMethod == PaymentMethod.credit ? 0 : _totalAmount,
      paymentMethod: _paymentMethod,
      status: _paymentMethod == PaymentMethod.credit ? BillStatus.unpaid : BillStatus.paid);
    await appState.createBill(bill);

    // Auto-add to Cash Book or Bank Book based on payment method
    if (_paymentMethod != PaymentMethod.credit && _totalAmount > 0) {
      if (_paymentMethod == PaymentMethod.cash) {
        // Cash payment → Cash Book (Cash In)
        await appState.addCashBookEntry(CashBookEntry(
          type: TransactionType.cashIn,
          amount: _totalAmount,
          description: 'Sales - $billNumber',
          reference: billNumber,
          category: 'Sales',
        ));
      } else {
        // UPI, Card, Bank Transfer → Bank Book (Bank Deposit)
        final bankId = appState.bankAccounts.isNotEmpty ? appState.bankAccounts.first.id : null;
        await appState.addCashBookEntry(CashBookEntry(
          type: TransactionType.bankIn,
          amount: _totalAmount,
          description: 'Sales (${_paymentMethod.name.toUpperCase()}) - $billNumber',
          reference: billNumber,
          bankAccountId: bankId,
          category: 'Sales',
        ));
      }
    }

    if (mounted) {
      setState(() { _cart.clear(); _selectedCustomer = null; _paymentMethod = PaymentMethod.cash;
        _discountCtrl.text = '0'; _walkInNameCtrl.clear(); _walkInPhoneCtrl.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text('Bill $billNumber created!')]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

      // Offer to print invoice
      final shouldPrint = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.print, color: AppColors.primary), SizedBox(width: 10), Text('Print Invoice?')]),
        content: Text('Bill $billNumber created successfully.\nWould you like to print/download the invoice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Invoice'),
          ),
        ],
      ));

      if (shouldPrint == true && mounted) {
        final settings = await appState.getAllSettings();
        await InvoiceGenerator.generateAndPrint(bill,
          businessName: settings['businessName'] ?? 'My Billu',
          businessAddress: settings['businessAddress'] ?? '',
          businessPhone: settings['businessPhone'] ?? '',
          businessGstin: settings['businessGstin'] ?? '',
        );
      }
    }
  }
}
