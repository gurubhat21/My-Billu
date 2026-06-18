import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../core/models/credit_note.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_generator.dart';
import '../../widgets/common_widgets.dart';

class CreditNoteScreen extends StatefulWidget {
  const CreditNoteScreen({super.key});
  @override
  State<CreditNoteScreen> createState() => _CreditNoteScreenState();
}

class _CreditNoteScreenState extends State<CreditNoteScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final all = appState.creditNotes;
    final filtered = _search.isEmpty ? all
        : all.where((cn) =>
            cn.creditNoteNumber.toLowerCase().contains(_search.toLowerCase()) ||
            (cn.customerName ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

    final totalNotes = all.length;
    final totalAmount = all.fold<double>(0, (s, cn) => s + cn.totalAmount);
    final totalItems = all.fold<int>(0, (s, cn) => s + cn.items.fold<int>(0, (q, i) => q + i.quantity));

    return Column(children: [
      // Header
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
        Expanded(child: Text('Credit Notes', style: Theme.of(context).textTheme.headlineLarge)),
        SizedBox(width: 220, child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search...', prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        )),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: () => _showCreateDialog(context, appState),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Credit Note')),
      ])),
      const SizedBox(height: 12),
      // Summary Cards
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _summaryChip('Total Notes', '$totalNotes', Icons.assignment_return, AppColors.accent),
          _summaryChip('Items Returned', '$totalItems', Icons.inventory_2, AppColors.warning),
          _summaryChip('Credit Value', AppFormatters.currency(totalAmount), Icons.currency_rupee, AppColors.success),
        ]),
      )),
      const SizedBox(height: 12),
      // List
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('No credit notes yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _buildCreditNoteCard(context, filtered[i], appState),
          )),
    ]);
  }

  Widget _summaryChip(String label, String value, IconData icon, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.5))),
    ]);
  }

  Widget _buildCreditNoteCard(BuildContext context, CreditNote cn, AppState appState) {
    final statusColor = cn.status == CreditNoteStatus.issued ? AppColors.warning
        : cn.status == CreditNoteStatus.adjusted ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: () => _showDetailDialog(context, cn, appState),
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.assignment_return, color: statusColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(cn.creditNoteNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(cn.status.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor))),
          ]),
          const SizedBox(height: 3),
          Text(cn.customerName ?? 'Walk-in', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
          if (cn.billNumber != null) Text('Against: ${cn.billNumber}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(AppFormatters.currency(cn.totalAmount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: statusColor)),
          const SizedBox(height: 2),
          Text('${cn.items.length} items', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
          Text(AppFormatters.date(cn.createdAt), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        ]),
      ]),
    )));
  }

  Bill _toBill(CreditNote cn) => Bill(id: cn.id, billNumber: cn.creditNoteNumber, customerName: cn.customerName,
    items: cn.items, subtotal: cn.subtotal, totalTax: cn.totalTax, totalAmount: cn.totalAmount, createdAt: cn.createdAt);

  // ===== DETAIL DIALOG =====
  void _showDetailDialog(BuildContext context, CreditNote cn, AppState appState) {
    var selectedTemplate = 'GST Invoice';
    var selectedSize = 'A4';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      return AlertDialog(
        title: Row(children: [
          const Icon(Icons.assignment_return, color: AppColors.success, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cn.creditNoteNumber, style: const TextStyle(fontSize: 16)),
            Text('CREDIT NOTE', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1)),
          ])),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
        ]),
        content: SizedBox(width: 580, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Customer', cn.customerName ?? 'Walk-in'),
          if (cn.billNumber != null) _infoRow('Against Invoice', cn.billNumber!),
          _infoRow('Date', AppFormatters.dateTime(cn.createdAt)),
          _infoRow('Status', cn.status.name.toUpperCase()),
          _infoRow('Reason', cn.reason),
          if (cn.notes != null && cn.notes!.isNotEmpty) _infoRow('Notes', cn.notes!),
          const Divider(height: 20),
          // Items table
          const Text('Credit Items:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                child: const Row(children: [
                  Expanded(flex: 3, child: Text('Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                  Expanded(child: Text('Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                  Expanded(child: Text('Tax', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                  Expanded(child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                ]),
              ),
              ...cn.items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(item.itemName, style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text('${item.quantity}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(child: Text(AppFormatters.currency(item.unitPrice), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                  Expanded(child: Text('${item.taxRate}%', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)), textAlign: TextAlign.right)),
                  Expanded(child: Text(AppFormatters.currency(item.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Subtotal: ${AppFormatters.currency(cn.subtotal)}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              Text('Tax: ${AppFormatters.currency(cn.totalTax)}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 4),
              Text('Total: ${AppFormatters.currency(cn.totalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success)),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: selectedSize,
              decoration: const InputDecoration(labelText: 'Paper', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: ['A4', 'A5'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setDialogState(() => selectedSize = v ?? 'A4'))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: DropdownButtonFormField<String>(value: selectedTemplate,
              decoration: const InputDecoration(labelText: 'Template', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: ['Modern', 'Classic', 'Minimal', 'GST Invoice', 'Simple'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setDialogState(() => selectedTemplate = v ?? 'GST Invoice'))),
          ]),
        ]))),
        actions: [
          TextButton.icon(icon: const Icon(Icons.edit, size: 16), label: const Text('Edit'),
            onPressed: () { Navigator.pop(ctx); _showEditDialog(context, cn, appState); }),
          TextButton.icon(icon: const Icon(Icons.visibility, size: 16), label: const Text('Preview'),
            onPressed: () { Navigator.pop(ctx); _openPreview(context, cn, appState, selectedTemplate, selectedSize); }),
          TextButton.icon(icon: const Icon(Icons.print, size: 16), label: const Text('Print'),
            onPressed: () => _printCreditNote(cn, appState, selectedTemplate, selectedSize)),
          TextButton.icon(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error), label: const Text('Delete', style: TextStyle(color: AppColors.error)),
            onPressed: () async {
              final ok = await showDialog<bool>(context: ctx, builder: (c) => AlertDialog(
                title: const Text('Delete Credit Note?'), content: const Text('Stock and customer balance will be reversed. This cannot be undone.'),
                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
              ));
              if (ok == true) { await appState.deleteCreditNote(cn.id); if (ctx.mounted) Navigator.pop(ctx); }
            }),
        ],
      );
    }));
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  InvoiceTemplate _parseTemplate(String name) {
    switch (name) { case 'Modern': return InvoiceTemplate.modern; case 'Classic': return InvoiceTemplate.classic;
      case 'Minimal': return InvoiceTemplate.minimal; case 'Simple': return InvoiceTemplate.simple; default: return InvoiceTemplate.gstInvoice; }
  }
  PaperSize _parsePaperSize(String name) => name == 'A5' ? PaperSize.a5 : PaperSize.a4;

  // ===== EDIT =====
  void _showEditDialog(BuildContext context, CreditNote cn, AppState appState) {
    final reasonCtrl = TextEditingController(text: cn.reason);
    final notesCtrl = TextEditingController(text: cn.notes ?? '');
    var status = cn.status;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      return AlertDialog(
        title: Text('Edit ${cn.creditNoteNumber}'),
        content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<CreditNoteStatus>(value: status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            items: CreditNoteStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
            onChanged: (v) => setDialogState(() => status = v ?? status)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            await appState.updateCreditNote(CreditNote(
              id: cn.id, creditNoteNumber: cn.creditNoteNumber, billId: cn.billId, billNumber: cn.billNumber,
              customerId: cn.customerId, customerName: cn.customerName,
              items: cn.items, subtotal: cn.subtotal, totalTax: cn.totalTax, totalAmount: cn.totalAmount,
              reason: reasonCtrl.text.trim(), notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              status: status, createdAt: cn.createdAt));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('Save')),
        ],
      );
    }));
  }

  // ===== PREVIEW =====
  Future<void> _openPreview(BuildContext context, CreditNote cn, AppState appState, String tpl, String sz) async {
    final s = await appState.getAllSettings();
    final logo = InvoiceGenerator.parseLogoData(s['businessLogoData']);
    final seal = InvoiceGenerator.parseLogoData(s['businessSealData']);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CNPreviewPage(
        bill: _toBill(cn), docTitle: 'CREDIT NOTE', docNumber: cn.creditNoteNumber, reason: cn.reason,
        businessName: s['businessName'] ?? 'My Billu', businessAddress: s['businessAddress'] ?? '',
        businessPhone: s['businessPhone'] ?? '', businessGstin: s['businessGstin'] ?? '',
        businessBankName: s['businessBankName'] ?? '', businessBankAccount: s['businessBankAccount'] ?? '',
        businessBankIfsc: s['businessBankIfsc'] ?? '', businessUpiId: s['businessUpiId'] ?? '',
        logoBytes: logo, sealBytes: seal, template: _parseTemplate(tpl), paperSize: _parsePaperSize(sz),
      )));
    }
  }

  // ===== PRINT =====
  Future<void> _printCreditNote(CreditNote cn, AppState appState, String tpl, String sz) async {
    final s = await appState.getAllSettings();
    await InvoiceGenerator.generateAndPrint(_toBill(cn),
      businessName: s['businessName'] ?? 'My Billu', businessAddress: s['businessAddress'] ?? '',
      businessPhone: s['businessPhone'] ?? '', businessGstin: s['businessGstin'] ?? '',
      businessBankName: s['businessBankName'] ?? '', businessBankAccount: s['businessBankAccount'] ?? '',
      businessBankIfsc: s['businessBankIfsc'] ?? '', businessUpiId: s['businessUpiId'] ?? '',
      logoBytes: InvoiceGenerator.parseLogoData(s['businessLogoData']), sealBytes: InvoiceGenerator.parseLogoData(s['businessSealData']),
      template: _parseTemplate(tpl), paperSize: _parsePaperSize(sz),
      documentTitle: 'CREDIT NOTE', thankYouMessage: 'Thank you......visit again.', termsConditions: cn.reason);
  }

  // ===== CREATE =====
  void _showCreateDialog(BuildContext context, AppState appState) {
    Bill? selectedBill;
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final selectedFlags = <int, bool>{};
    final returnQtys = <int, int>{};

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final allBills = appState.bills;
      double returnTotal = 0;
      if (selectedBill != null) {
        for (int idx = 0; idx < selectedBill!.items.length; idx++) {
          if (selectedFlags[idx] == true) {
            final item = selectedBill!.items[idx];
            final qty = returnQtys[idx] ?? 1;
            returnTotal += item.unitPrice * (1 + item.taxRate / 100) * qty;
          }
        }
      }
      final hasSelection = selectedFlags.values.any((v) => v == true);

      return AlertDialog(
        title: const Text('Create Credit Note'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Autocomplete<Bill>(
            displayStringForOption: (b) => '${b.billNumber} - ${b.customerName ?? "Walk-in"} (${AppFormatters.currency(b.totalAmount)})',
            optionsBuilder: (tv) {
              final q = tv.text.toLowerCase();
              if (q.isEmpty) return allBills;
              return allBills.where((b) => b.billNumber.toLowerCase().contains(q) || (b.customerName ?? '').toLowerCase().contains(q));
            },
            onSelected: (b) => setDialogState(() { selectedBill = b; selectedFlags.clear(); returnQtys.clear(); }),
            fieldViewBuilder: (ctx, ctrl, fn, os) => TextField(controller: ctrl, focusNode: fn,
              decoration: InputDecoration(labelText: 'Search Invoice (No./Customer)', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: selectedBill != null ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { ctrl.clear(); setDialogState(() { selectedBill = null; selectedFlags.clear(); returnQtys.clear(); }); }) : null),
              onChanged: (_) { if (selectedBill != null) setDialogState(() { selectedBill = null; selectedFlags.clear(); returnQtys.clear(); }); }),
          ),
          if (selectedBill != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                Expanded(child: Text('${selectedBill!.billNumber} · ${selectedBill!.customerName ?? "Walk-in"} · ${AppFormatters.currency(selectedBill!.totalAmount)}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))),
              ]),
            ),
            const SizedBox(height: 10),
            const Align(alignment: Alignment.centerLeft, child: Text('Select items to return:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            const SizedBox(height: 4),
            ...selectedBill!.items.asMap().entries.map((e) {
              final idx = e.key; final item = e.value;
              final isSelected = selectedFlags[idx] == true;
              return Card(margin: const EdgeInsets.symmetric(vertical: 3), child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  Checkbox(value: isSelected, onChanged: (v) => setDialogState(() {
                    selectedFlags[idx] = v ?? false;
                    if (v == true && !returnQtys.containsKey(idx)) returnQtys[idx] = 1;
                  })),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${AppFormatters.currency(item.unitPrice)} × ${item.quantity} ${item.unit} = ${AppFormatters.currency(item.total)}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  ])),
                  if (isSelected) SizedBox(width: 70, child: TextFormField(
                    initialValue: (returnQtys[idx] ?? 1).toString(),
                    keyboardType: TextInputType.number, textAlign: TextAlign.center,
                    decoration: InputDecoration(labelText: 'Qty', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    onChanged: (v) { final p = int.tryParse(v) ?? 0; setDialogState(() => returnQtys[idx] = p.clamp(1, item.quantity)); },
                  )),
                ]),
              ));
            }),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Credit Total:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(AppFormatters.currency(returnTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.success)),
              ])),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder()),
              onChanged: (_) => setDialogState(() {})),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: selectedBill != null && hasSelection && reasonCtrl.text.trim().isNotEmpty ? () async {
            final returnItems = <BillItem>[];
            for (int idx = 0; idx < selectedBill!.items.length; idx++) {
              if (selectedFlags[idx] == true) {
                final orig = selectedBill!.items[idx];
                final qty = (returnQtys[idx] ?? 1).clamp(1, orig.quantity);
                returnItems.add(BillItem(itemId: orig.itemId, itemName: orig.itemName, unitPrice: orig.unitPrice, quantity: qty,
                  taxRate: orig.taxRate, unit: orig.unit, description: orig.description, serialNumber: orig.serialNumber));
              }
            }
            final sub = returnItems.fold<double>(0, (s, i) => s + i.subtotal);
            final tax = returnItems.fold<double>(0, (s, i) => s + i.taxAmount);
            await appState.addCreditNote(CreditNote(
              creditNoteNumber: appState.getNextCreditNoteNumber(),
              billId: selectedBill!.id, billNumber: selectedBill!.billNumber,
              customerId: selectedBill!.customerId, customerName: selectedBill!.customerName,
              items: returnItems, subtotal: sub, totalTax: tax, totalAmount: sub + tax,
              reason: reasonCtrl.text.trim(), notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim()));
            if (ctx.mounted) Navigator.pop(ctx);
          } : null, child: const Text('Create')),
        ],
      );
    }));
  }
}

// ===== PREVIEW PAGE =====
class _CNPreviewPage extends StatefulWidget {
  final Bill bill; final String docTitle, docNumber, reason;
  final String businessName, businessAddress, businessPhone, businessGstin;
  final String businessBankName, businessBankAccount, businessBankIfsc, businessUpiId;
  final Uint8List? logoBytes, sealBytes;
  final InvoiceTemplate template; final PaperSize paperSize;
  const _CNPreviewPage({required this.bill, required this.docTitle, required this.docNumber, required this.reason,
    required this.businessName, required this.businessAddress, required this.businessPhone, required this.businessGstin,
    required this.businessBankName, required this.businessBankAccount, required this.businessBankIfsc, required this.businessUpiId,
    this.logoBytes, this.sealBytes, required this.template, required this.paperSize});
  @override State<_CNPreviewPage> createState() => _CNPreviewPageState();
}

class _CNPreviewPageState extends State<_CNPreviewPage> {
  Uint8List? _pdfBytes; bool _loading = true;
  @override void initState() { super.initState(); _gen(); }
  Future<void> _gen() async {
    final bytes = await InvoiceGenerator.generatePdfBytes(widget.bill,
      businessName: widget.businessName, businessAddress: widget.businessAddress,
      businessPhone: widget.businessPhone, businessGstin: widget.businessGstin,
      businessBankName: widget.businessBankName, businessBankAccount: widget.businessBankAccount,
      businessBankIfsc: widget.businessBankIfsc, businessUpiId: widget.businessUpiId,
      logoBytes: widget.logoBytes, sealBytes: widget.sealBytes,
      template: widget.template, paperSize: widget.paperSize,
      documentTitle: widget.docTitle, thankYouMessage: 'Thank you......visit again.', termsConditions: widget.reason);
    if (mounted) setState(() { _pdfBytes = bytes; _loading = false; });
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.docTitle} - ${widget.docNumber}'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: _pdfBytes == null ? null : () async => await Printing.layoutPdf(onLayout: (_) async => _pdfBytes!),
          icon: const Icon(Icons.print, size: 18), label: const Text('Print')))]),
      body: _loading ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Generating preview...')]))
          : _pdfBytes != null ? PdfPreview(build: (_) async => _pdfBytes!, allowSharing: true, allowPrinting: true,
              canChangePageFormat: false, canChangeOrientation: false, canDebug: false, pdfFileName: '${widget.docTitle}_${widget.docNumber}.pdf')
          : const Center(child: Text('Error generating preview')));
  }
}
