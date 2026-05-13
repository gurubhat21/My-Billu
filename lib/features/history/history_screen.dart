import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_generator.dart';
import '../../core/database/excel_exporter.dart';
import '../../widgets/common_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final bills = _search.isEmpty ? appState.bills
          : appState.bills.where((b) =>
              b.billNumber.toLowerCase().contains(_search.toLowerCase()) ||
              (b.customerName ?? '').toLowerCase().contains(_search.toLowerCase()) ||
              (b.customerPhone ?? '').contains(_search)).toList();

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Column(children: [
          Padding(padding: EdgeInsets.all(isWide ? 24 : 16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Bill History', style: Theme.of(context).textTheme.headlineLarge)),
                OutlinedButton.icon(
                  onPressed: () => _exportBills(context, appState.bills),
                  icon: const Icon(Icons.download, size: 20),
                  label: Text(isWide ? 'Export Excel' : 'Export'),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(hintText: 'Search by bill no, name, or phone...', prefixIcon: Icon(Icons.search, color: AppColors.primary))),
            ])),
          Expanded(child: bills.isEmpty
              ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No bills yet', subtitle: 'Bills you create will appear here')
              : ListView.builder(padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                  itemCount: bills.length, itemBuilder: (ctx, i) => _billTile(context, bills[i]))),
        ]);
      });
    });
  }

  Widget _billTile(BuildContext context, Bill bill) {
    final statusColor = bill.status == BillStatus.paid ? AppColors.success
        : bill.status == BillStatus.partial ? AppColors.warning : AppColors.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(onTap: () => _showBillDetail(context, bill), padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt, size: 22, color: AppColors.primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(bill.customerName ?? 'Walk-in Customer', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(AppFormatters.dateTime(bill.createdAt), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.currency(bill.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Paid: ${AppFormatters.currency(bill.paidAmount)}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success.withValues(alpha: 0.8))),
              if (bill.balanceDue > 0) ...[
                const SizedBox(width: 6),
                Text('Due: ${AppFormatters.currency(bill.balanceDue)}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error.withValues(alpha: 0.9))),
              ],
            ]),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(bill.status.name.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
        ])));
  }

  void _showBillDetail(BuildContext context, Bill bill) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.receipt_long, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(bill.billNumber),
      ]),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _detailRow('Customer', bill.customerName ?? 'Walk-in'),
          _detailRow('Date', AppFormatters.dateTime(bill.createdAt)),
          _detailRow('Payment', AppFormatters.paymentMethod(bill.paymentMethod.name)),
          const Divider(height: 20),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...bill.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: Text('${item.itemName} × ${item.quantity}', style: const TextStyle(fontSize: 13))),
              Text(AppFormatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]))),
          const Divider(height: 20),
          _detailRow('Subtotal', AppFormatters.currency(bill.subtotal)),
          if (bill.discount > 0) _detailRow('Discount', '- ${AppFormatters.currency(bill.discount)}'),
          _detailRow('GST', AppFormatters.currency(bill.totalTax)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(AppFormatters.currency(bill.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
          ]),
          if (bill.status != BillStatus.paid) ...[
            const SizedBox(height: 8),
            _detailRow('Paid', AppFormatters.currency(bill.paidAmount)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Balance Due', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
              Text(AppFormatters.currency(bill.balanceDue),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
            ]),
          ],
        ]))),
      actions: [
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          _confirmDelete(context, bill);
        }, child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          _showEditBill(context, bill);
        }, child: const Text('Edit')),
        if (bill.status != BillStatus.paid)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.pop(ctx);
              _showCollectPayment(context, bill);
            },
            icon: const Icon(Icons.payments, size: 18),
            label: const Text('Collect Payment'),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final appState = context.read<AppState>();
            final settings = await appState.getAllSettings();
            final template = _parseTemplate(settings['pdf_template']);
            final paperSize = _parsePaperSize(settings['pdf_paper_size']);
            await InvoiceGenerator.generateAndPrint(bill,
              businessName: settings['businessName'] ?? 'My Billu',
              businessAddress: settings['businessAddress'] ?? '',
              businessPhone: settings['businessPhone'] ?? '',
              businessGstin: settings['businessGstin'] ?? '',
              template: template, paperSize: paperSize,
            );
          },
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Print'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          onPressed: () async {
            Navigator.pop(ctx);
            final appState = context.read<AppState>();
            final settings = await appState.getAllSettings();
            final template = _parseTemplate(settings['pdf_template']);
            final paperSize = _parsePaperSize(settings['pdf_paper_size']);
            try {
              await InvoiceGenerator.shareInvoice(bill,
                businessName: settings['businessName'] ?? 'My Billu',
                businessAddress: settings['businessAddress'] ?? '',
                businessPhone: settings['businessPhone'] ?? '',
                businessGstin: settings['businessGstin'] ?? '',
                template: template, paperSize: paperSize,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Share error: $e'), backgroundColor: AppColors.error));
              }
            }
          },
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Share'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
          onPressed: () async {
            Navigator.pop(ctx);
            final appState = context.read<AppState>();
            final settings = await appState.getAllSettings();
            final template = _parseTemplate(settings['pdf_template']);
            final paperSize = _parsePaperSize(settings['pdf_paper_size']);
            try {
              await InvoiceGenerator.emailInvoice(bill,
                businessName: settings['businessName'] ?? 'My Billu',
                businessAddress: settings['businessAddress'] ?? '',
                businessPhone: settings['businessPhone'] ?? '',
                businessGstin: settings['businessGstin'] ?? '',
                template: template, paperSize: paperSize,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Email error: $e'), backgroundColor: AppColors.error));
              }
            }
          },
          icon: const Icon(Icons.email, size: 18),
          label: const Text('Email'),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ));
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]));
  }

  void _confirmDelete(BuildContext context, Bill bill) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Bill?'),
      content: Text('Delete bill ${bill.billNumber}? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () { context.read<AppState>().deleteBill(bill.id); Navigator.pop(ctx); },
          child: const Text('Delete')),
      ],
    ));
  }

  Future<void> _exportBills(BuildContext context, List<Bill> bills) async {
    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bills to export')),
      );
      return;
    }
    try {
      await ExcelExporter.exportBills(bills);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Bills exported successfully!'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCollectPayment(BuildContext context, Bill bill) {
    final amountCtrl = TextEditingController(text: bill.balanceDue.toStringAsFixed(2));
    String paymentType = 'cash';
    String? selectedBankId;
    final appState = context.read<AppState>();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setPayState) {
      final bankAccounts = appState.bankAccounts;
      return AlertDialog(
        title: const Row(children: [
          Icon(Icons.payments, color: AppColors.success), SizedBox(width: 10), Text('Collect Payment')]),
        content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _detailRow('Bill', bill.billNumber),
          _detailRow('Customer', bill.customerName ?? 'Walk-in'),
          _detailRow('Total', AppFormatters.currency(bill.totalAmount)),
          _detailRow('Paid', AppFormatters.currency(bill.paidAmount)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Balance Due', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
            Text(AppFormatters.currency(bill.balanceDue),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Payment Amount (\u20b9)',
              prefixIcon: Icon(Icons.currency_rupee),
            )),
          const SizedBox(height: 16),
          // Payment method selection
          Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _payMethodChip('cash', 'Cash', Icons.money, paymentType, (v) => setPayState(() => paymentType = v)),
            _payMethodChip('upi', 'UPI', Icons.phone_android, paymentType, (v) => setPayState(() => paymentType = v)),
            _payMethodChip('bank', 'Bank Transfer', Icons.account_balance, paymentType, (v) => setPayState(() => paymentType = v)),
            _payMethodChip('card', 'Card', Icons.credit_card, paymentType, (v) => setPayState(() => paymentType = v)),
          ]),
          // Bank account picker for non-cash
          if (paymentType != 'cash' && bankAccounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedBankId,
              decoration: const InputDecoration(
                labelText: 'Select Bank Account',
                prefixIcon: Icon(Icons.account_balance),
                isDense: true),
              items: bankAccounts.map((a) => DropdownMenuItem(
                value: a.id,
                child: Text('${a.bankName} - ${a.accountNumber}', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setPayState(() => selectedBankId = v),
            ),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(ctx);
              await appState.collectPayment(
                bill.id, amount,
                paymentType: paymentType,
                bankAccountId: selectedBankId,
              );
              if (mounted) {
                final methodLabel = paymentType == 'cash' ? 'Cash' : paymentType == 'upi' ? 'UPI' : paymentType == 'bank' ? 'Bank Transfer' : 'Card';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                    Expanded(child: Text('\u20b9${amount.toStringAsFixed(2)} collected via $methodLabel for ${bill.billNumber}')),
                  ]),
                  backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Collect'),
          ),
        ],
      );
    }));
  }

  Widget _payMethodChip(String value, String label, IconData icon, String selected, void Function(String) onTap) {
    final isActive = selected == value;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? AppColors.primary : Colors.grey.withValues(alpha: 0.3), width: isActive ? 2 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isActive ? AppColors.primary : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.primary : null)),
        ]),
      ),
    );
  }

  void _showEditBill(BuildContext context, Bill bill) {
    final customerCtrl = TextEditingController(text: bill.customerName ?? '');
    final notesCtrl = TextEditingController(text: bill.notes ?? '');
    final discountCtrl = TextEditingController(text: bill.discount.toStringAsFixed(2));
    final paidCtrl = TextEditingController(text: bill.paidAmount.toStringAsFixed(2));
    String status = bill.status.name;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setEditState) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.edit, color: AppColors.primary), SizedBox(width: 10), Text('Edit Bill')]),
      content: SingleChildScrollView(child: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        _detailRow('Bill No', bill.billNumber),
        const SizedBox(height: 12),
        TextField(controller: customerCtrl,
          decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        TextField(controller: discountCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Discount (\u20b9)', prefixIcon: Icon(Icons.discount))),
        const SizedBox(height: 12),
        TextField(controller: paidCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Paid Amount (\u20b9)', prefixIcon: Icon(Icons.currency_rupee))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: status,
          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag)),
          items: BillStatus.values.map((s) => DropdownMenuItem(value: s.name,
            child: Text(s.name[0].toUpperCase() + s.name.substring(1)))).toList(),
          onChanged: (v) {
            setEditState(() {
              status = v ?? status;
              // Auto-adjust paid amount based on status
              if (status == 'unpaid') {
                paidCtrl.text = '0.00';
              } else if (status == 'paid') {
                final discount = double.tryParse(discountCtrl.text) ?? bill.discount;
                final total = bill.subtotal - discount + bill.totalTax;
                paidCtrl.text = total.toStringAsFixed(2);
              }
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: notesCtrl, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes))),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: () async {
            final discount = double.tryParse(discountCtrl.text) ?? bill.discount;
            final paid = double.tryParse(paidCtrl.text) ?? bill.paidAmount;
            final totalAmount = bill.subtotal - discount + bill.totalTax;
            // Auto-determine status from paid amount if not manually set
            String finalStatus = status;
            if (paid <= 0) {
              finalStatus = 'unpaid';
            } else if (paid >= totalAmount) {
              finalStatus = 'paid';
            } else if (paid > 0 && paid < totalAmount) {
              finalStatus = 'partial';
            }
            final updatedBill = Bill(
              id: bill.id,
              billNumber: bill.billNumber,
              customerId: bill.customerId,
              customerName: customerCtrl.text.trim().isEmpty ? null : customerCtrl.text.trim(),
              items: bill.items,
              subtotal: bill.subtotal,
              discount: discount,
              totalTax: bill.totalTax,
              totalAmount: totalAmount,
              paidAmount: paid,
              paymentMethod: bill.paymentMethod,
              status: BillStatus.values.firstWhere((e) => e.name == finalStatus, orElse: () => bill.status),
              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              createdAt: bill.createdAt,
            );
            Navigator.pop(ctx);
            await context.read<AppState>().updateBillRecord(updatedBill);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                  Text('Bill ${bill.billNumber} updated'),
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
    )));
  }

  InvoiceTemplate _parseTemplate(String? value) {
    switch (value) {
      case 'classic': return InvoiceTemplate.classic;
      case 'minimal': return InvoiceTemplate.minimal;
      case 'gstInvoice': return InvoiceTemplate.gstInvoice;
      default: return InvoiceTemplate.modern;
    }
  }

  PaperSize _parsePaperSize(String? value) {
    switch (value) {
      case 'a5': return PaperSize.a5;
      default: return PaperSize.a4;
    }
  }
}
