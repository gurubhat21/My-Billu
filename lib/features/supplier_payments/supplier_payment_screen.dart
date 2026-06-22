import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/purchase.dart';
import '../../core/models/bill.dart';
import '../../core/models/cash_book.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class SupplierPaymentScreen extends StatelessWidget {
  const SupplierPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supplier Payments'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.payment), text: 'Pay Supplier'),
            Tab(icon: Icon(Icons.history), text: 'Payment History'),
          ]),
        ),
        body: const TabBarView(children: [
          _PaySupplierTab(),
          _PaymentHistoryTab(),
        ]),
      ),
    );
  }
}

// ========== PAY SUPPLIER TAB ==========

class _PaySupplierTab extends StatefulWidget {
  const _PaySupplierTab();
  @override
  State<_PaySupplierTab> createState() => _PaySupplierTabState();
}

class _PaySupplierTabState extends State<_PaySupplierTab> {
  String _filterSupplier = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      // Get purchases with outstanding balance (accounting for returns)
      final unpaid = appState.purchases.where((p) => appState.getEffectiveBalanceDue(p) > 0.01).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final filtered = _filterSupplier.isEmpty
          ? unpaid
          : unpaid.where((p) => p.supplierName.toLowerCase().contains(_filterSupplier.toLowerCase())).toList();

      // Group by supplier
      final grouped = <String, List<Purchase>>{};
      for (final p in filtered) {
        grouped.putIfAbsent(p.supplierName, () => []).add(p);
      }

      return LayoutBuilder(builder: (context, constraints) {
        return Column(children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _filterSupplier = v),
              decoration: InputDecoration(
                hintText: 'Search supplier...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),
          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _summaryChip('Suppliers', '${grouped.length}', Icons.local_shipping, AppColors.accent),
                _summaryChip('Invoices', '${filtered.length}', Icons.receipt, AppColors.primary),
                _summaryChip('Total Pending',
                    AppFormatters.currency(filtered.fold(0.0, (s, p) => s + appState.getEffectiveBalanceDue(p))),
                    Icons.currency_rupee, AppColors.error),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No pending payments',
                    subtitle: 'All supplier purchases are fully paid')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, i) {
                      final supplier = grouped.keys.elementAt(i);
                      final purchases = grouped[supplier]!;
                      final totalPending = purchases.fold(0.0, (s, p) => s + appState.getEffectiveBalanceDue(p));
                      return _supplierCard(context, supplier, purchases, totalPending, appState);
                    },
                  ),
          ),
        ]);
      });
    });
  }

  Widget _summaryChip(String label, String value, IconData icon, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _supplierCard(BuildContext context, String supplier, List<Purchase> purchases, double totalPending, AppState appState) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
          child: Text(supplier[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
        ),
        title: Text(supplier, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text('${purchases.length} invoice(s) · Pending: ${AppFormatters.currency(totalPending)}',
            style: const TextStyle(fontSize: 11, color: AppColors.error)),
        trailing: ElevatedButton.icon(
          onPressed: () => _showPayDialog(context, appState, supplier, purchases, totalPending),
          icon: const Icon(Icons.payment, size: 16),
          label: const Text('Pay', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        children: purchases.map((p) {
          final effectiveDue = appState.getEffectiveBalanceDue(p);
          final returnAmt = appState.getReturnAmountForPurchase(p.id);
          return ListTile(
            dense: true,
            leading: const Icon(Icons.receipt_long, size: 18),
            title: Text('${p.purchaseNumber} · ${AppFormatters.shortDate(p.createdAt)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: Text('Total: ${AppFormatters.currency(p.totalAmount)}${returnAmt > 0 ? ' · Return: -${AppFormatters.currency(returnAmt)}' : ''} · Paid: ${AppFormatters.currency(p.paidAmount)}',
                style: const TextStyle(fontSize: 11)),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Pending', style: TextStyle(fontSize: 9, color: AppColors.error.withValues(alpha: 0.7))),
              Text(AppFormatters.currency(effectiveDue),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.error)),
            ]),
            onTap: () => _showPaySingleDialog(context, appState, p),
          );
        }).toList(),
      ),
    );
  }

  void _showPayDialog(BuildContext context, AppState appState, String supplier, List<Purchase> purchases, double totalPending) {
    final amtCtrl = TextEditingController(text: totalPending.toStringAsFixed(2));
    String payMode = 'cash';
    BankAccount? selectedBank = appState.bankAccounts.isNotEmpty ? appState.bankAccounts.first : null;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final amt = double.tryParse(amtCtrl.text) ?? 0;
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.payment, color: AppColors.success, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Pay $supplier', style: const TextStyle(fontSize: 16))),
          ]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Total pending
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Pending', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(AppFormatters.currency(totalPending),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.error)),
              ]),
            ),
            const SizedBox(height: 16),
            // Amount
            TextField(
              controller: amtCtrl, autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              onChanged: (_) => setDialogState(() {}),
            ),
            const SizedBox(height: 16),
            // Pay Mode
            const Align(alignment: Alignment.centerLeft,
                child: Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            Row(children: [
              ChoiceChip(
                label: const Text('Cash'),
                selected: payMode == 'cash', selectedColor: AppColors.success,
                labelStyle: TextStyle(color: payMode == 'cash' ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w600),
                onSelected: (_) => setDialogState(() => payMode = 'cash')),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Bank'),
                selected: payMode == 'bank', selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: payMode == 'bank' ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w600),
                onSelected: (_) => setDialogState(() => payMode = 'bank')),
            ]),
            // Bank selection
            if (payMode == 'bank') ...[
              const SizedBox(height: 12),
              if (appState.bankAccounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
                  child: const Row(children: [
                    Icon(Icons.warning, size: 16, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Expanded(child: Text('No bank accounts added. Go to Cash & Bank Book → Add Bank.',
                        style: TextStyle(fontSize: 11, color: Colors.orangeAccent))),
                  ]),
                )
              else
                DropdownButtonFormField<BankAccount>(
                  value: selectedBank,
                  decoration: InputDecoration(
                    labelText: 'Select Bank Account',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true),
                  items: appState.bankAccounts.map((b) => DropdownMenuItem(
                    value: b,
                    child: Text('${b.bankName} - ${b.accountNumber}', style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedBank = v),
                ),
            ],
            const SizedBox(height: 14),
            // Remaining after payment
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (totalPending - amt > 0 ? Colors.orangeAccent : AppColors.success).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (totalPending - amt > 0 ? Colors.orangeAccent : AppColors.success).withValues(alpha: 0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(totalPending - amt > 0.01 ? 'Remaining After Payment' : 'Fully Settled',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                        color: totalPending - amt > 0.01 ? Colors.orangeAccent : AppColors.success)),
                Text(AppFormatters.currency((totalPending - amt).clamp(0, double.infinity)),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                        color: totalPending - amt > 0.01 ? Colors.orangeAccent : AppColors.success)),
              ]),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (amt <= 0 || (payMode == 'bank' && selectedBank == null))
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _processPayment(context, appState, purchases, amt, payMode, selectedBank, supplier);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Pay Now')),
          ],
        );
      },
    ));
  }

  void _showPaySingleDialog(BuildContext context, AppState appState, Purchase purchase) {
    final effectiveDue = appState.getEffectiveBalanceDue(purchase);
    _showPayDialog(context, appState, purchase.supplierName, [purchase], effectiveDue);
  }

  Future<void> _processPayment(BuildContext context, AppState appState, List<Purchase> purchases, double amount, String payMode, BankAccount? bank, String supplier) async {
    try {
      var remaining = amount;
      // Distribute payment across purchases (oldest first)
      final sorted = [...purchases]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final p in sorted) {
        if (remaining <= 0) break;
        final due = appState.getEffectiveBalanceDue(p);
        final paying = remaining >= due ? due : remaining;
        p.paidAmount += paying;
        if (appState.getEffectiveBalanceDue(p) <= 0.01) {
          p.status = PurchaseStatus.received;
          p.paymentMethod = payMode == 'cash' ? PaymentMethod.cash : PaymentMethod.bank;
        }
        remaining -= paying;
        await appState.updatePurchase(p);
      }

      // Record in Cash/Bank Book
      if (payMode == 'cash') {
        await appState.addCashBookEntry(CashBookEntry(
          type: TransactionType.cashOut,
          amount: amount,
          description: 'Supplier Payment (Cash) - $supplier',
          reference: purchases.map((p) => p.purchaseNumber).join(', '),
          category: 'Purchase',
        ));
      } else if (bank != null) {
        await appState.addCashBookEntry(CashBookEntry(
          type: TransactionType.bankOut,
          amount: amount,
          description: 'Supplier Payment (${bank.bankName}) - $supplier',
          reference: purchases.map((p) => p.purchaseNumber).join(', '),
          bankAccountId: bank.id,
          category: 'Purchase',
        ));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
            Text('₹${amount.toStringAsFixed(2)} paid to $supplier'),
          ]),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

// ========== PAYMENT HISTORY TAB ==========

class _PaymentHistoryTab extends StatelessWidget {
  const _PaymentHistoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      // Show cash book entries with category 'Purchase'
      final entries = appState.cashBookEntries
          .where((e) => e.category == 'Purchase' && !e.isInflow)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (entries.isEmpty) {
        return const EmptyState(
            icon: Icons.history,
            title: 'No payment history',
            subtitle: 'Supplier payments will appear here');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (ctx, i) {
          final e = entries[i];
          final isBank = e.type == TransactionType.bankOut;
          String bankName = '';
          if (isBank && e.bankAccountId != null) {
            final ba = appState.bankAccounts.cast<BankAccount?>().firstWhere(
                (b) => b!.id == e.bankAccountId, orElse: () => null);
            bankName = ba?.bankName ?? 'Bank';
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (isBank ? AppColors.primary : AppColors.success).withValues(alpha: 0.15),
                child: Icon(isBank ? Icons.account_balance : Icons.money,
                    color: isBank ? AppColors.primary : AppColors.success, size: 20),
              ),
              title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                  '${AppFormatters.shortDate(e.date)} · ${isBank ? bankName : "Cash"}${e.reference != null ? " · ${e.reference}" : ""}',
                  style: const TextStyle(fontSize: 11)),
              trailing: Text(AppFormatters.currency(e.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.error)),
            ),
          );
        },
      );
    });
  }
}
