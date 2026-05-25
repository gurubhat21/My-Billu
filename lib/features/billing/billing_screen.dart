import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  String description;
  List<String> serialNumbers;
  _CartItem({required this.item, required this.quantity, this.description = '', List<String>? serialNumbers})
    : serialNumbers = serialNumbers ?? [''];
  double get subtotal => item.price * quantity;
  double get taxAmount => subtotal * item.taxRate / 100;
  void updateQuantity(int newQty) {
    quantity = newQty;
  }
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
  bool _isPartial = false;
  PaymentMethod _partialMethod1 = PaymentMethod.cash;
  PaymentMethod _partialMethod2 = PaymentMethod.upi;
  final _partialAmount1Ctrl = TextEditingController();
  String _itemSearch = '';
  bool _isGridView = true;
  final _discountCtrl = TextEditingController(text: '0');
  final _walkInNameCtrl = TextEditingController();
  final _walkInPhoneCtrl = TextEditingController();
  bool _showDescription = false;
  bool _showSerialNumber = false;
  final Map<String, FocusNode> _snFocusNodes = {};
  bool _gstInclusive = false;
  // Credit advance payment
  double _creditPaidAmount = 0;
  PaymentMethod _creditPaymentMethod = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _loadColumnSettings();
  }

  Future<void> _loadColumnSettings() async {
    final appState = context.read<AppState>();
    final desc = await appState.getSetting('billing_show_description');
    final serial = await appState.getSetting('billing_show_serial_number');
    final gstMode = await appState.getSetting('billing_gst_inclusive');
    if (mounted) {
      setState(() {
        _showDescription = desc == 'true';
        _showSerialNumber = serial == 'true';
        _gstInclusive = gstMode == 'true';
      });
    }
  }

  // When GST exclusive: subtotal = price * qty, tax = subtotal * rate/100
  // When GST inclusive: price already includes GST, so extract it
  double _itemSubtotal(_CartItem c) {
    if (_gstInclusive) {
      return c.item.price * c.quantity / (1 + c.item.taxRate / 100);
    }
    return c.item.price * c.quantity;
  }

  double _itemTax(_CartItem c) {
    if (_gstInclusive) {
      final inclTotal = c.item.price * c.quantity;
      return inclTotal - inclTotal / (1 + c.item.taxRate / 100);
    }
    return c.item.price * c.quantity * c.item.taxRate / 100;
  }

  double get _subtotal => _cart.fold(0.0, (s, c) => s + _itemSubtotal(c));
  double get _totalTax => _cart.fold(0.0, (s, c) => s + _itemTax(c));
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
          Row(children: [
            Expanded(child: Text('Create Bill', style: Theme.of(context).textTheme.headlineLarge)),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _viewToggleBtn(Icons.grid_view_rounded, true),
                _viewToggleBtn(Icons.view_list_rounded, false),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => setState(() => _itemSearch = v),
            decoration: const InputDecoration(hintText: 'Search items...', prefixIcon: Icon(Icons.search, color: AppColors.primary))),
        ],
      )),
      Expanded(child: items.isEmpty
          ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No items', subtitle: 'Add items in catalog first')
          : _isGridView ? _buildGridItems(items) : _buildListItems(items)),
    ]);
  }

  Widget _viewToggleBtn(IconData icon, bool isGrid) {
    final active = _isGridView == isGrid;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _isGridView = isGrid),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: active ? Colors.white : AppColors.primary.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildGridItems(List<Item> items) {
    return GridView.builder(
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
      });
  }

  Widget _buildListItems(List<Item> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final inCart = _cart.any((c) => c.item.id == item.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GlassCard(
            onTap: () => _addToCart(item),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: inCart ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(inCart ? Icons.check_circle : Icons.inventory_2, size: 18,
                  color: inCart ? AppColors.success : AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${item.hsnCode != null && item.hsnCode!.isNotEmpty ? "HSN: ${item.hsnCode} • " : ""}Qty: ${item.stockQuantity}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
              ])),
              Text(AppFormatters.currency(item.price),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
        );
      });
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
          : ListView.builder(
              key: ValueKey(_cart.length),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cart.length, itemBuilder: (ctx, i) => _buildCartItem(context, i))),
      // Summary
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          // GST toggle
          Row(children: [
            Icon(Icons.receipt_long, size: 16,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 6),
            Text(_gstInclusive ? 'GST Inclusive' : 'GST Exclusive',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: _gstInclusive ? AppColors.success : AppColors.primary)),
            const Spacer(),
            SizedBox(height: 28, child: Switch(
              value: _gstInclusive,
              activeColor: AppColors.success,
              onChanged: (v) async {
                setState(() => _gstInclusive = v);
                final appState = context.read<AppState>();
                await appState.saveSetting('billing_gst_inclusive', v.toString());
              },
            )),
          ]),
          const SizedBox(height: 4),
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
          Wrap(spacing: 8, runSpacing: 8,
            children: [
              ...PaymentMethod.values.map((pm) {
                final sel = !_isPartial && _paymentMethod == pm;
                return ChoiceChip(label: Text(AppFormatters.paymentMethod(pm.name)),
                  selected: sel, selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: sel ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w500),
                  onSelected: (_) {
                    if (pm == PaymentMethod.credit) {
                      _showCreditPaymentDialog(context);
                    } else {
                      setState(() { _paymentMethod = pm; _isPartial = false; });
                    }
                  });
              }),
              ChoiceChip(
                avatar: _isPartial ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                label: const Text('Partial'),
                selected: _isPartial,
                selectedColor: Colors.orangeAccent,
                labelStyle: TextStyle(color: _isPartial ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() {
                    _isPartial = true;
                    _partialAmount1Ctrl.text = '';
                  })),
            ],
          ),
          // Credit advance info display
          if (!_isPartial && _paymentMethod == PaymentMethod.credit && _creditPaidAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Advance Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(AppFormatters.currency(_creditPaidAmount),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Via', style: TextStyle(fontSize: 11)),
                  Text(AppFormatters.paymentMethod(_creditPaymentMethod.name),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Pending', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
                  Text(AppFormatters.currency(_totalAmount - _creditPaidAmount),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.error)),
                ]),
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, height: 30,
                  child: OutlinedButton(
                    onPressed: () => _showCreditPaymentDialog(context),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero,
                      side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5))),
                    child: const Text('Edit', style: TextStyle(fontSize: 11)),
                  )),
              ])),
          ],
          // ── Partial payment split UI ──
          if (_isPartial) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.call_split, size: 16, color: Colors.orangeAccent),
                  SizedBox(width: 6),
                  Text('Split Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.orangeAccent)),
                ]),
                const SizedBox(height: 12),
                // Method 1
                Row(children: [
                  const Text('Method 1: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [PaymentMethod.cash, PaymentMethod.upi, PaymentMethod.card, PaymentMethod.bank].map((pm) {
                    final sel = _partialMethod1 == pm;
                    return ChoiceChip(label: Text(AppFormatters.paymentMethod(pm.name), style: TextStyle(fontSize: 10, color: sel ? Colors.white : null)),
                      selected: sel, selectedColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _partialMethod1 = pm));
                  }).toList())),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _partialAmount1Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount for ${AppFormatters.paymentMethod(_partialMethod1.name)}',
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Method 2
                Row(children: [
                  const Text('Method 2: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [PaymentMethod.cash, PaymentMethod.upi, PaymentMethod.card, PaymentMethod.bank].map((pm) {
                    final sel = _partialMethod2 == pm;
                    return ChoiceChip(label: Text(AppFormatters.paymentMethod(pm.name), style: TextStyle(fontSize: 10, color: sel ? Colors.white : null)),
                      selected: sel, selectedColor: AppColors.accent,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _partialMethod2 = pm));
                  }).toList())),
                ]),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final amt1 = double.tryParse(_partialAmount1Ctrl.text) ?? 0;
                  final amt2 = _totalAmount - amt1;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                      child: Row(children: [
                        const Icon(Icons.currency_rupee, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text('${AppFormatters.paymentMethod(_partialMethod2.name)}: ',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(AppFormatters.currency(amt2 > 0 ? amt2 : 0),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accent)),
                      ]),
                    ),
                    if (amt1 > _totalAmount)
                      Padding(padding: const EdgeInsets.only(top: 6),
                        child: Text('⚠ Amount exceeds total (${AppFormatters.currency(_totalAmount)})',
                          style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600))),
                  ]);
                }),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            if (_cart.isNotEmpty)
              Expanded(child: SizedBox(height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('Clear Cart?'),
                      content: Text('Remove all ${_cart.length} items from cart?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() { _cart.clear(); _discountCtrl.text = '0'; });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Clear All')),
                      ],
                    ));
                  },
                  icon: const Icon(Icons.delete_sweep, size: 20, color: AppColors.error),
                  label: const Text('Clear', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ))),
            if (_cart.isNotEmpty) const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(height: 50,
              child: ElevatedButton(
                onPressed: _cart.isEmpty ? null : () => _createBill(context, appState),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, size: 22), SizedBox(width: 8),
                  Text('Create Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ])))),
          ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              // Tappable price
              GestureDetector(
                onTap: () {
                  final ctrl = TextEditingController(text: c.item.price.toStringAsFixed(2));
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Edit Price', style: TextStyle(fontSize: 16)),
                    content: TextField(
                      controller: ctrl, autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Unit Price'),
                      onSubmitted: (_) {
                        final p = double.tryParse(ctrl.text);
                        if (p != null && p >= 0) setState(() => c.item.price = p);
                        Navigator.pop(ctx);
                      },
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () {
                        final p = double.tryParse(ctrl.text);
                        if (p != null && p >= 0) setState(() => c.item.price = p);
                        Navigator.pop(ctx);
                      }, child: const Text('Save')),
                    ],
                  ));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${AppFormatters.currency(c.item.price)} \u00d7 ${c.quantity}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 11, color: Colors.white.withValues(alpha: 0.25)),
                ]),
              ),
            ])),
            Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_cart[index].quantity > 1) {
                        _cart[index].updateQuantity(_cart[index].quantity - 1);
                      } else {
                        _cart.removeAt(index);
                      }
                    });
                  },
                  icon: const Icon(Icons.remove, size: 20, color: AppColors.primary),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  splashRadius: 22,
                ),
                // Tappable quantity
                GestureDetector(
                  onTap: () {
                    final ctrl = TextEditingController(text: c.quantity.toString());
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('Edit Quantity', style: TextStyle(fontSize: 16)),
                      content: TextField(
                        controller: ctrl, autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        onSubmitted: (_) {
                          final q = int.tryParse(ctrl.text);
                          if (q != null && q > 0) setState(() => _cart[index].updateQuantity(q));
                          Navigator.pop(ctx);
                        },
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () {
                          final q = int.tryParse(ctrl.text);
                          if (q != null && q > 0) setState(() => _cart[index].updateQuantity(q));
                          Navigator.pop(ctx);
                        }, child: const Text('Save')),
                      ],
                    ));
                  },
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${c.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted))),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _cart[index].updateQuantity(_cart[index].quantity + 1);
                    });
                  },
                  icon: const Icon(Icons.add, size: 20, color: AppColors.primary),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  splashRadius: 22,
                ),
              ])),
            const SizedBox(width: 12),
            SizedBox(width: 70, child: Text(AppFormatters.currency(c.subtotal),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.right)),
          ]),
          // Optional description field
          if (_showDescription)
            Padding(padding: const EdgeInsets.only(top: 6),
              child: TextFormField(
                key: ValueKey('desc_${c.item.id}'),
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
          // Dynamic serial number fields — Enter/scan adds next field
          if (_showSerialNumber)
            ...List.generate(c.serialNumbers.length, (si) {
              final focusKey = 'sn_${c.item.id}_$si';
              _snFocusNodes.putIfAbsent(focusKey, () => FocusNode());
              return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextFormField(
                key: ValueKey('serial_${c.item.id}_${si}_${c.serialNumbers.length}'),
                initialValue: c.serialNumbers[si],
                focusNode: _snFocusNodes[focusKey],
                onChanged: (v) => c.serialNumbers[si] = v,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() {
                      c.serialNumbers.add('');
                    });
                    // Focus the new field after build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final nextKey = 'sn_${c.item.id}_${si + 1}';
                      _snFocusNodes.putIfAbsent(nextKey, () => FocusNode());
                      _snFocusNodes[nextKey]!.requestFocus();
                    });
                  }
                },
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: c.serialNumbers.length > 1
                      ? 'Serial #${si + 1}...'
                      : 'Serial number... (Enter to add next)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.qr_code, size: 16),
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (c.serialNumbers.length > 1)
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => c.serialNumbers.removeAt(si)),
                      ),
                    if (!kIsWeb)
                      IconButton(
                        icon: const Icon(Icons.camera_alt, size: 18, color: AppColors.primary),
                        tooltip: 'Scan barcode/QR',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _scanBarcode(context, (code) {
                          setState(() {
                            c.serialNumbers[si] = code;
                            c.serialNumbers.add('');
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final nextKey = 'sn_${c.item.id}_${si + 1}';
                            _snFocusNodes.putIfAbsent(nextKey, () => FocusNode());
                            _snFocusNodes[nextKey]!.requestFocus();
                          });
                        }),
                      ),
                  ]),
                ),
              ));
            }),
        ])));
  }


  void _showCreditPaymentDialog(BuildContext context) {
    final amtCtrl = TextEditingController(text: _creditPaidAmount > 0 ? _creditPaidAmount.toStringAsFixed(2) : '');
    PaymentMethod selectedMethod = _creditPaymentMethod;
    final total = _totalAmount;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final paid = double.tryParse(amtCtrl.text) ?? 0;
        final pending = total - paid;
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.credit_card, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 10),
            Text('Credit Payment', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Total amount display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Bill Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(AppFormatters.currency(total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 16),
            // Paid amount
            TextField(
              controller: amtCtrl, autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Advance Paid Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                helperText: 'Enter 0 for full credit (no advance)'),
              onChanged: (_) => setDialogState(() {}),
            ),
            const SizedBox(height: 14),
            // Payment method selection
            const Align(alignment: Alignment.centerLeft,
              child: Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
            Row(children: [PaymentMethod.cash, PaymentMethod.upi].map((pm) {
              final sel = selectedMethod == pm;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(AppFormatters.paymentMethod(pm.name)),
                  selected: sel, selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: sel ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w600),
                  onSelected: (_) => setDialogState(() => selectedMethod = pm),
                ));
            }).toList()),
            const SizedBox(height: 14),
            // Pending display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (pending > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (pending > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(pending > 0 ? 'Pending Amount' : 'Fully Paid',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                    color: pending > 0 ? AppColors.error : AppColors.success)),
                Text(AppFormatters.currency(pending > 0 ? pending : 0),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                    color: pending > 0 ? AppColors.error : AppColors.success)),
              ]),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                // No advance — full credit
                setState(() {
                  _paymentMethod = PaymentMethod.credit;
                  _isPartial = false;
                  _creditPaidAmount = 0;
                });
                Navigator.pop(ctx);
              },
              child: const Text('No Advance')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _paymentMethod = PaymentMethod.credit;
                  _isPartial = false;
                  _creditPaidAmount = paid;
                  _creditPaymentMethod = selectedMethod;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Confirm')),
          ],
        );
      },
    ));
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

  void _scanBarcode(BuildContext context, void Function(String code) onScanned) {
    if (kIsWeb) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => _BarcodeScannerPage(onScanned: (code) {
        Navigator.of(ctx).pop();
        onScanned(code);
      }),
    ));
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
    try {
      final billNumber = await appState.getNextBillNumber();
      final walkInName = _walkInNameCtrl.text.trim();
      final walkInPhone = _walkInPhoneCtrl.text.trim();
      final billItems = _cart.map((c) {
        final serials = c.serialNumbers.where((s) => s.isNotEmpty).toList();
        return BillItem(itemId: c.item.id, itemName: c.item.name,
          unitPrice: c.item.price, quantity: c.quantity, taxRate: c.item.taxRate, unit: c.item.unit,
          description: c.description.isNotEmpty ? c.description : null,
          serialNumber: serials.isNotEmpty ? serials.join(', ') : null);
      }).toList();
      final bill = Bill(billNumber: billNumber, customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? (walkInName.isNotEmpty ? walkInName : null),
        customerPhone: _selectedCustomer?.phone ?? (walkInPhone.isNotEmpty ? walkInPhone : null),
        items: billItems, subtotal: _subtotal,
        discount: _discount,
        totalTax: _totalTax, totalAmount: _totalAmount,
        paidAmount: _isPartial ? _totalAmount : (_paymentMethod == PaymentMethod.credit ? _creditPaidAmount : _totalAmount),
        paymentMethod: _isPartial ? _partialMethod1 : (_paymentMethod == PaymentMethod.credit && _creditPaidAmount > 0 ? _creditPaymentMethod : _paymentMethod),
        status: _isPartial ? BillStatus.paid : (_paymentMethod == PaymentMethod.credit ? (_creditPaidAmount >= _totalAmount ? BillStatus.paid : BillStatus.unpaid) : BillStatus.paid));
      await appState.createBill(bill);

      // Auto-add to Cash Book or Bank Book based on payment method
      if (_isPartial && _totalAmount > 0) {
        // Handle partial: two entries
        final amt1 = double.tryParse(_partialAmount1Ctrl.text) ?? 0;
        final amt2 = _totalAmount - amt1;
        try {
          // Entry 1
          if (amt1 > 0) {
            if (_partialMethod1 == PaymentMethod.cash) {
              await appState.addCashBookEntry(CashBookEntry(
                type: TransactionType.cashIn,
                amount: amt1,
                description: 'Sales (SPLIT-${_partialMethod1.name.toUpperCase()}) - $billNumber',
                reference: billNumber,
                category: 'Sales',
              ));
            } else {
              final bankId = appState.bankAccounts.isNotEmpty ? appState.bankAccounts.first.id : null;
              await appState.addCashBookEntry(CashBookEntry(
                type: TransactionType.bankIn,
                amount: amt1,
                description: 'Sales (SPLIT-${_partialMethod1.name.toUpperCase()}) - $billNumber',
                reference: billNumber,
                bankAccountId: bankId,
                category: 'Sales',
              ));
            }
          }
          // Entry 2
          if (amt2 > 0) {
            if (_partialMethod2 == PaymentMethod.cash) {
              await appState.addCashBookEntry(CashBookEntry(
                type: TransactionType.cashIn,
                amount: amt2,
                description: 'Sales (SPLIT-${_partialMethod2.name.toUpperCase()}) - $billNumber',
                reference: billNumber,
                category: 'Sales',
              ));
            } else {
              final bankId = appState.bankAccounts.isNotEmpty ? appState.bankAccounts.first.id : null;
              await appState.addCashBookEntry(CashBookEntry(
                type: TransactionType.bankIn,
                amount: amt2,
                description: 'Sales (SPLIT-${_partialMethod2.name.toUpperCase()}) - $billNumber',
                reference: billNumber,
                bankAccountId: bankId,
                category: 'Sales',
              ));
            }
          }
        } catch (e) {
          debugPrint('Partial Cash/Bank book entry error: $e');
        }
      } else if (_paymentMethod == PaymentMethod.credit && _creditPaidAmount > 0) {
        // Record credit advance payment
        try {
          if (_creditPaymentMethod == PaymentMethod.cash) {
            await appState.addCashBookEntry(CashBookEntry(
              type: TransactionType.cashIn,
              amount: _creditPaidAmount,
              description: 'Credit Advance (CASH) - $billNumber',
              reference: billNumber,
              category: 'Sales',
            ));
          } else {
            final bankId = appState.bankAccounts.isNotEmpty ? appState.bankAccounts.first.id : null;
            await appState.addCashBookEntry(CashBookEntry(
              type: TransactionType.bankIn,
              amount: _creditPaidAmount,
              description: 'Credit Advance (${_creditPaymentMethod.name.toUpperCase()}) - $billNumber',
              reference: billNumber,
              bankAccountId: bankId,
              category: 'Sales',
            ));
          }
        } catch (e) {
          debugPrint('Credit advance entry error: $e');
        }
      } else if (_paymentMethod != PaymentMethod.credit && _totalAmount > 0) {
        try {
          if (_paymentMethod == PaymentMethod.cash) {
            await appState.addCashBookEntry(CashBookEntry(
              type: TransactionType.cashIn,
              amount: _totalAmount,
              description: 'Sales - $billNumber',
              reference: billNumber,
              category: 'Sales',
            ));
          } else {
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
        } catch (e) {
          debugPrint('Cash/Bank book entry error: $e');
        }
      }

      if (mounted) {
        setState(() { _cart.clear(); _selectedCustomer = null; _paymentMethod = PaymentMethod.cash;
          _isPartial = false; _partialAmount1Ctrl.text = '';
          _creditPaidAmount = 0; _creditPaymentMethod = PaymentMethod.cash;
          _discountCtrl.text = '0'; _walkInNameCtrl.clear(); _walkInPhoneCtrl.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text('Bill $billNumber created!')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

        // Offer to print invoice with paper size selection
        final settings = await appState.getAllSettings();
        String selectedSize = settings['pdf_paper_size'] ?? 'a4';

        if (!mounted) return;
        final action = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.print, color: AppColors.primary), SizedBox(width: 10), Text('Print Invoice?')]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Bill $billNumber created successfully.\nWould you like to print/share the invoice?'),
              const SizedBox(height: 16),
              // Paper size toggle
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.description, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Paper Size: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
              TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('Skip')),
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
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

        if (action != null && action != 'skip' && mounted) {
          final s = await appState.getAllSettings();
          final template = _parseTemplate(s['pdf_template']);
          final paperSize = selectedSize == 'a5' ? PaperSize.a5 : PaperSize.a4;
          final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
          final tyMsg = s['pdf_thank_you_message'];
          final tc = s['pdf_terms_conditions'];
          if (action == 'preview') {
            if (!mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _BillPreviewPage(
                bill: bill,
                businessName: s['businessName'] ?? 'My Billu',
                businessAddress: s['businessAddress'] ?? '',
                businessPhone: s['businessPhone'] ?? '',
                businessGstin: s['businessGstin'] ?? '',
                businessBankName: s['businessBankName'] ?? '',
                businessBankAccount: s['businessBankAccount'] ?? '',
                businessBankIfsc: s['businessBankIfsc'] ?? '',
                logoBytes: logoBytes,
                template: template,
                paperSize: paperSize,
                thankYouMessage: tyMsg,
                termsConditions: tc,
              ),
            ));
          } else if (action == 'print') {
            await InvoiceGenerator.generateAndPrint(bill,
              businessName: s['businessName'] ?? 'My Billu',
              businessAddress: s['businessAddress'] ?? '',
              businessPhone: s['businessPhone'] ?? '',
              businessGstin: s['businessGstin'] ?? '',
              businessBankName: s['businessBankName'] ?? '',
              businessBankAccount: s['businessBankAccount'] ?? '',
              businessBankIfsc: s['businessBankIfsc'] ?? '',
              logoBytes: logoBytes,
              template: template, paperSize: paperSize,
              thankYouMessage: tyMsg, termsConditions: tc,
            );
          } else if (action == 'share') {
            await InvoiceGenerator.shareInvoice(bill,
              businessName: s['businessName'] ?? 'My Billu',
              businessAddress: s['businessAddress'] ?? '',
              businessPhone: s['businessPhone'] ?? '',
              businessGstin: s['businessGstin'] ?? '',
              businessBankName: s['businessBankName'] ?? '',
              businessBankAccount: s['businessBankAccount'] ?? '',
              businessBankIfsc: s['businessBankIfsc'] ?? '',
              logoBytes: logoBytes,
              template: template, paperSize: paperSize,
              thankYouMessage: tyMsg, termsConditions: tc,
            );
          } else if (action == 'save') {
            try {
              final savedPath = await InvoiceGenerator.savePdfToFile(bill,
                businessName: s['businessName'] ?? 'My Billu',
                businessAddress: s['businessAddress'] ?? '',
                businessPhone: s['businessPhone'] ?? '',
                businessGstin: s['businessGstin'] ?? '',
                businessBankName: s['businessBankName'] ?? '',
                businessBankAccount: s['businessBankAccount'] ?? '',
                businessBankIfsc: s['businessBankIfsc'] ?? '',
                logoBytes: logoBytes,
                template: template, paperSize: paperSize,
                thankYouMessage: tyMsg, termsConditions: tc,
                savePath: s['pdf_save_path'],
              );
              if (mounted) {
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Save error: $e'), backgroundColor: AppColors.error));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Create bill error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error creating bill: $e'),
          backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
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
class _BarcodeScannerPage extends StatefulWidget {
  final void Function(String code) onScanned;
  const _BarcodeScannerPage({required this.onScanned});
  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
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
        // Scan overlay
        Center(child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
        )),
        // Hint text
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


// ========== BILL PREVIEW PAGE ==========

class _BillPreviewPage extends StatefulWidget {
  final Bill bill;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String businessGstin;
  final String businessBankName;
  final String businessBankAccount;
  final String businessBankIfsc;
  final Uint8List? logoBytes;
  final InvoiceTemplate template;
  final PaperSize paperSize;
  final String? thankYouMessage;
  final String? termsConditions;

  const _BillPreviewPage({
    required this.bill,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.businessGstin,
    required this.businessBankName,
    required this.businessBankAccount,
    required this.businessBankIfsc,
    this.logoBytes,
    required this.template,
    required this.paperSize,
    this.thankYouMessage,
    this.termsConditions,
  });

  @override
  State<_BillPreviewPage> createState() => _BillPreviewPageState();
}

class _BillPreviewPageState extends State<_BillPreviewPage> {
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
      logoBytes: widget.logoBytes,
      template: widget.template,
      paperSize: widget.paperSize,
      thankYouMessage: widget.thankYouMessage,
      termsConditions: widget.termsConditions,
    );
    if (mounted) setState(() { _pdfBytes = bytes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice ${widget.bill.billNumber}'),
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
                  logoBytes: widget.logoBytes,
                  template: widget.template,
                  paperSize: widget.paperSize,
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
                  pdfFileName: 'Invoice_${widget.bill.billNumber}.pdf',
                )
              : const Center(child: Text('Error generating preview')),
    );
  }
}
