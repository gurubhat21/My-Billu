import 'package:flutter/material.dart';
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
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_CartEntry> _cart = [];
  bool _roundOff = false;
  String _purchaseNumber = '';
  DateTime _purchaseDate = DateTime.now();
  TimeOfDay _purchaseTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadPurchaseNumber();
  }

  Future<void> _loadPurchaseNumber() async {
    final appState = context.read<AppState>();
    final num = await appState.getNextPurchaseNumber();
    if (mounted) setState(() => _purchaseNumber = num);
  }

  double get _subtotal => _cart.fold(0, (s, e) => s + e.costPrice * e.qty);
  double get _totalDiscount => _cart.fold(0, (s, e) => s + e.discount);
  double get _totalTax => _cart.fold(0, (s, e) => s + (e.costPrice * e.qty - e.discount) * e.taxRate / 100);
  double get _rawTotal => (_subtotal - _totalDiscount + _totalTax).clamp(0, double.infinity);
  double get _roundOffAmount => _roundOff ? (_rawTotal.roundToDouble() - _rawTotal) : 0;
  double get _total => _rawTotal + _roundOffAmount;

  double? _getLastPurchaseCost(AppState appState, String itemId) {
    for (final p in appState.purchases) {
      for (final pi in p.items) { if (pi.itemId == itemId) return pi.unitCost; }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF5F7FA),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // === TOP BAR ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Row(children: [
                Text('Purchase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
              ]),
            ),
            const SizedBox(height: 12),

            // === SUPPLIER + PURCHASE INFO ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: Column(children: [
                  Row(children: [
                    Expanded(child: _buildSupplierAutocomplete(appState)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _supplierPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDeco('Phone No.', Icons.phone_outlined))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: _addressCtrl, maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: _fieldDeco('Supplier Address', Icons.location_on_outlined)),
                ])),
                const SizedBox(width: 24),
                SizedBox(width: 220, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _metaRow('Purchase #', _purchaseNumber),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Spacer(),
                    SizedBox(width: 140, child: TextField(controller: _invoiceCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(labelText: 'Invoice #', isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                  ]),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _purchaseDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setState(() => _purchaseDate = d);
                    },
                    child: _metaRow('Date', AppFormatters.date(_purchaseDate), icon: Icons.calendar_today)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _purchaseTime);
                      if (t != null) setState(() => _purchaseTime = t);
                    },
                    child: _metaRow('Time', _purchaseTime.format(context), icon: Icons.access_time)),
                ])),
              ]),
            ),
            const SizedBox(height: 12),

            // === ITEMS TABLE ===
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF1F3F8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    _thCell('#', 30), _thCell('ITEM', 0, flex: 3), _thCell('QTY', 70),
                    _thCell('UNIT', 80), _thCell('COST/UNIT', 90), _thCell('DISCOUNT', 80),
                    _thCell('TAX %', 90), _thCell('TAX AMT', 80), _thCell('AMOUNT', 90),
                    SizedBox(width: 36, child: IconButton(
                      onPressed: () => _showAddItemDialog(context, appState),
                      icon: const Icon(Icons.add_circle, size: 18, color: AppColors.accent),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: 'Add Item')),
                  ]),
                ),
                // Rows
                ..._cart.asMap().entries.map((e) => _buildTableRow(context, appState, e.key, e.value, isDark)),
                // Empty rows with inline autocomplete
                ...List.generate(5, (emptyIdx) => _buildEmptyRow(context, appState, _cart.length + emptyIdx, isDark)),
                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300))),
                  child: Row(children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddItemDialog(context, appState),
                      icon: const Icon(Icons.add, size: 16), label: const Text('ADD ROW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), visualDensity: VisualDensity.compact)),
                    const Spacer(),
                    Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(width: 16),
                    SizedBox(width: 80, child: Text(AppFormatters.currency(_totalDiscount), textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 16),
                    SizedBox(width: 80, child: Text(AppFormatters.currency(_totalTax), textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 16),
                    SizedBox(width: 90, child: Text(AppFormatters.currency(_rawTotal), textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.accent))),
                    const SizedBox(width: 36),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // === BOTTOM ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Row(children: [
                Expanded(flex: 2, child: TextField(controller: _notesCtrl, maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: _fieldDeco('Notes (optional)', Icons.notes_outlined))),
                const SizedBox(width: 16),
                const Spacer(),
                // Round off
                Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(height: 20, width: 20, child: Checkbox(value: _roundOff, activeColor: AppColors.accent,
                    onChanged: (v) => setState(() => _roundOff = v ?? false))),
                  const SizedBox(width: 4),
                  Text('Round Off', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  if (_roundOff) ...[
                    const SizedBox(width: 8),
                    Text(_roundOffAmount >= 0 ? '+${_roundOffAmount.toStringAsFixed(2)}' : _roundOffAmount.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ]),
                const SizedBox(width: 16),
                Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(AppFormatters.currency(_total),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.accent))),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : () => _savePurchase(context, appState),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  // â”€â”€ Helpers â”€â”€

  InputDecoration _fieldDeco(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18),
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));
  }

  Widget _metaRow(String label, String value, {IconData? icon}) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text('$label  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 14, color: AppColors.accent)],
    ]);
  }

  Widget _thCell(String text, double width, {int flex = 0}) {
    final child = Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5), textAlign: TextAlign.center);
    if (flex > 0) return Expanded(flex: flex, child: child);
    return SizedBox(width: width, child: child);
  }

  Widget _buildTableRow(BuildContext context, AppState appState, int index, _CartEntry e, bool isDark) {
    final isMeter = e.item.unit.toLowerCase() == 'mtr' || e.item.unit.toLowerCase() == 'meter';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 30, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text(e.item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 70, child: SizedBox(height: 30, child: TextField(
            key: ValueKey('pqty_${e.item.id}'),
            controller: TextEditingController(text: '${e.qty}'),
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            onChanged: (v) { final q = int.tryParse(v) ?? 0; if (q > 0) setState(() => e.qty = q); },
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ))),
          SizedBox(width: 80, child: SizedBox(height: 30, child: DropdownButtonFormField<String>(
            value: e.item.unit, isDense: true,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            items: ['pcs', 'kg', 'ltr', 'mtr', 'box', 'nos', 'set', 'pair'].map((u) =>
              DropdownMenuItem(value: u, child: Text(u.toUpperCase(), style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: (v) { if (v != null) setState(() => e.item.unit = v); },
          ))),
          SizedBox(width: 90, child: SizedBox(height: 30, child: TextField(
            key: ValueKey('pcost_${e.item.id}'),
            controller: TextEditingController(text: e.costPrice.toStringAsFixed(2)),
            keyboardType: TextInputType.number, textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(isDense: true, prefixText: '₹', prefixStyle: const TextStyle(fontSize: 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            onChanged: (v) { final c = double.tryParse(v) ?? 0; if (c >= 0) setState(() => e.costPrice = c); },
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ))),
          SizedBox(width: 80, child: SizedBox(height: 30, child: TextField(
            key: ValueKey('pdisc_${e.item.id}'),
            keyboardType: TextInputType.number, textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
            controller: TextEditingController(text: e.discount > 0 ? e.discount.toStringAsFixed(0) : ''),
            decoration: InputDecoration(isDense: true, hintText: '0', contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            onChanged: (v) => setState(() => e.discount = double.tryParse(v) ?? 0),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ))),
          SizedBox(width: 90, child: SizedBox(height: 30, child: DropdownButtonFormField<double>(
            value: e.taxRate, isDense: true,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            items: [0, 5, 12, 18, 28].map((r) =>
              DropdownMenuItem(value: r.toDouble(), child: Text(r == 0 ? 'NONE' : 'GST@$r%', style: const TextStyle(fontSize: 10)))).toList(),
            onChanged: (v) { if (v != null) setState(() => e.taxRate = v); },
          ))),
          SizedBox(width: 80, child: Text(AppFormatters.currency((e.costPrice * e.qty - e.discount) * e.taxRate / 100),
            style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
          SizedBox(width: 90, child: Text(AppFormatters.currency(e.costPrice * e.qty - e.discount + (e.costPrice * e.qty - e.discount) * e.taxRate / 100),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
          SizedBox(width: 36, child: IconButton(
            onPressed: () => setState(() => _cart.removeAt(index)),
            icon: Icon(Icons.close, size: 16, color: isDark ? Colors.white24 : Colors.black26),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30))),
        ]),
        // Description + Serial sub-row
        Padding(padding: const EdgeInsets.only(left: 30, top: 4, right: 36),
          child: Row(children: [
            Expanded(child: SizedBox(height: 28, child: TextField(
              key: ValueKey('pdesc_${e.item.id}'),
              controller: TextEditingController(text: e.description),
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(isDense: true, hintText: 'Item description...', hintStyle: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26),
                prefixIcon: const Icon(Icons.description_outlined, size: 14), prefixIconConstraints: const BoxConstraints(minWidth: 28),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
              onChanged: (v) => e.description = v,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ))),
            if (!isMeter) ...[
              const SizedBox(width: 8),
              ...List.generate(e.qty > 3 ? 1 : e.qty, (si) => Expanded(child: Padding(
                padding: EdgeInsets.only(left: si > 0 ? 4 : 0),
                child: SizedBox(height: 28, child: TextField(
                  key: ValueKey('pserial_${e.item.id}_$si'),
                  controller: TextEditingController(text: si < e.serialNumbers.length ? e.serialNumbers[si] : ''),
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(isDense: true,
                    hintText: e.qty > 3 ? 'Serials (comma sep)' : 'S/N ${si + 1}',
                    hintStyle: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26),
                    prefixIcon: const Icon(Icons.qr_code, size: 14), prefixIconConstraints: const BoxConstraints(minWidth: 28),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
                  onChanged: (v) {
                    if (e.qty > 3) {
                      e.serialNumbers = List.filled(e.qty, '');
                      final parts = v.split(',');
                      for (int p = 0; p < parts.length && p < e.qty; p++) e.serialNumbers[p] = parts[p].trim();
                    } else if (si < e.serialNumbers.length) { e.serialNumbers[si] = v; }
                  },
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ))))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildEmptyRow(BuildContext context, AppState appState, int index, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100))),
      child: Row(children: [
        SizedBox(width: 30, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white12 : Colors.black12), textAlign: TextAlign.center)),
        Expanded(flex: 3, child: SizedBox(height: 30, child: Autocomplete<Item>(
          optionsBuilder: (tv) {
            if (tv.text.isEmpty) return const [];
            final q = tv.text.toLowerCase();
            return appState.items.where((i) => i.name.toLowerCase().contains(q)
              || (i.barcode ?? '').contains(q) || (i.hsnCode ?? '').contains(q));
          },
          displayStringForOption: (i) => i.name,
          fieldViewBuilder: (ctx, ctrl, fn, onSubmit) => TextField(
            controller: ctrl, focusNode: fn,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
            decoration: InputDecoration(isDense: true, hintText: 'Type item name / barcode...',
              hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white12 : Colors.black12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100))),
            onSubmitted: (_) => onSubmit(),
          ),
          onSelected: (item) {
            final lastCost = _getLastPurchaseCost(appState, item.id);
            setState(() => _cart.add(_CartEntry(item: item, qty: 1, costPrice: lastCost ?? item.purchasePrice)));
          },
          optionsViewBuilder: (ctx, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(elevation: 8, borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                child: ListView.builder(shrinkWrap: true, padding: EdgeInsets.zero,
                  itemCount: options.length, itemBuilder: (_, i) {
                    final item = options.elementAt(i);
                    final lastCost = _getLastPurchaseCost(appState, item.id);
                    return ListTile(dense: true, visualDensity: VisualDensity.compact,
                      title: Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text('Sale: ${AppFormatters.currency(item.price)} · ${lastCost != null ? "Last: ${AppFormatters.currency(lastCost)}" : "No history"} · ${item.unit}',
                        style: const TextStyle(fontSize: 10)),
                      trailing: Text('₹${(lastCost ?? item.purchasePrice).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      onTap: () => onSelected(item));
                  })))),
        ))),
        SizedBox(width: 70, child: SizedBox(height: 30, child: TextField(enabled: false,
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)))))),
        const SizedBox(width: 80),
        const SizedBox(width: 90),
        const SizedBox(width: 80),
        const SizedBox(width: 90),
        const SizedBox(width: 80),
        const SizedBox(width: 90),
        const SizedBox(width: 36),
      ]),
    );
  }

  void _showAddItemDialog(BuildContext context, AppState appState) {
    String search = '';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
      final items = search.isEmpty ? appState.items
        : appState.items.where((i) => i.name.toLowerCase().contains(search.toLowerCase())
          || (i.barcode ?? '').contains(search) || (i.hsnCode ?? '').contains(search)).toList();
      return AlertDialog(
        title: const Text('Add Item'),
        content: SizedBox(width: 500, height: 400, child: Column(children: [
          TextField(onChanged: (v) => ss(() => search = v),
            decoration: const InputDecoration(hintText: 'Search by name, barcode, HSN...', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (_, i) {
            final item = items[i];
            final lastCost = _getLastPurchaseCost(appState, item.id);
            final inCart = _cart.any((c) => c.item.id == item.id);
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 16, backgroundColor: inCart ? AppColors.success.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.1),
                child: Icon(inCart ? Icons.check : Icons.inventory_2, size: 14, color: inCart ? AppColors.success : AppColors.accent)),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text('Sale: ${AppFormatters.currency(item.price)} Â· ${lastCost != null ? "Last: ${AppFormatters.currency(lastCost)}" : "No history"} Â· ${item.unit}',
                style: const TextStyle(fontSize: 11)),
              trailing: inCart ? Text('In cart', style: TextStyle(fontSize: 10, color: AppColors.success)) : null,
              onTap: () {
                setState(() => _cart.add(_CartEntry(item: item, qty: 1, costPrice: lastCost ?? item.purchasePrice)));
                Navigator.pop(ctx);
              },
            );
          })),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      );
    }));
  }

  Widget _buildSupplierAutocomplete(AppState appState) {
    final supplierNames = <String>{};
    for (final s in appState.suppliers) { supplierNames.add(s.name); }
    for (final p in appState.purchases) { supplierNames.add(p.supplierName); }
    final allNames = supplierNames.toList()..sort();
    return Autocomplete<String>(
      optionsBuilder: (tv) {
        if (tv.text.isEmpty) return allNames;
        final q = tv.text.toLowerCase();
        return allNames.where((n) => n.toLowerCase().contains(q));
      },
      fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
        ctrl.text = _supplierCtrl.text;
        ctrl.addListener(() { if (_supplierCtrl.text != ctrl.text) _supplierCtrl.text = ctrl.text; });
        return TextField(controller: ctrl, focusNode: fn,
          style: const TextStyle(fontSize: 13),
          decoration: _fieldDeco('Supplier Name *', Icons.business));
      },
      onSelected: (name) {
        _supplierCtrl.text = name;
        final supplier = appState.suppliers.cast<Supplier?>().firstWhere((s) => s!.name.toLowerCase() == name.toLowerCase(), orElse: () => null);
        if (supplier?.phone != null && supplier!.phone!.isNotEmpty) _supplierPhoneCtrl.text = supplier.phone!;
        setState(() {});
      },
    );
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
          taxRate: e.taxRate, unit: e.item.unit,
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
        paidAmount: _total, status: PurchaseStatus.received,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await appState.createPurchase(purchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10), Text('Purchase $poNumber saved! Stock updated.')]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        setState(() { _cart.clear(); _supplierCtrl.clear(); _supplierPhoneCtrl.clear(); _invoiceCtrl.clear(); _notesCtrl.clear(); _addressCtrl.clear(); _roundOff = false; });
        _loadPurchaseNumber();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
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
            Text('${purchase.items.length} items Â· ${AppFormatters.date(purchase.createdAt)}',
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
    showDialog(context: context, builder: (ctx) => AlertDialog(
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
          _detailRow('Date', AppFormatters.dateTime(purchase.createdAt)),
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
                  Text('${item.quantity} ${item.unit} Ã— ${AppFormatters.currency(item.unitCost)} + ${item.taxRate}% GST',
                    style: Theme.of(context).textTheme.bodySmall),
                  // Show price comparison with current selling price
                  if (currentPrice != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('Purchase: ${AppFormatters.currency(item.unitCost)}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(width: 8),
                      Text('â†’', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
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
            content: const Text('This will not reverse stock changes.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Delete')),
            ],
          ));
          if (confirm == true) await appState.deletePurchase(purchase.id);
        }, child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ));
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]));
  }
}

class _CartEntry {
  final Item item;
  int qty;
  double costPrice;
  double discount;
  double taxRate;
  String description;
  List<String> serialNumbers;
  _CartEntry({required this.item, required this.qty, required this.costPrice, this.discount = 0, double? taxRate, this.description = '', List<String>? serialNumbers})
    : taxRate = taxRate ?? item.taxRate,
      serialNumbers = serialNumbers ?? List.filled(qty, '');
  double get subtotal => costPrice * qty;
  double get taxAmount => (subtotal - discount) * taxRate / 100;
  double get total => subtotal - discount + taxAmount;
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


