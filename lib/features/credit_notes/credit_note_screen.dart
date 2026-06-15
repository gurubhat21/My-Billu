import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/credit_note.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
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
    final filtered = _search.isEmpty ? appState.creditNotes
        : appState.creditNotes.where((cn) =>
            cn.creditNoteNumber.toLowerCase().contains(_search.toLowerCase()) ||
            (cn.customerName ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Wrap(
        spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceBetween, children: [
        Text('Credit Notes', style: Theme.of(context).textTheme.headlineLarge),
        Row(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ])),
      const SizedBox(height: 16),
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

  Widget _buildCreditNoteCard(BuildContext context, CreditNote cn, AppState appState) {
    final statusColor = cn.status == CreditNoteStatus.issued ? AppColors.warning
        : cn.status == CreditNoteStatus.adjusted ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 4),
          Text(cn.customerName ?? 'Walk-in', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
          if (cn.billNumber != null) Text('Against: ${cn.billNumber}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          Text('Reason: ${cn.reason}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(AppFormatters.currency(cn.totalAmount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: statusColor)),
          const SizedBox(height: 4),
          Text(AppFormatters.date(cn.createdAt), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
          Text('${cn.items.length} items', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
        ]),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Credit Note?'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
            ));
            if (ok == true) await appState.deleteCreditNote(cn.id);
          }),
      ]),
    ));
  }

  void _showCreateDialog(BuildContext context, AppState appState) {
    Bill? selectedBill;
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final selectedFlags = <int, bool>{};
    final returnQtys = <int, int>{};

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final allBills = appState.bills;

      // Calculate return total
      double returnTotal = 0;
      if (selectedBill != null) {
        for (int idx = 0; idx < selectedBill!.items.length; idx++) {
          if (selectedFlags[idx] == true) {
            final item = selectedBill!.items[idx];
            final qty = returnQtys[idx] ?? item.quantity;
            final unitTotal = item.unitPrice * (1 + item.taxRate / 100);
            returnTotal += unitTotal * qty;
          }
        }
      }

      final hasSelection = selectedFlags.values.any((v) => v == true);

      return AlertDialog(
        title: const Text('Create Credit Note'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Bill>(
            decoration: const InputDecoration(labelText: 'Select Invoice', border: OutlineInputBorder()),
            isExpanded: true,
            items: allBills.map((b) => DropdownMenuItem(value: b,
              child: Text('${b.billNumber} - ${b.customerName ?? "Walk-in"} (${AppFormatters.currency(b.totalAmount)})', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (b) => setDialogState(() {
              selectedBill = b;
              selectedFlags.clear();
              returnQtys.clear();
              if (b != null) {
                for (int i = 0; i < b.items.length; i++) {
                  selectedFlags[i] = true;
                  returnQtys[i] = b.items[i].quantity;
                }
              }
            }),
          ),
          if (selectedBill != null) ...[
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Return Items:', style: TextStyle(fontWeight: FontWeight.w600))),
            ...selectedBill!.items.asMap().entries.map((e) {
              final idx = e.key;
              final item = e.value;
              final isSelected = selectedFlags[idx] == true;
              final maxQty = item.quantity;
              final currentQty = returnQtys[idx] ?? maxQty;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (v) => setDialogState(() => selectedFlags[idx] = v ?? false),
                    ),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${AppFormatters.currency(item.unitPrice)} × $maxQty ${item.unit} = ${AppFormatters.currency(item.total)}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                    ])),
                    if (isSelected) SizedBox(width: 70, child: TextFormField(
                      initialValue: currentQty.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v) ?? 0;
                        setDialogState(() => returnQtys[idx] = parsed.clamp(1, maxQty));
                      },
                    )),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Credit Total:', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(AppFormatters.currency(returnTotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: selectedBill != null && hasSelection && reasonCtrl.text.trim().isNotEmpty ? () async {
            // Build return items with selected quantities
            final returnItems = <BillItem>[];
            for (int idx = 0; idx < selectedBill!.items.length; idx++) {
              if (selectedFlags[idx] == true) {
                final orig = selectedBill!.items[idx];
                final qty = (returnQtys[idx] ?? orig.quantity).clamp(1, orig.quantity);
                returnItems.add(BillItem(
                  itemId: orig.itemId, itemName: orig.itemName,
                  unitPrice: orig.unitPrice, quantity: qty,
                  taxRate: orig.taxRate, unit: orig.unit,
                  description: orig.description, serialNumber: orig.serialNumber,
                ));
              }
            }
            final sub = returnItems.fold<double>(0, (s, i) => s + i.subtotal);
            final tax = returnItems.fold<double>(0, (s, i) => s + i.taxAmount);
            final cn = CreditNote(
              creditNoteNumber: appState.getNextCreditNoteNumber(),
              billId: selectedBill!.id, billNumber: selectedBill!.billNumber,
              customerId: selectedBill!.customerId, customerName: selectedBill!.customerName,
              items: returnItems, subtotal: sub, totalTax: tax, totalAmount: sub + tax,
              reason: reasonCtrl.text.trim(), notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            );
            await appState.addCreditNote(cn);
            if (ctx.mounted) Navigator.pop(ctx);
          } : null, child: const Text('Create')),
        ],
      );
    }));
  }
}
