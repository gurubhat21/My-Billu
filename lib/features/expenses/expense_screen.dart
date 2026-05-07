import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/expense.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  ExpenseCategory? _catFilter;
  String _period = 'This Month';

  List<Expense> _filter(List<Expense> list) {
    final now = DateTime.now();
    var filtered = list.where((e) {
      if (_period == 'Today') {
        return e.date.day == now.day && e.date.month == now.month && e.date.year == now.year;
      } else if (_period == 'This Week') {
        return e.date.isAfter(now.subtract(const Duration(days: 7)));
      } else if (_period == 'This Month') {
        return e.date.month == now.month && e.date.year == now.year;
      } else if (_period == 'This Year') {
        return e.date.year == now.year;
      }
      return true;
    }).toList();
    if (_catFilter != null) {
      filtered = filtered.where((e) => e.category == _catFilter).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<AppState>(builder: (context, appState, _) {
      final expenses = _filter(appState.expenses);
      final total = expenses.fold<double>(0, (s, e) => s + e.amount);

      // Category breakdown
      final catTotals = <ExpenseCategory, double>{};
      for (final e in expenses) {
        catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
      }
      final sortedCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Column(children: [
          // Header
          Padding(padding: EdgeInsets.all(isWide ? 24 : 16), child: Row(children: [
            Expanded(child: Text('Expense Tracker', style: Theme.of(context).textTheme.headlineLarge)),
            ElevatedButton.icon(
              onPressed: () => _showAddExpense(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Expense'),
            ),
          ])),

          // Period filter
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['Today', 'This Week', 'This Month', 'This Year', 'All Time'].map((p) =>
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                label: Text(p, style: const TextStyle(fontSize: 11)),
                selected: _period == p,
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _period = p),
              ))).toList()),
          )),
          const SizedBox(height: 12),

          // Content
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.all(isWide ? 24 : 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Total card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TOTAL EXPENSES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(AppFormatters.currency(total),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('${expenses.length} transactions · $_period',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                  ])),
                ])),
              const SizedBox(height: 20),

              // Category breakdown
              if (sortedCats.isNotEmpty) ...[
                GlassCard(padding: const EdgeInsets.all(16), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.pie_chart, color: AppColors.accent, size: 18),
                      SizedBox(width: 8),
                      Text('By Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                    const SizedBox(height: 12),
                    ...sortedCats.map((entry) {
                      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
                      return InkWell(
                        onTap: () => setState(() => _catFilter = _catFilter == entry.key ? null : entry.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: _catFilter == entry.key ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Text(entry.key.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(entry.key.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 4),
                              ClipRRect(borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                  color: _catColor(entry.key),
                                  minHeight: 5)),
                            ])),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(AppFormatters.currency(entry.value),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              Text('${pct.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
                            ]),
                          ])));
                    }),
                  ])),
                const SizedBox(height: 20),
              ],

              // Category filter chips
              if (_catFilter != null)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                  Text('Filtered: ${_catFilter!.icon} ${_catFilter!.label}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _catFilter = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.close, size: 14, color: AppColors.error))),
                ])),

              // Expense list
              if (expenses.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                  Icon(Icons.money_off, size: 64, color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1)),
                  const SizedBox(height: 12),
                  Text('No expenses recorded', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddExpense(context, appState),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add your first expense')),
                ])))
              else
                ...expenses.map((e) => _buildExpenseTile(context, e, appState, isDark)),
            ]),
          )),
        ]);
      });
    });
  }

  Widget _buildExpenseTile(BuildContext context, Expense expense, AppState appState, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _catColor(expense.category).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(expense.category.icon, style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              Text(expense.category.label,
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 8),
              Text('· ${AppFormatters.date(expense.date)}',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
            ]),
            if (expense.notes != null && expense.notes!.isNotEmpty)
              Text(expense.notes!, style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black26),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Text(AppFormatters.currency(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.error)),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            iconSize: 18,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
            ],
            onSelected: (v) async {
              if (v == 'edit') {
                _showAddExpense(context, appState, existing: expense);
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Delete Expense?'),
                  content: Text('Delete "${expense.title}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ]));
                if (ok == true) await appState.deleteExpense(expense.id);
              }
            }),
        ])),
    );
  }

  void _showAddExpense(BuildContext context, AppState appState, {Expense? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    ExpenseCategory selectedCat = existing?.category ?? ExpenseCategory.misc;
    DateTime selectedDate = existing?.date ?? DateTime.now();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
      return AlertDialog(
        title: Row(children: [
          Icon(isEdit ? Icons.edit : Icons.add_circle, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Expense' : 'Add Expense'),
        ]),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Office Rent May',
                prefixIcon: Icon(Icons.title)),
              textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                hintText: '0.00',
                prefixIcon: Icon(Icons.currency_rupee))),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              value: selectedCat,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category)),
              items: ExpenseCategory.values.map((c) => DropdownMenuItem(
                value: c,
                child: Row(children: [
                  Text(c.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(c.label, style: const TextStyle(fontSize: 13)),
                ]))).toList(),
              onChanged: (v) => setDialogState(() => selectedCat = v!)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)));
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today)),
                child: Text(AppFormatters.date(selectedDate)))),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.note)),
              maxLines: 2),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;

              final exp = Expense(
                id: existing?.id,
                title: titleCtrl.text.trim(),
                amount: amount,
                category: selectedCat,
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                date: selectedDate,
                createdAt: existing?.createdAt,
              );

              if (isEdit) {
                await appState.updateExpense(exp);
              } else {
                await appState.addExpense(exp);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(isEdit ? 'Expense updated' : 'Expense added'),
                ]),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
            },
            icon: Icon(isEdit ? Icons.save : Icons.add, size: 18),
            label: Text(isEdit ? 'Update' : 'Add Expense')),
        ],
      );
    }));
  }

  Color _catColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.rent: return const Color(0xFF8B5CF6);
      case ExpenseCategory.salary: return const Color(0xFF3B82F6);
      case ExpenseCategory.electricity: return const Color(0xFFF59E0B);
      case ExpenseCategory.water: return const Color(0xFF06B6D4);
      case ExpenseCategory.internet: return const Color(0xFF6366F1);
      case ExpenseCategory.transport: return const Color(0xFFEC4899);
      case ExpenseCategory.packaging: return const Color(0xFF78716C);
      case ExpenseCategory.maintenance: return const Color(0xFFEF4444);
      case ExpenseCategory.marketing: return const Color(0xFF10B981);
      case ExpenseCategory.insurance: return const Color(0xFF14B8A6);
      case ExpenseCategory.tax: return const Color(0xFFDC2626);
      case ExpenseCategory.office: return const Color(0xFF64748B);
      case ExpenseCategory.misc: return const Color(0xFF9CA3AF);
    }
  }
}
