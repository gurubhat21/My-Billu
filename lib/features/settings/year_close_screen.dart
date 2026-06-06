import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/fy_service.dart';
import '../../core/models/bill.dart';
import '../../widgets/common_widgets.dart';

class YearCloseScreen extends StatefulWidget {
  const YearCloseScreen({super.key});
  @override
  State<YearCloseScreen> createState() => _YearCloseScreenState();
}

class _YearCloseScreenState extends State<YearCloseScreen> {
  int _step = 0; // 0 = review, 1 = confirm, 2 = processing, 3 = done
  bool _processing = false;
  String? _error;
  String? _newFY;

  // Closing summaries
  int _totalBills = 0;
  int _totalPurchases = 0;
  int _totalItems = 0;
  double _closingStockValue = 0;
  int _unpaidBillCount = 0;
  double _unpaidBillTotal = 0;
  double _customerOutstanding = 0;
  double _supplierOutstanding = 0;
  double _bankBalance = 0;

  @override
  void initState() {
    super.initState();
    _calculateClosingSummary();
  }

  void _calculateClosingSummary() {
    final appState = context.read<AppState>();
    _totalBills = appState.bills.length;
    _totalPurchases = appState.purchases.length;
    _totalItems = appState.items.length;
    _closingStockValue = appState.items.fold(0.0, (sum, item) =>
        sum + (item.stockQuantity * item.price));

    final unpaidBills = appState.bills.where((b) => b.status != BillStatus.paid).toList();
    _unpaidBillCount = unpaidBills.length;
    _unpaidBillTotal = unpaidBills.fold(0.0, (sum, b) => sum + b.balanceDue);

    _customerOutstanding = appState.customers.fold(0.0, (sum, c) => sum + c.outstandingBalance);
    _supplierOutstanding = appState.suppliers.fold(0.0, (sum, s) => sum + s.outstandingBalance);
    _bankBalance = appState.bankAccounts.fold(0.0, (sum, a) => sum + a.balance);

    setState(() {});
  }

  Future<void> _executeYearClose() async {
    setState(() { _processing = true; _step = 2; _error = null; });

    try {
      final appState = context.read<AppState>();

      // Prepare items data (carry forward with stock)
      final itemsData = appState.items.map((item) => item.toMap()).toList();

      // Prepare customers data (carry forward with outstanding balance)
      final customersData = appState.customers.map((c) => c.toMap()).toList();

      // Prepare suppliers data
      final suppliersData = appState.suppliers.map((s) => s.toMap()).toList();

      // Prepare bank accounts data
      final bankAccountsData = appState.bankAccounts.map((a) => a.toMap()).toList();

      // Prepare active recurring bills
      final recurringData = appState.recurringBills
          .where((rb) => rb.isActive)
          .map((rb) => rb.toMap())
          .toList();

      // Prepare unpaid bills (copy to new FY)
      final unpaidBills = appState.bills
          .where((b) => b.status != BillStatus.paid)
          .map((b) => b.toMap())
          .toList();

      // Prepare settings to carry forward (business info, preferences)
      final allSettings = await appState.getAllSettings();
      final settingsToCarry = <String, String>{};
      // Carry business settings, theme, preferences
      final carryKeys = [
        'businessName', 'businessAddress', 'businessPhone', 'businessGstin',
        'businessLogo', 'businessBankName', 'businessBankAccount',
        'businessBankIfsc', 'businessUpiId', 'loginUsername', 'loginPassword',
        'app_theme', 'biometric_enabled', 'pdf_thank_you_message',
        'pdf_terms_conditions', 'pdf_save_path', 'billing_show_description',
        'billing_show_serial_number', 'invoice_prefix', 'invoice_pattern',
        'app_expiry_date', 'gmail_registered', 'registered_email',
        'registered_display_name', 'subscription_status', 'subscription_expiry',
        'data_path',
      ];
      for (final key in carryKeys) {
        if (allSettings.containsKey(key)) {
          settingsToCarry[key] = allSettings[key]!;
        }
      }
      // Reset start number to 1 in new FY
      settingsToCarry['invoice_start_number'] = '1';

      // Execute year close
      _newFY = await FYService.instance.closeYearAndCreateNew(
        itemsData: itemsData,
        customersData: customersData,
        suppliersData: suppliersData,
        bankAccountsData: bankAccountsData,
        recurringBillsData: recurringData,
        unpaidBillsData: unpaidBills,
        settingsToCarry: settingsToCarry,
      );

      // Reload data from new FY database
      await appState.reloadAllData();

      setState(() { _processing = false; _step = 3; });
    } catch (e) {
      setState(() { _processing = false; _error = e.toString(); _step = 1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFY = FYService.instance.activeFY;
    final startYear = int.parse(currentFY.split('-').first);
    final nextFY = '${startYear + 1}-${(startYear + 2).toString().substring(2)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Close Financial Year'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _step == 0 ? _buildReviewStep(currentFY, nextFY)
                : _step == 1 ? _buildConfirmStep(currentFY, nextFY)
                : _step == 2 ? _buildProcessingStep()
                : _buildDoneStep(),
          ),
        )),
      ),
    );
  }

  Widget _buildReviewStep(String currentFY, String nextFY) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.event_note, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Close FY $currentFY', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text('Create new FY $nextFY', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          ])),
        ]),
      ),
      const SizedBox(height: 24),

      // Closing Summary Card
      GlassCard(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📊 Closing Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _summaryRow('Total Bills', '$_totalBills'),
          _summaryRow('Total Purchases', '$_totalPurchases'),
          _summaryRow('Total Items', '$_totalItems'),
          _summaryRow('Closing Stock Value', AppFormatters.currency(_closingStockValue)),
          const Divider(height: 24),
          _summaryRow('Unpaid Bills', '$_unpaidBillCount (${AppFormatters.currency(_unpaidBillTotal)})',
              color: _unpaidBillCount > 0 ? AppColors.warning : null),
          _summaryRow('Customer Outstanding', AppFormatters.currency(_customerOutstanding),
              color: _customerOutstanding > 0 ? AppColors.warning : null),
          _summaryRow('Supplier Outstanding', AppFormatters.currency(_supplierOutstanding),
              color: _supplierOutstanding > 0 ? AppColors.warning : null),
          _summaryRow('Bank Balance', AppFormatters.currency(_bankBalance),
              color: AppColors.success),
        ],
      )),
      const SizedBox(height: 16),

      // What will carry forward
      GlassCard(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📋 What Carries to New FY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _carryRow(Icons.inventory, 'Items with closing stock', true),
          _carryRow(Icons.people, 'Customers with outstanding balance', true),
          _carryRow(Icons.local_shipping, 'Suppliers with outstanding balance', true),
          _carryRow(Icons.account_balance, 'Bank accounts with balance', true),
          _carryRow(Icons.receipt_long, 'Unpaid bills ($_unpaidBillCount)', true),
          _carryRow(Icons.repeat, 'Active recurring bills', true),
          _carryRow(Icons.settings, 'Business settings & preferences', true),
          const Divider(height: 16),
          _carryRow(Icons.receipt, 'Paid bills & old transactions', false),
          _carryRow(Icons.shopping_cart, 'Paid purchases', false),
          _carryRow(Icons.request_quote, 'Quotations', false),
          _carryRow(Icons.money_off, 'Expenses', false),
          _carryRow(Icons.book, 'Cash book entries', false),
        ],
      )),
      const SizedBox(height: 16),

      // Invoice number reset notice
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
        child: const Row(children: [
          Icon(Icons.info, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('All invoice, quotation, and purchase numbers will reset to 1 in the new FY.',
            style: TextStyle(fontSize: 12, color: AppColors.primary))),
        ]),
      ),
      const SizedBox(height: 24),

      // Action buttons
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        )),
        const SizedBox(width: 16),
        Expanded(child: ElevatedButton.icon(
          onPressed: () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Proceed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ]),
    ]);
  }

  Widget _buildConfirmStep(String currentFY, String nextFY) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
        child: Column(children: [
          const Icon(Icons.warning_amber, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          const Text('Confirm Year Close', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('You are about to close FY $currentFY and create FY $nextFY.\n'
              'All data will be preserved in the old FY database.\n'
              'You can switch back to view old FY data anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        ]),
      ),

      if (_error != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.error, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
          ]),
        ),
      ],

      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Go Back'),
        )),
        const SizedBox(width: 16),
        Expanded(child: ElevatedButton.icon(
          onPressed: _executeYearClose,
          icon: const Icon(Icons.check_circle),
          label: const Text('Close Year & Create New FY'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ]),
    ]);
  }

  Widget _buildProcessingStep() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 40),
      const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
      const SizedBox(height: 24),
      const Text('Closing year...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Creating new FY database and carrying forward data...',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
      const SizedBox(height: 40),
    ]);
  }

  Widget _buildDoneStep() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 40),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          shape: BoxShape.circle),
        child: const Icon(Icons.check_circle, color: AppColors.success, size: 64),
      ),
      const SizedBox(height: 24),
      const Text('Year Closed Successfully! 🎉', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('You are now in FY ${_newFY ?? ""}',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
      const SizedBox(height: 8),
      Text('All invoice numbers have been reset to 1.',
        style: TextStyle(color: AppColors.primary, fontSize: 13)),
      const SizedBox(height: 32),
      SizedBox(width: 200, child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.home),
        label: const Text('Go to Dashboard'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          padding: const EdgeInsets.symmetric(vertical: 14)),
      )),
      const SizedBox(height: 40),
    ]);
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
          color: color ?? AppColors.primary)),
      ]));
  }

  Widget _carryRow(IconData icon, String label, bool carries) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(carries ? Icons.check_circle : Icons.cancel,
          size: 16, color: carries ? AppColors.success : AppColors.error.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12,
          color: carries ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.4))),
      ]));
  }
}
