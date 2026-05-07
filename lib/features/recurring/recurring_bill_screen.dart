import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/recurring_bill.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class RecurringBillScreen extends StatefulWidget {
  const RecurringBillScreen({super.key});
  @override
  State<RecurringBillScreen> createState() => _RecurringBillScreenState();
}

class _RecurringBillScreenState extends State<RecurringBillScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-process due recurring bills on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppState>();
      final count = await appState.processRecurringBills();
      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $count recurring bill(s) generated!'), backgroundColor: AppColors.success));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = appState.recurringBills;

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [
        Text('Recurring Bills', style: Theme.of(context).textTheme.headlineLarge),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () async {
            final count = await appState.processRecurringBills();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(count > 0 ? '✅ $count bill(s) generated!' : 'No bills due yet'),
                backgroundColor: count > 0 ? AppColors.success : AppColors.primary));
            }
          },
          icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Process Due')),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => _showCreateDialog(context, appState),
          icon: const Icon(Icons.add, size: 18), label: const Text('New Recurring')),
      ])),
      const SizedBox(height: 16),
      Expanded(child: items.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.repeat, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('No recurring bills', style: TextStyle(color: Colors.white.withValues(alpha: 0.3)))]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final rb = items[i];
              final isDue = DateTime.now().isAfter(rb.nextDueDate) && rb.isActive;
              return Padding(padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(padding: const EdgeInsets.all(16), child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
                    color: (rb.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.repeat, color: rb.isActive ? AppColors.success : AppColors.error, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(rb.customerName ?? 'Walk-in', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(rb.frequency.name.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent))),
                      if (isDue) ...[const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text('DUE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.warning)))],
                    ]),
                    const SizedBox(height: 4),
                    Text('${rb.items.length} items • Next: ${AppFormatters.date(rb.nextDueDate)}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  ])),
                  Text(AppFormatters.currency(rb.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 8),
                  Switch(value: rb.isActive, activeColor: AppColors.success,
                    onChanged: (_) => appState.toggleRecurringBill(rb.id)),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    onPressed: () => appState.deleteRecurringBill(rb.id)),
                ])));
            })),
    ]);
  }

  void _showCreateDialog(BuildContext context, AppState appState) {
    final customers = appState.customers;
    String? selectedCustomerId;
    String? selectedCustomerName;
    RecurringFrequency freq = RecurringFrequency.monthly;
    // Use existing bills as template
    Bill? templateBill;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      return AlertDialog(
        title: const Text('New Recurring Bill'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
            isExpanded: true,
            items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setDialogState(() {
              selectedCustomerId = v;
              selectedCustomerName = customers.firstWhere((c) => c.id == v).name;
            })),
          const SizedBox(height: 12),
          DropdownButtonFormField<RecurringFrequency>(
            decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
            value: freq,
            items: RecurringFrequency.values.map((f) => DropdownMenuItem(value: f,
              child: Text(f.name[0].toUpperCase() + f.name.substring(1)))).toList(),
            onChanged: (v) => setDialogState(() => freq = v!)),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft, child: Text('Template from existing bill:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const SizedBox(height: 8),
          DropdownButtonFormField<Bill>(
            decoration: const InputDecoration(labelText: 'Select Bill Template', border: OutlineInputBorder()),
            isExpanded: true,
            items: appState.bills.take(20).map((b) => DropdownMenuItem(value: b,
              child: Text('${b.billNumber} - ${AppFormatters.currency(b.totalAmount)}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (b) => setDialogState(() {
              templateBill = b;
              if (b != null) {
                selectedCustomerId = b.customerId;
                selectedCustomerName = b.customerName;
              }
            })),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: templateBill != null ? () async {
            final now = DateTime.now();
            DateTime nextDue;
            switch (freq) {
              case RecurringFrequency.weekly: nextDue = now.add(const Duration(days: 7));
              case RecurringFrequency.monthly: nextDue = DateTime(now.year, now.month + 1, now.day);
              case RecurringFrequency.quarterly: nextDue = DateTime(now.year, now.month + 3, now.day);
              case RecurringFrequency.yearly: nextDue = DateTime(now.year + 1, now.month, now.day);
            }
            final rb = RecurringBill(
              customerId: selectedCustomerId, customerName: selectedCustomerName,
              items: templateBill!.items, totalAmount: templateBill!.totalAmount,
              frequency: freq, paymentMethod: templateBill!.paymentMethod,
              startDate: now, nextDueDate: nextDue);
            await appState.addRecurringBill(rb);
            if (ctx.mounted) Navigator.pop(ctx);
          } : null, child: const Text('Create')),
        ],
      );
    }));
  }
}
