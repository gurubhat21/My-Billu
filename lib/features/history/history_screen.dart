import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
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
              (b.customerName ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Column(children: [
          Padding(padding: EdgeInsets.all(isWide ? 24 : 16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bill History', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              TextField(onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(hintText: 'Search bills...', prefixIcon: Icon(Icons.search, color: AppColors.primary))),
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
          _detailRow('GST', AppFormatters.currency(bill.totalTax)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(AppFormatters.currency(bill.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
          ]),
        ]))),
      actions: [
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          _confirmDelete(context, bill);
        }, child: const Text('Delete', style: TextStyle(color: AppColors.error))),
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
}
