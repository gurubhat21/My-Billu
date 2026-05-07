import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/customer.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});
  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  Customer? _selectedCustomer;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customers = appState.customers;

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
        Text('Customer Ledger', style: Theme.of(context).textTheme.headlineLarge),
        const Spacer(),
        SizedBox(width: 300, child: DropdownButtonFormField<Customer>(
          decoration: InputDecoration(
            hintText: 'Select Customer', isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          isExpanded: true,
          value: _selectedCustomer,
          items: customers.map((c) => DropdownMenuItem(value: c,
            child: Text('${c.name}${c.phone != null ? " (${c.phone})" : ""}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (c) => setState(() => _selectedCustomer = c),
        )),
      ])),
      const SizedBox(height: 16),
      Expanded(child: _selectedCustomer == null
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('Select a customer to view ledger', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
          ]))
        : _buildLedger(context, appState)),
    ]);
  }

  Widget _buildLedger(BuildContext context, AppState appState) {
    final customer = _selectedCustomer!;
    final entries = appState.getCustomerLedger(customer.id);
    double runningBalance = 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Customer Summary Card
        GlassCard(padding: const EdgeInsets.all(20), child: Row(children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
            gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.person, color: Colors.white, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            if (customer.phone != null) Text(customer.phone!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
            if (customer.gstin != null) Text('GSTIN: ${customer.gstin}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ])),
          Column(children: [
            _summaryChip('Total Sales', AppFormatters.currency(customer.totalPurchases), AppColors.primary),
            const SizedBox(height: 6),
            _summaryChip('Outstanding', AppFormatters.currency(customer.outstandingBalance),
              customer.outstandingBalance > 0 ? AppColors.error : AppColors.success),
          ]),
        ])),
        const SizedBox(height: 20),

        // Ledger Table
        if (entries.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40),
            child: Text('No transactions found', style: TextStyle(color: Colors.white.withValues(alpha: 0.3)))))
        else
          GlassCard(padding: const EdgeInsets.all(16), child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(flex: 2, child: Text('Debit (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(flex: 2, child: Text('Credit (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                Expanded(flex: 2, child: Text('Balance (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
              ]),
            ),
            const Divider(height: 1),
            ...entries.map((e) {
              final debit = e['debit'] as double;
              final credit = e['credit'] as double;
              runningBalance += debit - credit;
              final date = e['date'] as DateTime;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
                child: Row(children: [
                  Expanded(flex: 2, child: Text(AppFormatters.shortDate(date), style: const TextStyle(fontSize: 11))),
                  Expanded(flex: 2, child: Row(children: [
                    Icon(e['type'] == 'Invoice' ? Icons.receipt : e['type'] == 'Payment' ? Icons.payments : Icons.assignment_return,
                      size: 14, color: e['type'] == 'Invoice' ? AppColors.error : AppColors.success),
                    const SizedBox(width: 4),
                    Text(e['type'] as String, style: const TextStyle(fontSize: 11)),
                  ])),
                  Expanded(flex: 2, child: Text(e['ref'] as String, style: const TextStyle(fontSize: 11))),
                  Expanded(flex: 2, child: Text(debit > 0 ? AppFormatters.currency(debit) : '-',
                    textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: debit > 0 ? AppColors.error : null))),
                  Expanded(flex: 2, child: Text(credit > 0 ? AppFormatters.currency(credit) : '-',
                    textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: credit > 0 ? AppColors.success : null))),
                  Expanded(flex: 2, child: Text(AppFormatters.currency(runningBalance),
                    textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: runningBalance > 0 ? AppColors.error : AppColors.success))),
                ]),
              );
            }),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(color: (runningBalance > 0 ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
              child: Row(children: [
                const Expanded(flex: 8, child: Text('CLOSING BALANCE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(flex: 2, child: Text(AppFormatters.currency(runningBalance), textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: runningBalance > 0 ? AppColors.error : AppColors.success))),
              ]),
            ),
          ])),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }
}
