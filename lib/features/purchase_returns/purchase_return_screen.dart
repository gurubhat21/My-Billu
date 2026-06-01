import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/purchase_return.dart';
import '../../core/models/purchase.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class PurchaseReturnScreen extends StatefulWidget {
  const PurchaseReturnScreen({super.key});
  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final filtered = _search.isEmpty ? appState.purchaseReturns
        : appState.purchaseReturns.where((pr) =>
            pr.returnNumber.toLowerCase().contains(_search.toLowerCase()) ||
            pr.supplierName.toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Wrap(
        spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceBetween, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Purchase Returns', style: Theme.of(context).textTheme.headlineLarge),
        ]),
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
            label: const Text('New Return')),
        ]),
      ])),
      const SizedBox(height: 16),
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.keyboard_return, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('No purchase returns yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _buildReturnCard(context, filtered[i], appState),
          )),
    ]);
  }

  Widget _buildReturnCard(BuildContext context, PurchaseReturn pr, AppState appState) {
    final statusColor = pr.status == PurchaseReturnStatus.returned ? AppColors.warning
        : pr.status == PurchaseReturnStatus.refunded ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.keyboard_return, color: statusColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(pr.returnNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(pr.status.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor))),
          ]),
          const SizedBox(height: 4),
          Text(pr.supplierName, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
          if (pr.purchaseNumber != null) Text('Against: ${pr.purchaseNumber}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          Text('Reason: ${pr.reason}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(AppFormatters.currency(pr.totalAmount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: statusColor)),
          const SizedBox(height: 4),
          Text(AppFormatters.date(pr.createdAt), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        ]),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Return?'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
            ));
            if (ok == true) await appState.deletePurchaseReturn(pr.id);
          }),
      ]),
    ));
  }

  void _showCreateDialog(BuildContext context, AppState appState) {
    Purchase? selectedPurchase;
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final selectedItems = <PurchaseItem>[];

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      final allPurchases = appState.purchases.where((p) => p.status == PurchaseStatus.received).toList();
      return AlertDialog(
        title: const Text('Create Purchase Return'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Purchase>(
            decoration: const InputDecoration(labelText: 'Select Purchase', border: OutlineInputBorder()),
            isExpanded: true,
            items: allPurchases.map((p) => DropdownMenuItem(value: p,
              child: Text('${p.purchaseNumber} - ${p.supplierName} (${AppFormatters.currency(p.totalAmount)})', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (p) => setDialogState(() {
              selectedPurchase = p;
              selectedItems.clear();
              if (p != null) selectedItems.addAll(p.items);
            }),
          ),
          if (selectedPurchase != null) ...[
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Return Items:', style: TextStyle(fontWeight: FontWeight.w600))),
            ...selectedPurchase!.items.map((item) {
              final isSelected = selectedItems.contains(item);
              return CheckboxListTile(
                dense: true, controlAffinity: ListTileControlAffinity.leading,
                title: Text('${item.itemName} (${item.quantity} ${item.unit})', style: const TextStyle(fontSize: 13)),
                subtitle: Text(AppFormatters.currency(item.total), style: const TextStyle(fontSize: 11)),
                value: isSelected,
                onChanged: (v) => setDialogState(() => v == true ? selectedItems.add(item) : selectedItems.remove(item)),
              );
            }),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: selectedPurchase != null && selectedItems.isNotEmpty && reasonCtrl.text.trim().isNotEmpty ? () async {
            final sub = selectedItems.fold<double>(0, (s, i) => s + i.subtotal);
            final tax = selectedItems.fold<double>(0, (s, i) => s + i.taxAmount);
            final pr = PurchaseReturn(
              returnNumber: appState.getNextPurchaseReturnNumber(),
              purchaseId: selectedPurchase!.id, purchaseNumber: selectedPurchase!.purchaseNumber,
              supplierName: selectedPurchase!.supplierName,
              items: selectedItems, subtotal: sub, totalTax: tax, totalAmount: sub + tax,
              reason: reasonCtrl.text.trim(), notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            );
            await appState.addPurchaseReturn(pr);
            if (ctx.mounted) Navigator.pop(ctx);
          } : null, child: const Text('Create')),
        ],
      );
    }));
  }
}


