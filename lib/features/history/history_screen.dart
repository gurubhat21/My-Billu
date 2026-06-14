import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/models/customer.dart';
import '../../core/models/item.dart';
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

  void _showBillDetail(BuildContext context, Bill bill) async {
    final appState = context.read<AppState>();
    final settings = await appState.getAllSettings();
    String selectedSize = settings['pdf_paper_size'] ?? 'a4';
    String selectedTemplate = settings['pdf_template'] ?? 'modern';

    if (!context.mounted) return;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.receipt_long, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(bill.billNumber),
      ]),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _detailRow('Customer', bill.customerName ?? 'Walk-in'),
          if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
            _detailRow('Phone', bill.customerPhone!),
          // Save walk-in customer to customers list
          if (bill.customerName != null && bill.customerName!.isNotEmpty && bill.customerId == null)
            Builder(builder: (_) {
              final existingCustomer = appState.customers.any((c) =>
                c.name.toLowerCase() == bill.customerName!.toLowerCase() ||
                (bill.customerPhone != null && bill.customerPhone!.isNotEmpty && c.phone == bill.customerPhone));
              if (existingCustomer) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () async {
                    final customer = Customer(
                      name: bill.customerName!,
                      phone: bill.customerPhone,
                    );
                    await appState.addCustomer(customer);
                    // Link this bill to the new customer
                    final updatedBill = Bill(
                      id: bill.id, billNumber: bill.billNumber,
                      customerId: customer.id,
                      customerName: bill.customerName,
                      customerPhone: bill.customerPhone,
                      items: bill.items, subtotal: bill.subtotal,
                      discount: bill.discount, totalTax: bill.totalTax,
                      totalAmount: bill.totalAmount, paidAmount: bill.paidAmount,
                      paymentMethod: bill.paymentMethod, status: bill.status,
                      notes: bill.notes, createdAt: bill.createdAt,
                    );
                    await appState.updateBillRecord(updatedBill);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                          Text('${bill.customerName} added to Customers list'),
                        ]),
                        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  icon: const Icon(Icons.person_add, size: 16, color: AppColors.success),
                  label: const Text('Save to Customers', style: TextStyle(fontSize: 12, color: AppColors.success)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.success.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              );
            }),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx, initialDate: bill.createdAt,
                firstDate: DateTime(2020), lastDate: DateTime(2030),
              );
              if (picked != null) {
                bill.createdAt = DateTime(picked.year, picked.month, picked.day, bill.createdAt.hour, bill.createdAt.minute);
                await context.read<AppState>().updateBillRecord(bill);
                setDialogState(() {});
              }
            },
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Text('Date: ', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                Text(AppFormatters.dateTime(bill.createdAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 6),
                Icon(Icons.edit_calendar, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
              ]),
            ),
          ),
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
          _detailRow('Total', AppFormatters.currency(bill.totalAmount)),
          if (bill.paidAmount > 0) ...[
            _detailRow('Paid', AppFormatters.currency(bill.paidAmount)),
            Row(children: [
              Text('Balance Due: ', style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
              Text(AppFormatters.currency(bill.balanceDue),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
            ]),
          ],

          const SizedBox(height: 16),
          // Paper size selector
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.description, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Paper: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              _sizeToggle('A4', 'a4', selectedSize, (v) async {
                setDialogState(() => selectedSize = v);
                await appState.saveSetting('pdf_paper_size', v);
              }),
              const SizedBox(width: 6),
              _sizeToggle('A5', 'a5', selectedSize, (v) async {
                setDialogState(() => selectedSize = v);
                await appState.saveSetting('pdf_paper_size', v);
              }),
            ]),
          ),
          const SizedBox(height: 8),
          // Template selector
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.style, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Template: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ...[
                  ('Modern', 'modern'),
                  ('Classic', 'classic'),
                  ('Minimal', 'minimal'),
                  ('GST', 'gstInvoice'),
                  ('Simple', 'simple'),
                ].map((t) => InkWell(
                  onTap: () async {
                    setDialogState(() => selectedTemplate = t.$2);
                    await appState.saveSetting('pdf_template', t.$2);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selectedTemplate == t.$2 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selectedTemplate == t.$2 ? AppColors.primary : Colors.grey.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(t.$1, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: selectedTemplate == t.$2 ? Colors.white : Colors.grey,
                    )),
                  ),
                )),
              ]),
            ]),
          ),
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
            final s = await appState.getAllSettings();
            final template = _parseTemplate(selectedTemplate);
            final paperSize = _parsePaperSize(selectedSize);
            final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
            final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);
            if (context.mounted) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _HistoryBillPreviewPage(
                  bill: bill,
                  businessName: s['businessName'] ?? 'My Billu',
                  businessAddress: s['businessAddress'] ?? '',
                  businessPhone: s['businessPhone'] ?? '',
                  businessGstin: s['businessGstin'] ?? '',
                  businessBankName: s['businessBankName'] ?? '',
                  businessBankAccount: s['businessBankAccount'] ?? '',
                  businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
                  logoBytes: logoBytes, sealBytes: sealBytes,
                  template: template,
                  paperSize: paperSize,
                  thankYouMessage: s['pdf_thank_you_message'],
                  termsConditions: s['pdf_terms_conditions'],
                ),
              ));
            }
          },
          icon: const Icon(Icons.visibility, size: 18),
          label: const Text('Preview'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final s = await appState.getAllSettings();
            final template = _parseTemplate(selectedTemplate);
            final paperSize = _parsePaperSize(selectedSize);
            final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
            final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);
            await InvoiceGenerator.generateAndPrint(bill,
              businessName: s['businessName'] ?? 'My Billu',
              businessAddress: s['businessAddress'] ?? '',
              businessPhone: s['businessPhone'] ?? '',
              businessGstin: s['businessGstin'] ?? '',
              businessBankName: s['businessBankName'] ?? '',
              businessBankAccount: s['businessBankAccount'] ?? '',
              businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
              logoBytes: logoBytes, sealBytes: sealBytes,
              template: template, paperSize: paperSize,
              thankYouMessage: s['pdf_thank_you_message'],
              termsConditions: s['pdf_terms_conditions'],
            );
          },
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Print'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final s = await appState.getAllSettings();
            final template = _parseTemplate(selectedTemplate);
            final paperSize = _parsePaperSize(selectedSize);
            final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
            final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);
            try {
              final savedPath = await InvoiceGenerator.savePdfToFile(bill,
                businessName: s['businessName'] ?? 'My Billu',
                businessAddress: s['businessAddress'] ?? '',
                businessPhone: s['businessPhone'] ?? '',
                businessGstin: s['businessGstin'] ?? '',
                businessBankName: s['businessBankName'] ?? '',
                businessBankAccount: s['businessBankAccount'] ?? '',
                businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
                logoBytes: logoBytes, sealBytes: sealBytes,
                template: template, paperSize: paperSize,
                thankYouMessage: s['pdf_thank_you_message'],
                termsConditions: s['pdf_terms_conditions'],
                savePath: s['pdf_save_path'],
              );
              if (context.mounted) {
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Save error: $e'), backgroundColor: AppColors.error));
              }
            }
          },
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save PDF'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          onPressed: () async {
            Navigator.pop(ctx);
            final s = await appState.getAllSettings();
            final template = _parseTemplate(selectedTemplate);
            final paperSize = _parsePaperSize(selectedSize);
            final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
            final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);
            try {
              await InvoiceGenerator.shareInvoice(bill,
                businessName: s['businessName'] ?? 'My Billu',
                businessAddress: s['businessAddress'] ?? '',
                businessPhone: s['businessPhone'] ?? '',
                businessGstin: s['businessGstin'] ?? '',
                businessBankName: s['businessBankName'] ?? '',
                businessBankAccount: s['businessBankAccount'] ?? '',
                businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
                logoBytes: logoBytes, sealBytes: sealBytes,
                template: template, paperSize: paperSize,
                thankYouMessage: s['pdf_thank_you_message'],
                termsConditions: s['pdf_terms_conditions'],
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          onPressed: () async {
            Navigator.pop(ctx);
            final s = await appState.getAllSettings();
            final template = _parseTemplate(selectedTemplate);
            final paperSize = _parsePaperSize(selectedSize);
            final logoBytes = InvoiceGenerator.parseLogoData(s['businessLogoData']);
            final sealBytes = InvoiceGenerator.parseLogoData(s['businessSealData']);
            try {
              await InvoiceGenerator.shareViaWhatsApp(bill,
                customerPhone: bill.customerPhone,
                businessName: s['businessName'] ?? 'My Billu',
                businessAddress: s['businessAddress'] ?? '',
                businessPhone: s['businessPhone'] ?? '',
                businessGstin: s['businessGstin'] ?? '',
                businessBankName: s['businessBankName'] ?? '',
                businessBankAccount: s['businessBankAccount'] ?? '',
                businessBankIfsc: s['businessBankIfsc'] ?? '',
              businessUpiId: s['businessUpiId'] ?? '',
                logoBytes: logoBytes, sealBytes: sealBytes,
                template: template, paperSize: paperSize,
                thankYouMessage: s['pdf_thank_you_message'],
                termsConditions: s['pdf_terms_conditions'],
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('WhatsApp error: $e'), backgroundColor: AppColors.error));
              }
            }
          },
          icon: const Icon(Icons.chat, size: 18),
          label: const Text('WhatsApp'),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    )));
  }

  Widget _sizeToggle(String label, String value, String current, Function(String) onTap) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.primary)),
      ),
    );
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
    final phoneCtrl = TextEditingController(text: bill.customerPhone ?? '');
    final notesCtrl = TextEditingController(text: bill.notes ?? '');
    final discountCtrl = TextEditingController(text: bill.discount.toStringAsFixed(2));
    final paidCtrl = TextEditingController(text: bill.paidAmount.toStringAsFixed(2));
    String status = bill.status.name;
    bool gstInclusive = false;

    // Load saved GST mode
    context.read<AppState>().getSetting('billing_gst_inclusive').then((v) {
      if (v == 'true') {
        gstInclusive = true;
      }
    });

    // Editable copy of items
    final editItems = bill.items.map((i) => <String, dynamic>{
      'itemId': i.itemId, 'itemName': i.itemName, 'unitPrice': i.unitPrice,
      'quantity': i.quantity, 'taxRate': i.taxRate, 'unit': i.unit,
      'description': i.description, 'serialNumber': i.serialNumber,
    }).toList();

    // When GST inclusive, convert stored base prices to inclusive display prices
    if (gstInclusive) {
      for (final item in editItems) {
        final basePrice = item['unitPrice'] as double;
        final rate = item['taxRate'] as double;
        item['unitPrice'] = basePrice * (1 + rate / 100);
      }
    }

    // Create controllers once per item
    final List<List<TextEditingController>> itemCtrls = editItems.map((i) => [
      TextEditingController(text: (i['unitPrice'] as double).toStringAsFixed(2)),
      TextEditingController(text: (i['quantity'] as int).toString()),
      TextEditingController(text: (i['taxRate'] as double).toStringAsFixed(1)),
    ]).toList();

    // When GST exclusive: subtotal = price * qty, tax = subtotal * rate/100
    // When GST inclusive: price already includes GST, so extract it
    double calcSubtotal(bool inclusive) {
      if (inclusive) {
        return editItems.fold(0.0, (s, i) {
          final price = i['unitPrice'] as double;
          final qty = i['quantity'] as int;
          final rate = i['taxRate'] as double;
          final basePrice = price / (1 + rate / 100);
          return s + basePrice * qty;
        });
      }
      return editItems.fold(0.0, (s, i) => s + (i['unitPrice'] as double) * (i['quantity'] as int));
    }
    double calcTax(bool inclusive) {
      if (inclusive) {
        return editItems.fold(0.0, (s, i) {
          final price = i['unitPrice'] as double;
          final qty = i['quantity'] as int;
          final rate = i['taxRate'] as double;
          final basePrice = price / (1 + rate / 100);
          return s + basePrice * qty * rate / 100;
        });
      }
      return editItems.fold(0.0, (s, i) => s + (i['unitPrice'] as double) * (i['quantity'] as int) * (i['taxRate'] as double) / 100);
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setEditState) {
      final subtotal = calcSubtotal(gstInclusive);
      final tax = calcTax(gstInclusive);
      final discount = double.tryParse(discountCtrl.text) ?? 0;
      final total = subtotal - discount + tax;

      return AlertDialog(
        title: const Row(children: [
          Icon(Icons.edit, color: AppColors.primary), SizedBox(width: 10), Text('Edit Bill')]),
        content: SingleChildScrollView(child: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _detailRow('Bill No', bill.billNumber),
          const SizedBox(height: 12),
          TextField(controller: customerCtrl,
            decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          // ===== GST MODE TOGGLE =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: gstInclusive ? AppColors.success.withValues(alpha: 0.08) : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gstInclusive ? AppColors.success.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.receipt_long, size: 18,
                color: gstInclusive ? AppColors.success : AppColors.primary),
              const SizedBox(width: 8),
              Text(gstInclusive ? 'GST Inclusive' : 'GST Exclusive',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                  color: gstInclusive ? AppColors.success : AppColors.primary)),
              const Spacer(),
              Switch(
                value: gstInclusive,
                activeColor: AppColors.success,
                onChanged: (v) async {
                  // Convert prices between inclusive/exclusive when toggle changes
                  for (int idx = 0; idx < editItems.length; idx++) {
                    final price = editItems[idx]['unitPrice'] as double;
                    final rate = editItems[idx]['taxRate'] as double;
                    double newPrice;
                    if (v) {
                      // Switching to inclusive: base → inclusive
                      newPrice = price * (1 + rate / 100);
                    } else {
                      // Switching to exclusive: inclusive → base
                      newPrice = price / (1 + rate / 100);
                    }
                    editItems[idx]['unitPrice'] = newPrice;
                    itemCtrls[idx][0].text = newPrice.toStringAsFixed(2);
                  }
                  setEditState(() => gstInclusive = v);
                  final appState = context.read<AppState>();
                  await appState.saveSetting('billing_gst_inclusive', v.toString());
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ===== ITEMS SECTION =====
          Row(children: [
            const Icon(Icons.shopping_cart, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                final appState = context.read<AppState>();
                _showAddItemDialog(ctx, appState.items, editItems, (fn) {
                  setEditState(() {
                    fn();
                    // Add controllers for new item
                    final newItem = editItems.last;
                    itemCtrls.add([
                      TextEditingController(text: (newItem['unitPrice'] as double).toStringAsFixed(2)),
                      TextEditingController(text: (newItem['quantity'] as int).toString()),
                      TextEditingController(text: (newItem['taxRate'] as double).toStringAsFixed(1)),
                    ]);
                  });
                });
              },
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text('Add Item', style: TextStyle(fontSize: 13)),
            ),
          ]),
          const Divider(height: 8),

          // Item list
          ...editItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final ctrls = itemCtrls[idx];
            final itemSubtotal = (item['unitPrice'] as double) * (item['quantity'] as int);

            return Container(
              key: ValueKey('item_${item['itemId']}_$idx'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(item['itemName'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('₹${itemSubtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setEditState(() {
                      editItems.removeAt(idx);
                      itemCtrls.removeAt(idx);
                    }),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: AppColors.error))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: ctrls[0], keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: gstInclusive ? 'Price (incl. GST)' : 'Price', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    onChanged: (v) {
                      editItems[idx]['unitPrice'] = double.tryParse(v) ?? 0.0;
                      setEditState(() {});
                    })),
                  const SizedBox(width: 8),
                  SizedBox(width: 70, child: TextField(controller: ctrls[1], keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    onChanged: (v) {
                      editItems[idx]['quantity'] = int.tryParse(v) ?? 1;
                      setEditState(() {});
                    })),
                  const SizedBox(width: 8),
                  SizedBox(width: 70, child: TextField(controller: ctrls[2], keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tax%', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    onChanged: (v) {
                      editItems[idx]['taxRate'] = double.tryParse(v) ?? 0.0;
                      setEditState(() {});
                    })),
                ]),
              ]),
            );
          }),

          if (editItems.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No items — add items above', style: TextStyle(color: Colors.grey))),

          const SizedBox(height: 12),
          // Totals
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              _detailRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
              _detailRow('GST${gstInclusive ? ' (Inclusive)' : ''}', '₹${tax.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              Row(children: [
                const Text('Discount', style: TextStyle(fontSize: 13)),
                const Spacer(),
                SizedBox(width: 100, child: TextField(controller: discountCtrl, keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(prefixText: '₹', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  onChanged: (_) => setEditState(() {}))),
              ]),
              const Divider(),
              _detailRow('Total', '₹${total.toStringAsFixed(2)}'),
            ]),
          ),

          const SizedBox(height: 12),
          TextField(controller: paidCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Paid Amount (₹)', prefixIcon: Icon(Icons.currency_rupee)),
            onChanged: (_) => setEditState(() {})),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag)),
            items: BillStatus.values.map((s) => DropdownMenuItem(value: s.name,
              child: Text(s.name[0].toUpperCase() + s.name.substring(1)))).toList(),
            onChanged: (v) {
              setEditState(() {
                status = v ?? status;
                if (status == 'unpaid') paidCtrl.text = '0.00';
                else if (status == 'paid') paidCtrl.text = total.toStringAsFixed(2);
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
            onPressed: editItems.isEmpty ? null : () async {
              // When GST inclusive, store base price (without GST) so BillItem getters calculate correctly
              final billItems = editItems.map((i) {
                double price = i['unitPrice'] as double;
                if (gstInclusive) {
                  final rate = i['taxRate'] as double;
                  price = price / (1 + rate / 100);
                }
                return BillItem(
                  itemId: i['itemId'] as String, itemName: i['itemName'] as String,
                  unitPrice: price, quantity: i['quantity'] as int,
                  taxRate: i['taxRate'] as double, unit: i['unit'] as String? ?? 'pcs',
                  description: i['description'] as String?, serialNumber: i['serialNumber'] as String?,
                );
              }).toList();
              final newSubtotal = billItems.fold(0.0, (s, i) => s + i.subtotal);
              final newTax = billItems.fold(0.0, (s, i) => s + i.taxAmount);
              final newDiscount = double.tryParse(discountCtrl.text) ?? 0;
              final newTotal = newSubtotal - newDiscount + newTax;
              final paid = double.tryParse(paidCtrl.text) ?? bill.paidAmount;
              String finalStatus = status;
              if (paid <= 0) finalStatus = 'unpaid';
              else if (paid >= newTotal) finalStatus = 'paid';
              else finalStatus = 'partial';

              final updatedBill = Bill(
                id: bill.id, billNumber: bill.billNumber, customerId: bill.customerId,
                customerName: customerCtrl.text.trim().isEmpty ? null : customerCtrl.text.trim(),
                customerPhone: phoneCtrl.text.trim().isEmpty ? bill.customerPhone : phoneCtrl.text.trim(),
                items: billItems, subtotal: newSubtotal, discount: newDiscount,
                totalTax: newTax, totalAmount: newTotal, paidAmount: paid,
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
                    Text('Bill ${bill.billNumber} updated — ${billItems.length} items, ₹${newTotal.toStringAsFixed(2)}'),
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

  void _showAddItemDialog(BuildContext ctx, List<Item> allItems, List<Map<String, dynamic>> editItems, Function(VoidCallback) onAddItem) {
    String search = '';
    showDialog(context: ctx, builder: (dCtx) => StatefulBuilder(builder: (dCtx, setAddState) {
      final filtered = search.isEmpty ? allItems
          : allItems.where((i) => i.name.toLowerCase().contains(search.toLowerCase())).toList();
      return AlertDialog(
        title: const Row(children: [
          Icon(Icons.add_shopping_cart, color: AppColors.primary), SizedBox(width: 10), Text('Add Item')]),
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
                leading: const Icon(Icons.inventory_2, size: 20, color: AppColors.primary),
                title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('₹${item.price.toStringAsFixed(2)} • Tax: ${item.taxRate}%', style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.add_circle, color: AppColors.success),
                onTap: () {
                  Navigator.pop(dCtx);
                  onAddItem(() {
                    editItems.add({
                      'itemId': item.id, 'itemName': item.name, 'unitPrice': item.price,
                      'quantity': 1, 'taxRate': item.taxRate, 'unit': item.unit,
                      'description': item.description, 'serialNumber': null,
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

  InvoiceTemplate _parseTemplate(String? value) {
    switch (value) {
      case 'classic': return InvoiceTemplate.classic;
      case 'minimal': return InvoiceTemplate.minimal;
      case 'gstInvoice': return InvoiceTemplate.gstInvoice;
      case 'simple': return InvoiceTemplate.simple;
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

// ========== BILL PREVIEW PAGE (History) ==========

class _HistoryBillPreviewPage extends StatefulWidget {
  final Bill bill;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String businessGstin;
  final String businessBankName;
  final String businessBankAccount;
  final String businessBankIfsc;
  final String businessUpiId;
  final Uint8List? logoBytes;
  final Uint8List? sealBytes;
  final InvoiceTemplate template;
  final PaperSize paperSize;
  final String? thankYouMessage;
  final String? termsConditions;

  const _HistoryBillPreviewPage({
    required this.bill,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.businessGstin,
    required this.businessBankName,
    required this.businessBankAccount,
    required this.businessBankIfsc,
    this.businessUpiId = '',
    this.logoBytes,
    this.sealBytes,
    required this.template,
    required this.paperSize,
    this.thankYouMessage,
    this.termsConditions,
  });

  @override
  State<_HistoryBillPreviewPage> createState() => _HistoryBillPreviewPageState();
}

class _HistoryBillPreviewPageState extends State<_HistoryBillPreviewPage> {
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
      businessUpiId: widget.businessUpiId,
      logoBytes: widget.logoBytes, sealBytes: widget.sealBytes,
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
                  businessUpiId: widget.businessUpiId,
                  logoBytes: widget.logoBytes, sealBytes: widget.sealBytes,
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