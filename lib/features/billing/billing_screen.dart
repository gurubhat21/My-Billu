import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  double itemDiscount;
  String description;
  List<String> serialNumbers;
  _CartItem({required this.item, required this.quantity, this.itemDiscount = 0, this.description = '', List<String>? serialNumbers})
    : serialNumbers = serialNumbers ?? List.filled(quantity, '');
  double get subtotal => item.price * quantity;
  double get taxAmount => (subtotal - itemDiscount) * item.taxRate / 100;
  double get rowTotal => subtotal - itemDiscount + taxAmount;
  void updateQuantity(int newQty) {
    if (newQty > quantity) {
      serialNumbers.addAll(List.filled(newQty - quantity, ''));
    } else if (newQty < quantity) {
      serialNumbers = serialNumbers.sublist(0, newQty);
    }
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
  final _discountCtrl = TextEditingController(text: '0');
  final _walkInNameCtrl = TextEditingController();
  final _walkInPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _showDescription = false;
  bool _showSerialNumber = false;
  bool _gstInclusive = false;
  bool _roundOff = false;
  String _invoiceNumber = '';
  DateTime _billDate = DateTime.now();
  TimeOfDay _billTime = TimeOfDay.now();

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
    final nextBill = await appState.getNextBillNumber();
    if (mounted) {
      setState(() {
        _showDescription = desc == 'true';
        _showSerialNumber = serial == 'true';
        _gstInclusive = gstMode == 'true';
        _invoiceNumber = nextBill;
      });
    }
  }

  double _itemSubtotal(_CartItem c) {
    if (_gstInclusive) {
      return c.item.price * c.quantity / (1 + c.item.taxRate / 100);
    }
    return c.item.price * c.quantity;
  }

  double _itemTax(_CartItem c) {
    final base = _itemSubtotal(c) - c.itemDiscount;
    if (_gstInclusive) {
      final inclTotal = c.item.price * c.quantity - c.itemDiscount;
      return inclTotal - inclTotal / (1 + c.item.taxRate / 100);
    }
    return base * c.item.taxRate / 100;
  }

  double get _subtotal => _cart.fold(0.0, (s, c) => s + _itemSubtotal(c));
  double get _totalItemDiscount => _cart.fold(0.0, (s, c) => s + c.itemDiscount);
  double get _totalTax => _cart.fold(0.0, (s, c) => s + _itemTax(c));
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _rawTotal => (_subtotal - _totalItemDiscount + _totalTax - _discount).clamp(0, double.infinity);
  double get _roundOffAmount => _roundOff ? (_rawTotal.roundToDouble() - _rawTotal) : 0;
  double get _totalAmount => _rawTotal + _roundOffAmount;



  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF5F7FA),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // === TOP BAR: Sale + toggles ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Row(children: [
                Text('Sale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(width: 16),
                // Credit/Cash toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _toggleChip('Credit', _paymentMethod == PaymentMethod.credit, () => setState(() { _paymentMethod = PaymentMethod.credit; _isPartial = false; }), isDark),
                    _toggleChip('Cash', _paymentMethod == PaymentMethod.cash, () => setState(() { _paymentMethod = PaymentMethod.cash; _isPartial = false; }), isDark),
                  ]),
                ),
                const SizedBox(width: 12),
                // GST toggle
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_gstInclusive ? 'Inclusive' : 'Exclusive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gstInclusive ? AppColors.success : AppColors.primary)),
                  SizedBox(height: 24, child: Switch(value: _gstInclusive, activeColor: AppColors.success, onChanged: (v) async {
                    setState(() => _gstInclusive = v);
                    await appState.saveSetting('billing_gst_inclusive', v.toString());
                  })),
                ]),
                const Spacer(),
                // More payment methods
                Wrap(spacing: 6, children: [PaymentMethod.upi, PaymentMethod.card, PaymentMethod.bank].map((pm) {
                  final sel = !_isPartial && _paymentMethod == pm;
                  return ChoiceChip(label: Text(AppFormatters.paymentMethod(pm.name), style: TextStyle(fontSize: 10, color: sel ? Colors.white : null)),
                    selected: sel, selectedColor: AppColors.primary, visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() { _paymentMethod = pm; _isPartial = false; }));
                }).toList()),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('Partial', style: TextStyle(fontSize: 10)),
                  selected: _isPartial, selectedColor: Colors.orangeAccent, visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: _isPartial ? Colors.white : null, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() { _isPartial = true; _partialAmount1Ctrl.text = ''; })),
              ]),
            ),
            const SizedBox(height: 12),

            // === CUSTOMER + INVOICE INFO ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Left: customer fields
                Expanded(flex: 3, child: Column(children: [
                  Row(children: [
                    Expanded(child: TextField(controller: _walkInNameCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDeco('Billing Name (Optional)', Icons.person_outline),
                      onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _walkInPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13),
                      decoration: _fieldDeco('Phone No.', Icons.phone_outlined),
                      onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => _showCustomerPicker(context, appState),
                      icon: const Icon(Icons.contacts, color: AppColors.primary, size: 20),
                      tooltip: 'Select Customer'),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: _addressCtrl, maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: _fieldDeco('Billing Address', Icons.location_on_outlined)),
                ])),
                const SizedBox(width: 24),
                // Right: invoice metadata
                SizedBox(width: 220, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _metaRow('Invoice Number', _invoiceNumber),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _billDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setState(() => _billDate = d);
                    },
                    child: _metaRow('Invoice Date', AppFormatters.date(_billDate), icon: Icons.calendar_today)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _billTime);
                      if (t != null) setState(() => _billTime = t);
                    },
                    child: _metaRow('Time', _billTime.format(context), icon: Icons.access_time)),
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
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF1F3F8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    _thCell('#', 30), _thCell('ITEM', 0, flex: 3), _thCell('QTY', 70),
                    _thCell('UNIT', 80), _thCell('PRICE/UNIT', 90), _thCell('DISCOUNT', 80),
                    _thCell('TAX %', 90), _thCell('TAX AMT', 80), _thCell('AMOUNT', 90),
                    const SizedBox(width: 36),
                  ]),
                ),
                // Table rows
                ..._cart.asMap().entries.map((e) => _buildTableRow(context, appState, e.key, e.value, isDark)),
                // Add Row button + totals
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300))),
                  child: Row(children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddItemDialog(context, appState),
                      icon: const Icon(Icons.add, size: 16), label: const Text('ADD ROW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), visualDensity: VisualDensity.compact)),
                    const Spacer(),
                    Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(width: 16),
                    SizedBox(width: 80, child: Text(AppFormatters.currency(_totalItemDiscount), textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 16),
                    SizedBox(width: 80, child: Text(AppFormatters.currency(_totalTax), textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    const SizedBox(width: 16),
                    SizedBox(width: 90, child: Text(AppFormatters.currency(_rawTotal), textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary))),
                    const SizedBox(width: 36),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // === PARTIAL PAYMENT UI (if selected) ===
            if (_isPartial) _buildPartialUI(isDark),

            // === BOTTOM: Round off + Total + Buttons ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
              child: Row(children: [
                // Description/notes area
                if (_showDescription)
                  Expanded(flex: 2, child: TextField(
                    decoration: _fieldDeco('Add Description / Notes', Icons.description_outlined),
                    maxLines: 2, style: const TextStyle(fontSize: 12))),
                if (_showDescription) const SizedBox(width: 16),
                const Spacer(),
                // Round off
                Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(height: 20, width: 20, child: Checkbox(value: _roundOff, activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _roundOff = v ?? false))),
                  const SizedBox(width: 4),
                  Text('Round Off', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  if (_roundOff) ...[
                    const SizedBox(width: 8),
                    Text(_roundOffAmount >= 0 ? '+${_roundOffAmount.toStringAsFixed(2)}' : _roundOffAmount.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ]),
                const SizedBox(width: 24),
                // Extra discount
                SizedBox(width: 100, child: TextField(controller: _discountCtrl, keyboardType: TextInputType.number,
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(labelText: 'Discount', prefixText: 'â‚¹', isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  onChanged: (_) => setState(() {}))),
                const SizedBox(width: 16),
                // Total
                Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(AppFormatters.currency(_totalAmount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary))),
                const SizedBox(width: 16),
                // Buttons
                OutlinedButton.icon(
                  onPressed: _cart.isEmpty ? null : () => _createBill(context, appState),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : () => _createBill(context, appState),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  // â”€â”€â”€ Helper widgets â”€â”€â”€

  Widget _toggleChip(String label, bool sel, VoidCallback onTap, bool isDark) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(18)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: sel ? Colors.white : (isDark ? Colors.white60 : Colors.black54)))));
  }

  InputDecoration _fieldDeco(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18),
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));
  }

  Widget _metaRow(String label, String value, {IconData? icon}) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text('$label  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 14, color: AppColors.primary)],
    ]);
  }

  Widget _thCell(String text, double width, {int flex = 0}) {
    final child = Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5), textAlign: TextAlign.center);
    if (flex > 0) return Expanded(flex: flex, child: child);
    return SizedBox(width: width, child: child);
  }

  Widget _buildTableRow(BuildContext context, AppState appState, int index, _CartItem c, bool isDark) {
    final isMeter = c.item.unit.toLowerCase() == 'mtr' || c.item.unit.toLowerCase() == 'meter';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Main row
        Row(children: [
          SizedBox(width: 30, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text(c.item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          // QTY
          SizedBox(width: 70, child: SizedBox(height: 30, child: TextField(
            key: ValueKey('qty_${c.item.id}'),
            controller: TextEditingController(text: '${c.quantity}'),
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            onChanged: (v) { final q = int.tryParse(v) ?? 0; if (q > 0) setState(() => c.updateQuantity(q)); },
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ))),
          // UNIT
          SizedBox(width: 80, child: SizedBox(height: 30, child: DropdownButtonFormField<String>(
            value: c.item.unit, isDense: true,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            items: ['pcs', 'kg', 'ltr', 'mtr', 'box', 'nos', 'set', 'pair'].map((u) =>
              DropdownMenuItem(value: u, child: Text(u.toUpperCase(), style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: (v) { if (v != null) setState(() => c.item.unit = v); },
          ))),
          // PRICE - typable
          SizedBox(width: 90, child: SizedBox(height: 30, child: TextField(
            key: ValueKey('price_${c.item.id}'),
            controller: TextEditingController(text: c.item.price.toStringAsFixed(2)),
            keyboardType: TextInputType.number, textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(isDense: true, prefixText: '₹', prefixStyle: const TextStyle(fontSize: 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            onChanged: (v) { final p = double.tryParse(v); if (p != null && p >= 0) setState(() => c.item.price = p); },
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ))),
          // DISCOUNT
          SizedBox(width: 80, child: SizedBox(height: 30, child: TextField(
            key: ValueKey('disc_${c.item.id}'),
            keyboardType: TextInputType.number, textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11), controller: TextEditingController(text: c.itemDiscount > 0 ? c.itemDiscount.toStringAsFixed(0) : ''),
            decoration: InputDecoration(isDense: true, hintText: '0', contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            onChanged: (v) => setState(() => c.itemDiscount = double.tryParse(v) ?? 0),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ))),
          // TAX %
          SizedBox(width: 90, child: SizedBox(height: 30, child: DropdownButtonFormField<double>(
            value: c.item.taxRate, isDense: true,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300))),
            items: [0, 5, 12, 18, 28].map((r) =>
              DropdownMenuItem(value: r.toDouble(), child: Text(r == 0 ? 'NONE' : 'GST@$r%', style: const TextStyle(fontSize: 10)))).toList(),
            onChanged: (v) { if (v != null) setState(() => c.item.taxRate = v); },
          ))),
          // TAX AMT
          SizedBox(width: 80, child: Text(AppFormatters.currency(_itemTax(c)), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
          // AMOUNT
          SizedBox(width: 90, child: Text(AppFormatters.currency(_itemSubtotal(c) - c.itemDiscount + _itemTax(c)),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
          // Delete
          SizedBox(width: 36, child: IconButton(
            onPressed: () => setState(() => _cart.removeAt(index)),
            icon: Icon(Icons.close, size: 16, color: isDark ? Colors.white24 : Colors.black26),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30))),
        ]),
        // Description + Serial sub-row
        Padding(padding: const EdgeInsets.only(left: 30, top: 4, right: 36),
          child: Row(children: [
            // Description
            Expanded(child: SizedBox(height: 28, child: TextField(
              key: ValueKey('desc_${c.item.id}'),
              controller: TextEditingController(text: c.description),
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(isDense: true, hintText: 'Item description...', hintStyle: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26),
                prefixIcon: const Icon(Icons.description_outlined, size: 14), prefixIconConstraints: const BoxConstraints(minWidth: 28),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
              onChanged: (v) => c.description = v,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ))),
            // Serial numbers (hidden for meter unit)
            if (!isMeter) ...[
              const SizedBox(width: 8),
              ...List.generate(c.quantity > 3 ? 1 : c.quantity, (si) => Expanded(child: Padding(
                padding: EdgeInsets.only(left: si > 0 ? 4 : 0),
                child: SizedBox(height: 28, child: TextField(
                  key: ValueKey('serial_${c.item.id}_$si'),
                  controller: TextEditingController(text: si < c.serialNumbers.length ? c.serialNumbers[si] : ''),
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(isDense: true,
                    hintText: c.quantity > 3 ? 'Serials (comma sep)' : 'S/N ${si + 1}',
                    hintStyle: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : Colors.black26),
                    prefixIcon: const Icon(Icons.qr_code, size: 14), prefixIconConstraints: const BoxConstraints(minWidth: 28),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
                  onChanged: (v) {
                    if (c.quantity > 3) {
                      c.serialNumbers = List.filled(c.quantity, '');
                      final parts = v.split(',');
                      for (int p = 0; p < parts.length && p < c.quantity; p++) c.serialNumbers[p] = parts[p].trim();
                    } else if (si < c.serialNumbers.length) { c.serialNumbers[si] = v; }
                  },
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ))))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildPartialUI(bool isDark) {
    final amt1 = double.tryParse(_partialAmount1Ctrl.text) ?? 0;
    final amt2 = _totalAmount - amt1;
    final bool hasCreditMethod = _partialMethod1 == PaymentMethod.credit || _partialMethod2 == PaymentMethod.credit;
    // Calculate pending: credit portion is unpaid
    double pendingAmount = 0;
    if (_partialMethod1 == PaymentMethod.credit) pendingAmount += amt1;
    if (_partialMethod2 == PaymentMethod.credit) pendingAmount += (amt2 > 0 ? amt2 : 0);

    const allMethods = [PaymentMethod.cash, PaymentMethod.upi, PaymentMethod.card, PaymentMethod.bank, PaymentMethod.credit];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.call_split, size: 16, color: Colors.orangeAccent), SizedBox(width: 6),
          Text('Split Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.orangeAccent))]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Method 1: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ...(allMethods.map((pm) {
            final sel = _partialMethod1 == pm;
            return Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
              label: Text(AppFormatters.paymentMethod(pm.name), style: TextStyle(fontSize: 10, color: sel ? Colors.white : null)),
              selected: sel, selectedColor: pm == PaymentMethod.credit ? AppColors.error : AppColors.primary,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _partialMethod1 = pm)));
          })),
          const SizedBox(width: 12),
          SizedBox(width: 150, child: TextField(controller: _partialAmount1Ctrl, keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(labelText: 'Amount', prefixText: '₹', isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('Method 2: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ...(allMethods.map((pm) {
            final sel = _partialMethod2 == pm;
            return Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
              label: Text(AppFormatters.paymentMethod(pm.name), style: TextStyle(fontSize: 10, color: sel ? Colors.white : null)),
              selected: sel, selectedColor: pm == PaymentMethod.credit ? AppColors.error : AppColors.accent,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _partialMethod2 = pm)));
          })),
          const SizedBox(width: 12),
          Text('${AppFormatters.paymentMethod(_partialMethod2.name)}: ${AppFormatters.currency(amt2 > 0 ? amt2 : 0)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: _partialMethod2 == PaymentMethod.credit ? AppColors.error : AppColors.accent)),
        ]),
        // Pending amount when credit is selected
        if (hasCreditMethod && pendingAmount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text('Pending Amount: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
              Text(AppFormatters.currency(pendingAmount),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.error)),
              const Spacer(),
              Text('Bill will be marked as Partial/Unpaid', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
            ]),
          ),
        ],
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
            final inCart = _cart.any((c) => c.item.id == item.id);
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 16, backgroundColor: inCart ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1),
                child: Icon(inCart ? Icons.check : Icons.inventory_2, size: 14, color: inCart ? AppColors.success : AppColors.primary)),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text('${AppFormatters.currency(item.price)} Â· ${item.unit} Â· GST ${item.taxRate}%', style: const TextStyle(fontSize: 11)),
              trailing: inCart ? Text('In cart', style: TextStyle(fontSize: 10, color: AppColors.success)) : null,
              onTap: () { _addToCart(item); Navigator.pop(ctx); },
            );
          })),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      );
    }));
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
      // Calculate paid amount for partial with credit
      double paidAmt = _totalAmount;
      BillStatus billStatus = BillStatus.paid;
      if (_isPartial) {
        final a1 = double.tryParse(_partialAmount1Ctrl.text) ?? 0;
        final a2 = _totalAmount - a1;
        double creditAmt = 0;
        if (_partialMethod1 == PaymentMethod.credit) creditAmt += a1;
        if (_partialMethod2 == PaymentMethod.credit) creditAmt += (a2 > 0 ? a2 : 0);
        paidAmt = _totalAmount - creditAmt;
        if (creditAmt > 0) billStatus = BillStatus.partial;
      } else if (_paymentMethod == PaymentMethod.credit) {
        paidAmt = 0;
        billStatus = BillStatus.unpaid;
      }
      final bill = Bill(billNumber: billNumber, customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? (walkInName.isNotEmpty ? walkInName : null),
        customerPhone: _selectedCustomer?.phone ?? (walkInPhone.isNotEmpty ? walkInPhone : null),
        items: billItems, subtotal: _subtotal,
        discount: _discount,
        totalTax: _totalTax, totalAmount: _totalAmount,
        paidAmount: paidAmt,
        paymentMethod: _isPartial ? _partialMethod1 : _paymentMethod,
        status: billStatus);
      await appState.createBill(bill);

      // Auto-add to Cash Book or Bank Book based on payment method
      if (_isPartial && _totalAmount > 0) {
        // Handle partial: two entries
        final amt1 = double.tryParse(_partialAmount1Ctrl.text) ?? 0;
        final amt2 = _totalAmount - amt1;
        try {
          // Entry 1 (skip if credit)
          if (amt1 > 0 && _partialMethod1 != PaymentMethod.credit) {
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
          if (amt2 > 0 && _partialMethod2 != PaymentMethod.credit) {
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
          _isPartial = false; _partialAmount1Ctrl.text = ''; _roundOff = false;
          _discountCtrl.text = '0'; _walkInNameCtrl.clear(); _walkInPhoneCtrl.clear(); _addressCtrl.clear(); });
        _loadColumnSettings(); // reload next invoice number
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
          if (action == 'print') {
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
            );
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


