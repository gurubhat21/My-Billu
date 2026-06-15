import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/models/item.dart';
import '../../core/models/purchase.dart';
import '../../core/models/supplier.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
        child: TabBar(controller: _tabCtrl, tabs: const [
          Tab(icon: Icon(Icons.add_shopping_cart), text: 'New Purchase'),
          Tab(icon: Icon(Icons.history), text: 'Purchase History'),
        ], indicatorColor: AppColors.primary, labelColor: AppColors.primary),
      ),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [
        _NewPurchaseTab(onSaved: () => _tabCtrl.animateTo(1)),
        const _PurchaseHistoryTab(),
      ])),
    ]);
  }
}

// ========== NEW PURCHASE TAB ==========

class _NewPurchaseTab extends StatefulWidget {
  final VoidCallback onSaved;
  const _NewPurchaseTab({required this.onSaved});
  @override
  State<_NewPurchaseTab> createState() => _NewPurchaseTabState();
}

class _NewPurchaseTabState extends State<_NewPurchaseTab> {
  final _supplierCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_CartEntry> _cart = [];
  Item? _selectedItem;
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  bool _showDescription = false;
  bool _showSerialNumber = false;
  bool _gstInclusive = false;
  DateTime _purchaseDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadColumnSettings();
  }

  Future<void> _loadColumnSettings() async {
    final appState = context.read<AppState>();
    final desc = await appState.getSetting('billing_show_description');
    final serial = await appState.getSetting('billing_show_serial_number');
    final gst = await appState.getSetting('billing_gst_inclusive');
    if (mounted) {
      setState(() {
        _showDescription = desc == 'true';
        _showSerialNumber = serial == 'true';
        _gstInclusive = gst == 'true';
      });
    }
  }

  double get _subtotal {
    if (_gstInclusive) {
      return _cart.fold(0, (sum, e) => sum + (e.costPrice * e.qty / (1 + e.item.taxRate / 100)));
    }
    return _cart.fold(0, (sum, e) => sum + e.subtotal);
  }
  double get _totalTax {
    if (_gstInclusive) {
      return _cart.fold(0, (sum, e) {
        final inclTotal = e.costPrice * e.qty;
        return sum + (inclTotal - inclTotal / (1 + e.item.taxRate / 100));
      });
    }
    return _cart.fold(0, (sum, e) => sum + e.taxAmount);
  }
  double get _total => _subtotal + _totalTax;

  /// Find last purchase cost for a given item from purchase history
  double? _getLastPurchaseCost(AppState appState, String itemId) {
    for (final purchase in appState.purchases) {
      for (final pi in purchase.items) {
        if (pi.itemId == itemId) return pi.unitCost;
      }
    }
    return null;
  }

  Widget _buildSupplierAutocomplete(AppState appState) {
    // Combine suppliers from Supplier list + unique names from past purchases
    final supplierNames = <String>{};
    for (final s in appState.suppliers) { supplierNames.add(s.name); }
    for (final p in appState.purchases) { supplierNames.add(p.supplierName); }
    final allNames = supplierNames.toList()..sort();

    return Autocomplete<String>(
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return allNames;
        final q = textValue.text.toLowerCase();
        return allNames.where((n) => n.toLowerCase().contains(q));
      },
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
        // Sync controller text with _supplierCtrl
        ctrl.text = _supplierCtrl.text;
        ctrl.addListener(() {
          if (_supplierCtrl.text != ctrl.text) _supplierCtrl.text = ctrl.text;
        });
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Supplier Name *',
            prefixIcon: Icon(Icons.business),
            suffixIcon: Icon(Icons.search, size: 18)),
        );
      },
      onSelected: (name) {
        FocusScope.of(context).unfocus();
        _supplierCtrl.text = name;
        // Auto-fill phone from supplier list
        final supplier = appState.suppliers.cast<Supplier?>().firstWhere(
          (s) => s!.name.toLowerCase() == name.toLowerCase(), orElse: () => null);
        if (supplier != null) {
          if (supplier.phone != null && supplier.phone!.isNotEmpty) {
            _supplierPhoneCtrl.text = supplier.phone!;
          }
        } else {
          // Try from past purchases
          final pastPurchase = appState.purchases.cast<Purchase?>().firstWhere(
            (p) => p!.supplierName.toLowerCase() == name.toLowerCase(), orElse: () => null);
          if (pastPurchase != null && pastPurchase.supplierPhone != null) {
            _supplierPhoneCtrl.text = pastPurchase.supplierPhone!;
          }
        }
        setState(() {});
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1E1E2E) : Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 350),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final name = options.elementAt(i);
                  final supplier = appState.suppliers.cast<Supplier?>().firstWhere(
                    (s) => s!.name == name, orElse: () => null);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      child: Text(name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.accent))),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: supplier?.phone != null
                        ? Text(supplier!.phone!, style: const TextStyle(fontSize: 11))
                        : null,
                    onTap: () => onSelected(name),
                  );
                }),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Purchase Entry', style: Theme.of(context).textTheme.headlineLarge),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: _purchaseDate,
                      firstDate: DateTime(2020), lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _purchaseDate = picked);
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
                      Text('Date: ${DateFormat('dd MMM yyyy').format(_purchaseDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Supplier Info
            GlassCard(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Supplier Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                if (isWide) Row(children: [
                  Expanded(child: _buildSupplierAutocomplete(appState)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _supplierPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _invoiceCtrl,
                    decoration: const InputDecoration(labelText: 'Invoice #', prefixIcon: Icon(Icons.receipt)))),
                ]) else ...[
                  _buildSupplierAutocomplete(appState),
                  const SizedBox(height: 12),
                  TextField(controller: _supplierPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    child: Autocomplete<Item>(
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
                      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                        return TextField(
                          controller: ctrl, focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Search Item',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _selectedItem != null
                              ? IconButton(icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () { ctrl.clear(); setState(() => _selectedItem = null); })
                              : null,
                          ),
                        );
                      },
                      onSelected: (item) {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _selectedItem = item;
                          _costCtrl.text = item.purchasePrice.toStringAsFixed(2);
                        });
                      },
                      optionsViewBuilder: (ctx, onSelected, options) {
                        return Align(alignment: Alignment.topLeft, child: Material(
                          elevation: 8, borderRadius: BorderRadius.circular(12),
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? const Color(0xFF1E1E2E) : Colors.white,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true, itemCount: options.length,
                              itemBuilder: (ctx, i) {
                                final item = options.elementAt(i);
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(radius: 16,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: Text(item.name[0].toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))),
                                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text('₹${item.purchasePrice.toStringAsFixed(2)} · ${item.unit} · Stock: ${item.stockQuantity}',
                                    style: const TextStyle(fontSize: 11)),
                                  onTap: () => onSelected(item),
                                );
                              }),
                          ),
                        ));
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
                // Show last purchase price when item is selected
                if (_selectedItem != null) ...[
                  const SizedBox(height: 10),
                  Builder(builder: (_) {
                    final lastCost = _getLastPurchaseCost(appState, _selectedItem!.id);
                    if (lastCost == null) {
                      return Text('ℹ️ First time purchasing this item',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)));
                    }
                    final currentCost = double.tryParse(_costCtrl.text) ?? _selectedItem!.price;
                    final diff = currentCost - lastCost;
                    final pct = lastCost > 0 ? (diff / lastCost * 100) : 0.0;
                    final color = diff > 0 ? AppColors.error : diff < 0 ? AppColors.success : AppColors.accent;
                    final icon = diff > 0 ? Icons.trending_up : diff < 0 ? Icons.trending_down : Icons.trending_flat;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Text('Last: ${AppFormatters.currency(lastCost)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                        const SizedBox(width: 8),
                        Text('|', style: TextStyle(color: color.withValues(alpha: 0.4))),
                        const SizedBox(width: 8),
                        Text(
                          diff == 0 ? 'No change'
                            : '${diff > 0 ? '+' : ''}${AppFormatters.currency(diff)} (${pct.toStringAsFixed(1)}%)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                        ),
                      ]),
                    );
                  }),
                ],
              ])),
            const SizedBox(height: 16),

            // Cart with price comparison
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
                  final lastCost = _getLastPurchaseCost(appState, e.item.id);
                  final diff = lastCost != null ? e.costPrice - lastCost : null;

                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            GestureDetector(
                              onTap: () {
                                final ctrl = TextEditingController(text: e.costPrice.toStringAsFixed(2));
                                showDialog(context: context, builder: (ctx2) => AlertDialog(
                                  title: const Text('Edit Price', style: TextStyle(fontSize: 16)),
                                  content: TextField(
                                    controller: ctrl, autofocus: true,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Cost Price'),
                                    onSubmitted: (_) {
                                      final p = double.tryParse(ctrl.text);
                                      if (p != null && p >= 0) setState(() => _cart[i] = _CartEntry(item: e.item, qty: e.qty, costPrice: p, description: e.description, serialNumbers: e.serialNumbers));
                                      Navigator.pop(ctx2);
                                    },
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () {
                                      final p = double.tryParse(ctrl.text);
                                      if (p != null && p >= 0) setState(() => _cart[i] = _CartEntry(item: e.item, qty: e.qty, costPrice: p, description: e.description, serialNumbers: e.serialNumbers));
                                      Navigator.pop(ctx2);
                                    }, child: const Text('Save')),
                                  ],
                                ));
                              },
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('${AppFormatters.currency(e.costPrice)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(width: 2),
                                Icon(Icons.edit, size: 10, color: Colors.white.withValues(alpha: 0.25)),
                              ]),
                            ),
                            const SizedBox(height: 2),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              GestureDetector(
                                onTap: () {
                                  final ctrl = TextEditingController(text: e.qty.toString());
                                  showDialog(context: context, builder: (ctx2) => AlertDialog(
                                    title: const Text('Edit Quantity', style: TextStyle(fontSize: 16)),
                                    content: TextField(
                                      controller: ctrl, autofocus: true,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Quantity'),
                                      onSubmitted: (_) {
                                        final q = int.tryParse(ctrl.text);
                                        if (q != null && q > 0) setState(() => _cart[i] = _CartEntry(item: e.item, qty: q, costPrice: e.costPrice, description: e.description, serialNumbers: e.serialNumbers));
                                        Navigator.pop(ctx2);
                                      },
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () {
                                        final q = int.tryParse(ctrl.text);
                                        if (q != null && q > 0) setState(() => _cart[i] = _CartEntry(item: e.item, qty: q, costPrice: e.costPrice, description: e.description, serialNumbers: e.serialNumbers));
                                        Navigator.pop(ctx2);
                                      }, child: const Text('Save')),
                                    ],
                                  ));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('Qty: ${e.qty}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    const SizedBox(width: 2),
                                    Icon(Icons.edit, size: 10, color: AppColors.primary.withValues(alpha: 0.5)),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('+ ${e.item.taxRate}% GST', style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ])),
                          Text(AppFormatters.currency(e.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                            onPressed: () => setState(() => _cart.removeAt(i))),
                        ]),
                        // Price difference badge
                        if (diff != null && diff != 0)
                          Padding(padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (diff > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(diff > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12,
                                  color: diff > 0 ? AppColors.error : AppColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  '${diff > 0 ? '+' : ''}${AppFormatters.currency(diff)} from last (${AppFormatters.currency(lastCost!)})',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: diff > 0 ? AppColors.error : AppColors.success),
                                ),
                              ]),
                            )),
                        // Optional description field
                        if (_showDescription)
                          Padding(padding: const EdgeInsets.only(top: 6),
                            child: TextFormField(
                              key: ValueKey('pdesc_${e.item.id}'),
                              initialValue: e.description,
                              onChanged: (v) => e.description = v,
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
                          ...List.generate(e.serialNumbers.length, (si) {
                            final focusKey = 'pserial_${e.item.id}_${si}_${e.serialNumbers.length}';
                            return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Builder(builder: (fieldContext) {
                              final focusNode = FocusNode();
                              // Auto-focus the last empty field (newly added)
                              if (si == e.serialNumbers.length - 1 && e.serialNumbers[si].isEmpty && e.serialNumbers.length > 1) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (fieldContext.mounted) focusNode.requestFocus();
                                });
                              }
                              return TextFormField(
                              key: ValueKey(focusKey),
                              initialValue: e.serialNumbers[si],
                              focusNode: focusNode,
                              onChanged: (v) => e.serialNumbers[si] = v,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setState(() {
                                    e.serialNumbers.add('');
                                  });
                                }
                              },
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: e.serialNumbers.length > 1
                                    ? 'Serial #${si + 1}...'
                                    : 'Serial number... (Enter to add next)',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.qr_code, size: 16),
                                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (e.serialNumbers.length > 1)
                                    IconButton(
                                      icon: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => e.serialNumbers.removeAt(si)),
                                    ),
                                  if (!kIsWeb)
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt, size: 18, color: AppColors.primary),
                                      tooltip: 'Scan barcode/QR',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _scanBarcode(context, (code) {
                                        setState(() {
                                          e.serialNumbers[si] = code;
                                          e.serialNumbers.add('');
                                        });
                                      }),
                                    ),
                                ]),
                              ),
                            );}));
                          }),
                      ]),
                    ));
                }),
                const Divider(),
                // GST Inclusive/Exclusive toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
                  child: Row(children: [
                    Icon(Icons.receipt_long, size: 16, color: _gstInclusive ? Colors.greenAccent : Colors.cyanAccent),
                    const SizedBox(width: 8),
                    Text(_gstInclusive ? 'GST Inclusive' : 'GST Exclusive',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _gstInclusive ? Colors.greenAccent : Colors.cyanAccent)),
                    const Spacer(),
                    SizedBox(height: 24, child: Switch(
                      value: _gstInclusive,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) async {
                        setState(() => _gstInclusive = v);
                        final appState = context.read<AppState>();
                        await appState.saveSetting('billing_gst_inclusive', v.toString());
                      },
                    )),
                  ]),
                ),
                _totalRow('Subtotal', AppFormatters.currency(_subtotal)),
                _totalRow('GST', AppFormatters.currency(_totalTax)),
                _totalRow('Total', AppFormatters.currency(_total), bold: true),
              ])),
              const SizedBox(height: 16),

              TextField(controller: _notesCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes))),
              const SizedBox(height: 20),

              SizedBox(width: double.infinity, height: 52,
                child: Row(children: [
                  Expanded(child: SizedBox(height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('Clear Cart?'),
                          content: Text('Remove all ${_cart.length} items?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _cart.clear());
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
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: SizedBox(height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => _savePurchase(context, appState),
                      icon: const Icon(Icons.save, size: 22),
                      label: const Text('Save Purchase & Update Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ))),
                ])),
            ],
          ]),
        );
      });
    });
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 18 : 14)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 18 : 14, color: bold ? AppColors.primary : null)),
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

  void _scanBarcode(BuildContext context, void Function(String code) onScanned) {
    if (kIsWeb) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => _PurchaseBarcodeScannerPage(onScanned: (code) {
        Navigator.of(ctx).pop();
        onScanned(code);
      }),
    ));
  }

  Future<void> _savePurchase(BuildContext context, AppState appState) async {
    if (_supplierCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier name is required')));
      return;
    }
    if (_cart.isEmpty) return;
    try {
      final poNumber = await appState.getNextPurchaseNumber();
      final purchaseItems = _cart.map((e) {
        final serials = e.serialNumbers.where((s) => s.isNotEmpty).toList();
        return PurchaseItem(
          itemId: e.item.id, itemName: e.item.name,
          unitCost: e.costPrice, quantity: e.qty,
          taxRate: e.item.taxRate, unit: e.item.unit,
          description: e.description.isNotEmpty ? e.description : null,
          serialNumber: serials.isNotEmpty ? serials.join(', ') : null,
        );
      }).toList();
      final purchase = Purchase(
        purchaseNumber: poNumber,
        supplierName: _supplierCtrl.text.trim(),
        supplierPhone: _supplierPhoneCtrl.text.trim().isEmpty ? null : _supplierPhoneCtrl.text.trim(),
        invoiceNumber: _invoiceCtrl.text.trim().isEmpty ? null : _invoiceCtrl.text.trim(),
        items: purchaseItems,
        subtotal: _subtotal, totalTax: _totalTax, totalAmount: _total,
        paidAmount: 0, status: PurchaseStatus.pending,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: _purchaseDate,
      );
      await appState.createPurchase(purchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
            Text('Purchase $poNumber saved! Stock updated.'),
          ]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        setState(() { _cart.clear(); _supplierCtrl.clear(); _supplierPhoneCtrl.clear(); _invoiceCtrl.clear(); _notesCtrl.clear(); _purchaseDate = DateTime.now(); });
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

// ========== PURCHASE HISTORY TAB ==========

class _PurchaseHistoryTab extends StatelessWidget {
  const _PurchaseHistoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final purchases = appState.purchases;
      if (purchases.isEmpty) {
        return const EmptyState(icon: Icons.shopping_bag_outlined, title: 'No purchases yet', subtitle: 'Your purchase history will appear here');
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: purchases.length,
        itemBuilder: (ctx, i) => _purchaseTile(context, purchases[i], appState),
      );
    });
  }

  Widget _purchaseTile(BuildContext context, Purchase purchase, AppState appState) {
    final statusColor = purchase.status == PurchaseStatus.received ? AppColors.success
        : purchase.status == PurchaseStatus.pending ? AppColors.warning : AppColors.error;

    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => _showPurchaseDetail(context, purchase, appState),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          // PO icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Icon(Icons.shopping_bag, color: AppColors.accent, size: 22)),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(purchase.purchaseNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(purchase.status.name.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(purchase.supplierName, style: Theme.of(context).textTheme.bodySmall),
            Text('${purchase.items.length} items · ${AppFormatters.date(purchase.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall),
          ])),
          // Total
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.currency(purchase.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
            if (purchase.invoiceNumber != null && purchase.invoiceNumber!.isNotEmpty)
              Text('Inv: ${purchase.invoiceNumber}', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      ));
  }

  void _showPurchaseDetail(BuildContext context, Purchase purchase, AppState appState) {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.shopping_bag, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(purchase.purchaseNumber)),
      ]),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _detailRow('Supplier', purchase.supplierName),
          if (purchase.supplierPhone != null) _detailRow('Phone', purchase.supplierPhone!),
          if (purchase.invoiceNumber != null) _detailRow('Invoice #', purchase.invoiceNumber!),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx, initialDate: purchase.createdAt,
                firstDate: DateTime(2020), lastDate: DateTime(2030),
              );
              if (picked != null) {
                purchase.createdAt = DateTime(picked.year, picked.month, picked.day, purchase.createdAt.hour, purchase.createdAt.minute);
                await appState.updatePurchase(purchase);
                setDialogState(() {});
              }
            },
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Text('Date: ', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                Text(AppFormatters.dateTime(purchase.createdAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 6),
                Icon(Icons.edit_calendar, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
              ]),
            ),
          ),
          _detailRow('Status', purchase.status.name.toUpperCase()),
          if (purchase.notes != null && purchase.notes!.isNotEmpty) _detailRow('Notes', purchase.notes!),
          const Divider(height: 20),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...purchase.items.map((item) {
            // Find current item price for comparison
            final currentItem = appState.items.where((i) => i.id == item.itemId);
            final currentPrice = currentItem.isNotEmpty ? currentItem.first.price : null;

            return Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Text(AppFormatters.currency(item.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${item.quantity} ${item.unit} × ${AppFormatters.currency(item.unitCost)} + ${item.taxRate}% GST',
                    style: Theme.of(context).textTheme.bodySmall),
                  // Show price comparison with current selling price
                  if (currentPrice != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('Purchase: ${AppFormatters.currency(item.unitCost)}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(width: 8),
                      Text('→', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                      const SizedBox(width: 8),
                      Text('Selling: ${AppFormatters.currency(currentPrice)}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (currentPrice > item.unitCost ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Margin: ${((currentPrice - item.unitCost) / item.unitCost * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: currentPrice > item.unitCost ? AppColors.success : AppColors.error),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ));
          }),
          const Divider(height: 20),
          _detailRow('Subtotal', AppFormatters.currency(purchase.subtotal)),
          _detailRow('GST', AppFormatters.currency(purchase.totalTax)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(AppFormatters.currency(purchase.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
          ]),
        ]))),
      actions: [
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('Delete Purchase?'),
            content: const Text('This will reverse stock changes and reduce item quantities.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Delete')),
            ],
          ));
          if (confirm == true) await appState.deletePurchase(purchase.id);
        }, child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            _showEditPurchase(context, purchase, appState);
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit'),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    )));
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]));
  }

  void _showEditPurchase(BuildContext context, Purchase purchase, AppState appState) {
    // Build editable items list from purchase
    final editItems = purchase.items.map((item) => <String, dynamic>{
      'itemId': item.itemId, 'itemName': item.itemName, 'unitCost': item.unitCost,
      'quantity': item.quantity, 'taxRate': item.taxRate, 'unit': item.unit,
      'description': item.description, 'serialNumber': item.serialNumber,
    }).toList();

    final supplierCtrl = TextEditingController(text: purchase.supplierName);
    final phoneCtrl = TextEditingController(text: purchase.supplierPhone ?? '');
    final invoiceCtrl = TextEditingController(text: purchase.invoiceNumber ?? '');
    final notesCtrl = TextEditingController(text: purchase.notes ?? '');
    final paidCtrl = TextEditingController(text: purchase.paidAmount.toStringAsFixed(2));

    // Create persistent controllers for each item
    final itemCtrls = <Map<String, TextEditingController>>[];
    for (final item in editItems) {
      itemCtrls.add({
        'cost': TextEditingController(text: (item['unitCost'] as double).toStringAsFixed(2)),
        'qty': TextEditingController(text: (item['quantity'] as int).toString()),
        'tax': TextEditingController(text: (item['taxRate'] as double).toStringAsFixed(1)),
      });
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setEditState) {
      // Recalculate totals
      double subtotal = 0, totalTax = 0;
      for (final item in editItems) {
        final cost = (item['unitCost'] as double) * (item['quantity'] as int);
        subtotal += cost;
        totalTax += cost * (item['taxRate'] as double) / 100;
      }
      final totalAmount = subtotal + totalTax;
      final paid = double.tryParse(paidCtrl.text) ?? 0;

      return AlertDialog(
        title: Row(children: [
          const Icon(Icons.edit, color: AppColors.accent), const SizedBox(width: 10),
          Text('Edit ${purchase.purchaseNumber}'),
        ]),
        content: SizedBox(width: 550, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Supplier details
            TextField(controller: supplierCtrl,
              decoration: const InputDecoration(labelText: 'Supplier Name *', prefixIcon: Icon(Icons.business), isDense: true)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone), isDense: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: invoiceCtrl,
                decoration: const InputDecoration(labelText: 'Invoice #', prefixIcon: Icon(Icons.receipt), isDense: true))),
            ]),
            const SizedBox(height: 14),

            // Items header + Add button
            Row(children: [
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddPurchaseItem(ctx, appState, editItems, itemCtrls, setEditState),
                icon: const Icon(Icons.add, size: 16), label: const Text('Add Item', style: TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 6),

            // Editable items
            ...editItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final ctrls = itemCtrls[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.15))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(item['itemName'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      onPressed: () => setEditState(() {
                        editItems.removeAt(i);
                        itemCtrls[i]['cost']!.dispose();
                        itemCtrls[i]['qty']!.dispose();
                        itemCtrls[i]['tax']!.dispose();
                        itemCtrls.removeAt(i);
                      })),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: ctrls['cost'],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost ₹', isDense: true),
                      onChanged: (v) => setEditState(() {
                        item['unitCost'] = double.tryParse(v) ?? item['unitCost'];
                      }))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: ctrls['qty'],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                      onChanged: (v) => setEditState(() {
                        item['quantity'] = int.tryParse(v) ?? item['quantity'];
                      }))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: ctrls['tax'],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tax %', isDense: true),
                      onChanged: (v) => setEditState(() {
                        item['taxRate'] = double.tryParse(v) ?? item['taxRate'];
                      }))),
                  ]),
                ]),
              );
            }),

            const Divider(),
            // Totals
            _detailRow('Subtotal', AppFormatters.currency(subtotal)),
            _detailRow('GST', AppFormatters.currency(totalTax)),
            Padding(padding: const EdgeInsets.only(bottom: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(AppFormatters.currency(totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
              ])),
            const SizedBox(height: 8),
            TextField(controller: paidCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Paid Amount', prefixIcon: Icon(Icons.payments), isDense: true),
              onChanged: (_) => setEditState(() {})),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes), isDense: true)),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: editItems.isEmpty ? null : () async {
              Navigator.pop(ctx);
              final updatedItems = editItems.map((item) => PurchaseItem(
                itemId: item['itemId'] as String, itemName: item['itemName'] as String,
                unitCost: item['unitCost'] as double, quantity: item['quantity'] as int,
                taxRate: item['taxRate'] as double, unit: (item['unit'] as String?) ?? 'pcs',
                description: item['description'] as String?,
                serialNumber: item['serialNumber'] as String?,
              )).toList();
              final updatedPurchase = Purchase(
                id: purchase.id,
                purchaseNumber: purchase.purchaseNumber,
                supplierName: supplierCtrl.text.trim(),
                supplierPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                supplierGstin: purchase.supplierGstin,
                invoiceNumber: invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                items: updatedItems,
                subtotal: subtotal, totalTax: totalTax, totalAmount: totalAmount,
                paidAmount: paid,
                status: purchase.status,
                paymentMethod: purchase.paymentMethod,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                createdAt: purchase.createdAt,
              );
              await appState.updatePurchase(updatedPurchase);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                    Text('${purchase.purchaseNumber} updated — ${updatedItems.length} items, ${AppFormatters.currency(totalAmount)}'),
                  ]),
                  backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Changes'),
          ),
        ],
      );
    }));
  }

  void _showAddPurchaseItem(BuildContext ctx, AppState appState,
      List<Map<String, dynamic>> editItems, List<Map<String, TextEditingController>> itemCtrls,
      StateSetter setEditState) {
    String search = '';
    showDialog(context: ctx, builder: (dCtx) => StatefulBuilder(builder: (dCtx, setAddState) {
      final filtered = search.isEmpty ? appState.items
          : appState.items.where((i) => i.name.toLowerCase().contains(search.toLowerCase())).toList();
      return AlertDialog(
        title: const Row(children: [
          Icon(Icons.add_shopping_cart, color: AppColors.accent), SizedBox(width: 10), Text('Add Item')]),
        content: SizedBox(width: 400, height: 350, child: Column(children: [
          TextField(
            decoration: const InputDecoration(hintText: 'Search items...', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setAddState(() => search = v)),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final item = filtered[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2, size: 20, color: AppColors.accent),
                title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('₹${item.purchasePrice.toStringAsFixed(2)} • Tax: ${item.taxRate}%', style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.add_circle, color: AppColors.success),
                onTap: () {
                  Navigator.pop(dCtx);
                  setEditState(() {
                    editItems.add({
                      'itemId': item.id, 'itemName': item.name, 'unitCost': item.purchasePrice,
                      'quantity': 1, 'taxRate': item.taxRate, 'unit': item.unit,
                      'description': item.description, 'serialNumber': null,
                    });
                    itemCtrls.add({
                      'cost': TextEditingController(text: item.purchasePrice.toStringAsFixed(2)),
                      'qty': TextEditingController(text: '1'),
                      'tax': TextEditingController(text: item.taxRate.toStringAsFixed(1)),
                    });
                  });
                },
              );
            },
          )),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel'))],
      );
    }));
  }
}

class _CartEntry {
  final Item item;
  final int qty;
  final double costPrice;
  String description;
  List<String> serialNumbers;
  _CartEntry({required this.item, required this.qty, required this.costPrice, this.description = '', List<String>? serialNumbers})
    : serialNumbers = serialNumbers ?? [''];
  double get subtotal => costPrice * qty;
  double get taxAmount => subtotal * item.taxRate / 100;
  double get total => subtotal + taxAmount;
}

// ===== Barcode Scanner Page (Android/iOS only) =====
class _PurchaseBarcodeScannerPage extends StatefulWidget {
  final void Function(String code) onScanned;
  const _PurchaseBarcodeScannerPage({required this.onScanned});
  @override
  State<_PurchaseBarcodeScannerPage> createState() => _PurchaseBarcodeScannerPageState();
}

class _PurchaseBarcodeScannerPageState extends State<_PurchaseBarcodeScannerPage> {
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


