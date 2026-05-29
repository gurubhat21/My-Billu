import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/bill.dart';
import '../../core/utils/invoice_generator.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

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
  String _company1Gstin = '';
  String _company2Name = '';
  String _company2Phone = '';
  String _company2Gstin = '';
  
  // Quotation fields
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  List<BillItem> _items = [];
  final _itemNameCtrl = TextEditingController();
  final _itemPriceCtrl = TextEditingController();
  final _itemQtyCtrl = TextEditingController(text: '1');
  final _itemUnitCtrl = TextEditingController(text: 'Pcs');
  final _itemDescCtrl = TextEditingController();
  double _discount = 0;
  final _discountCtrl = TextEditingController(text: '0');
  
  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }
  
  Future<void> _loadProfiles() async {
    final appState = context.read<AppState>();
    final c1n = await appState.getSetting('fake_company_1_name') ?? '';
    final c1p = await appState.getSetting('fake_company_1_phone') ?? '';
    final c1g = await appState.getSetting('fake_company_1_gstin') ?? '';
    final c2n = await appState.getSetting('fake_company_2_name') ?? '';
    final c2p = await appState.getSetting('fake_company_2_phone') ?? '';
    final c2g = await appState.getSetting('fake_company_2_gstin') ?? '';
    if (mounted) setState(() {
      _company1Name = c1n; _company1Phone = c1p; _company1Gstin = c1g;
      _company2Name = c2n; _company2Phone = c2p; _company2Gstin = c2g;
    });
  }
  
  String get _currentCompanyName => _selectedProfile == 1 ? _company1Name : _company2Name;
  String get _currentCompanyPhone => _selectedProfile == 1 ? _company1Phone : _company2Phone;
  String get _currentCompanyGstin => _selectedProfile == 1 ? _company1Gstin : _company2Gstin;
  
  double get _subtotal => _items.fold(0.0, (s, i) => s + i.total);
  double get _totalAmount => _subtotal - _discount;
  
  void _addItem() {
    final name = _itemNameCtrl.text.trim();
    final price = double.tryParse(_itemPriceCtrl.text) ?? 0;
    final qty = int.tryParse(_itemQtyCtrl.text) ?? 1;
    final unit = _itemUnitCtrl.text.trim().isNotEmpty ? _itemUnitCtrl.text.trim() : 'Pcs';
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter item name and price')));
      return;
    }
    setState(() {
      _items.add(BillItem(
        itemId: const Uuid().v4(),
        itemName: name,
        unitPrice: price,
        quantity: qty,
        unit: unit,
        taxRate: 0,
        description: _itemDescCtrl.text.trim().isNotEmpty ? _itemDescCtrl.text.trim() : null,
      ));
      _itemNameCtrl.clear();
      _itemPriceCtrl.clear();
      _itemQtyCtrl.text = '1';
      _itemDescCtrl.clear();
    });
  }
  
  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _generateQuote() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }
    if (_currentCompanyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please configure fake company in Settings first')));
      return;
    }
    
    final appState = context.read<AppState>();
    final bill = Bill(
      billNumber: 'FQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      customerName: _customerNameCtrl.text.trim().isNotEmpty ? _customerNameCtrl.text.trim() : 'Customer',
      customerPhone: _customerPhoneCtrl.text.trim(),
      items: _items,
      subtotal: _subtotal,
      totalTax: 0,
      discount: _discount,
      totalAmount: _totalAmount,
      paidAmount: 0,
      paymentMethod: PaymentMethod.cash,
      status: BillStatus.unpaid,
      createdAt: DateTime.now(),
    );
    
    // Get template and paper size from settings
    final templateStr = await appState.getSetting('pdf_template') ?? 'simple';
    final paperStr = await appState.getSetting('pdf_paper_size') ?? 'a4';
    InvoiceTemplate template;
    switch (templateStr) {
      case 'classic': template = InvoiceTemplate.classic; break;
      case 'minimal': template = InvoiceTemplate.minimal; break;
      case 'gstInvoice': template = InvoiceTemplate.gstInvoice; break;
      case 'simple': template = InvoiceTemplate.simple; break;
      default: template = InvoiceTemplate.modern;
    }
    final paperSize = paperStr == 'a5' ? PaperSize.a5 : PaperSize.a4;
    
    await InvoiceGenerator.generateAndPrint(
      bill,
      template: template,
      paperSize: paperSize,
      documentTitle: 'QUOTATION',
      businessName: _currentCompanyName,
      businessAddress: '',
      businessPhone: _currentCompanyPhone,
      businessGstin: _currentCompanyGstin,
    );
  }
  
  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _itemNameCtrl.dispose();
    _itemPriceCtrl.dispose();
    _itemQtyCtrl.dispose();
    _itemUnitCtrl.dispose();
    _itemDescCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Company Profile Selection
        GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Text('Select Company Profile', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _profileCard(1, _company1Name, _company1Phone, _company1Gstin)),
              const SizedBox(width: 12),
              Expanded(child: _profileCard(2, _company2Name, _company2Phone, _company2Gstin)),
            ]),
            if (_currentCompanyName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Using: $_currentCompanyName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.success)),
                  if (_currentCompanyPhone.isNotEmpty) Text('Phone: $_currentCompanyPhone', style: const TextStyle(fontSize: 12)),
                  if (_currentCompanyGstin.isNotEmpty) Text('GSTIN: $_currentCompanyGstin', style: const TextStyle(fontSize: 12)),
                ])),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                child: const Text('⚠ Please configure company profiles in Settings → Fake Quote',
                  style: TextStyle(fontSize: 12, color: AppColors.warning))),
            ],
          ])),
        const SizedBox(height: 16),
        
        // Customer Details
        GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person, color: AppColors.primary, size: 22)),
              const SizedBox(width: 12),
              Text('Customer Details', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(
                controller: _customerNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _customerPhoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
          ])),
        const SizedBox(height: 16),
        
        // Add Items
        GlassCard(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_shopping_cart, color: Color(0xFF8B5CF6), size: 22)),
              const SizedBox(width: 12),
              Text('Add Items', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(flex: 3, child: TextField(
                controller: _itemNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: TextField(
                controller: _itemPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: TextField(
                controller: _itemQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: TextField(
                controller: _itemUnitCtrl,
                decoration: InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _itemDescCtrl,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _addItem,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Item', style: TextStyle(color: Colors.white)),
            )),
          ])),
        const SizedBox(height: 16),
        
        // Items List
        if (_items.isNotEmpty)
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Items (${_items.length})', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._items.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                child: Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Rs.${e.value.unitPrice.toStringAsFixed(2)} × ${e.value.quantity} ${e.value.unit} = Rs.${e.value.total.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                  ])),
                  IconButton(icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                    onPressed: () => _removeItem(e.key)),
                ]),
              )),
              const Divider(),
              // Discount
              Row(children: [
                const Text('Discount: ', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(width: 100, child: TextField(
                  controller: _discountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: 'Rs.',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
                )),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 14)),
                Text('Rs.${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              if (_discount > 0)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Discount:', style: TextStyle(fontSize: 14, color: AppColors.error)),
                  Text('- Rs.${_discount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Rs.${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ])),
        const SizedBox(height: 20),
        
        // Generate Button
        SizedBox(width: double.infinity, height: 56, child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _generateQuote,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 22),
            label: const Text('Generate Fake Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        )),
      ]),
    );
  }

  Widget _profileCard(int num, String name, String phone, String gstin) {
    final isSelected = _selectedProfile == num;
    final hasData = name.isNotEmpty;
    return InkWell(
      onTap: () => setState(() => _selectedProfile = num),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 8),
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
}
