import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/cash_book.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key});
  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final entries = appState.cashBookEntries;
      final accounts = appState.bankAccounts;

      // Calculate totals
      double cashBalance = 0;
      for (final e in entries) {
        if (e.type == TransactionType.cashIn) cashBalance += e.amount;
        if (e.type == TransactionType.cashOut) cashBalance -= e.amount;
      }
      double totalBankBalance = accounts.fold(0.0, (sum, a) => sum + a.balance);

      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Column(children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Text('Cash & Bank Book', style: Theme.of(context).textTheme.headlineLarge),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showAddTransaction(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Transaction')),
          ]),
          const SizedBox(height: 16),

          // Summary cards
          Row(children: [
            Expanded(child: _summaryCard('Cash Balance', cashBalance, Icons.payments, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _summaryCard('Bank Balance', totalBankBalance, Icons.account_balance, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _summaryCard('Total', cashBalance + totalBankBalance, Icons.wallet, AppColors.accent)),
          ]),
          const SizedBox(height: 16),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
              tabs: const [
                Tab(text: 'Transactions'),
                Tab(text: 'Bank Accounts'),
                Tab(text: 'Summary'),
              ],
            ),
          ),
        ])),

        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _buildTransactions(context, appState, entries),
          _buildBankAccounts(context, appState, accounts),
          _buildSummary(context, appState, entries, accounts),
        ])),
      ]);
    });
  }

  Widget _summaryCard(String label, double amount, IconData icon, Color color) {
    return GlassCard(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const Spacer(),
        ]),
        const SizedBox(height: 10),
        Text(AppFormatters.currency(amount), style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: amount >= 0 ? Colors.white : AppColors.error)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
      ]));
  }

  // ===== TAB 1: TRANSACTIONS =====
  Widget _buildTransactions(BuildContext context, AppState appState, List<CashBookEntry> entries) {
    // Filter
    var filtered = entries;
    if (_filterType != 'all') {
      if (_filterType == 'cash') {
        filtered = entries.where((e) => e.type == TransactionType.cashIn || e.type == TransactionType.cashOut).toList();
      } else if (_filterType == 'bank') {
        filtered = entries.where((e) => e.type == TransactionType.bankIn || e.type == TransactionType.bankOut || e.type == TransactionType.bankTransfer).toList();
      }
    }

    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          _filterChip('All', 'all'),
          const SizedBox(width: 8),
          _filterChip('Cash', 'cash'),
          const SizedBox(width: 8),
          _filterChip('Bank', 'bank'),
          const Spacer(),
          Text('${filtered.length} entries', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
        ])),
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('No transactions yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddTransaction(context, appState),
              icon: const Icon(Icons.add, size: 16), label: const Text('Add First Transaction'))]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _buildEntryTile(context, appState, filtered[i]))),
    ]);
  }

  Widget _filterChip(String label, String value) {
    final selected = _filterType == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      selected: selected,
      onSelected: (_) => setState(() => _filterType = value),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEntryTile(BuildContext context, AppState appState, CashBookEntry entry) {
    final isIn = entry.isInflow;
    final color = isIn ? AppColors.success : AppColors.error;
    final icon = entry.type == TransactionType.cashIn || entry.type == TransactionType.cashOut
        ? Icons.payments : Icons.account_balance;

    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
              child: Text(entry.typeLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
            if (entry.reference != null) ...[
              const SizedBox(width: 6),
              Text(entry.reference!, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
            ],
            if (entry.category != null) ...[
              const SizedBox(width: 6),
              Text('· ${entry.category}', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
            ],
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isIn ? '+' : '-'} ${AppFormatters.currency(entry.amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text(DateFormat('dd MMM yy').format(entry.date), style: TextStyle(
            fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
        ]),
        const SizedBox(width: 6),
        IconButton(icon: Icon(Icons.delete_outline, size: 16, color: Colors.white.withValues(alpha: 0.3)),
          onPressed: () => _confirmDeleteEntry(context, appState, entry)),
      ])));
  }

  // ===== TAB 2: BANK ACCOUNTS =====
  Widget _buildBankAccounts(BuildContext context, AppState appState, List<BankAccount> accounts) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Text('${accounts.length} accounts', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showBankDialog(context, appState),
            icon: const Icon(Icons.add, size: 16), label: const Text('Add Bank')),
        ])),
      Expanded(child: accounts.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.account_balance, size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text('No bank accounts', style: TextStyle(color: Colors.white.withValues(alpha: 0.3)))]))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: accounts.length,
            itemBuilder: (ctx, i) => _buildBankTile(context, appState, accounts[i]))),
    ]);
  }

  Widget _buildBankTile(BuildContext context, AppState appState, BankAccount account) {
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(padding: const EdgeInsets.all(18), child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance, color: Colors.white, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(account.bankName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text('A/C: ${_maskAccount(account.accountNumber)}', style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
            if (account.ifscCode.isNotEmpty)
              Text('IFSC: ${account.ifscCode}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.currency(account.balance), style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 18,
              color: account.balance >= 0 ? AppColors.success : AppColors.error)),
            const SizedBox(height: 2),
            Text('Balance', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (account.branch.isNotEmpty)
            Text('Branch: ${account.branch}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
          if (account.accountHolder.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text('Holder: ${account.accountHolder}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
          ],
          const Spacer(),
          IconButton(icon: const Icon(Icons.edit, size: 16), visualDensity: VisualDensity.compact,
            onPressed: () => _showBankDialog(context, appState, account: account)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error), visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDeleteBank(context, appState, account)),
        ]),
      ])));
  }

  String _maskAccount(String acc) {
    if (acc.length <= 4) return acc;
    return 'XXXX${acc.substring(acc.length - 4)}';
  }

  // ===== TAB 3: SUMMARY =====
  Widget _buildSummary(BuildContext context, AppState appState, List<CashBookEntry> entries, List<BankAccount> accounts) {
    double totalCashIn = 0, totalCashOut = 0, totalBankIn = 0, totalBankOut = 0;
    for (final e in entries) {
      switch (e.type) {
        case TransactionType.cashIn: totalCashIn += e.amount; break;
        case TransactionType.cashOut: totalCashOut += e.amount; break;
        case TransactionType.bankIn: totalBankIn += e.amount; break;
        case TransactionType.bankOut: totalBankOut += e.amount; break;
        case TransactionType.bankTransfer: break;
      }
    }

    // Group by category
    final categoryTotals = <String, double>{};
    for (final e in entries.where((e) => !e.isInflow)) {
      final cat = e.category ?? 'Uncategorized';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
    }
    final sortedCats = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlassCard(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('Cash Flow Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          _summaryRow('Total Cash In', totalCashIn, AppColors.success),
          _summaryRow('Total Cash Out', totalCashOut, AppColors.error),
          const Divider(height: 20),
          _summaryRow('Net Cash', totalCashIn - totalCashOut, totalCashIn >= totalCashOut ? AppColors.success : AppColors.error),
          const SizedBox(height: 16),
          _summaryRow('Total Bank Deposits', totalBankIn, AppColors.success),
          _summaryRow('Total Bank Withdrawals', totalBankOut, AppColors.error),
          const Divider(height: 20),
          _summaryRow('Total Balance', (totalCashIn - totalCashOut) + accounts.fold(0.0, (s, a) => s + a.balance),
            AppColors.primary, bold: true),
        ])),
        if (sortedCats.isNotEmpty) ...[
          const SizedBox(height: 20),
          GlassCard(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Outflow by Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              ...sortedCats.map((e) => _summaryRow(e.key, e.value, AppColors.error)),
            ])),
        ],
      ]));
  }

  Widget _summaryRow(String label, double amount, Color color, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text(AppFormatters.currency(amount), style: TextStyle(
          fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
      ]));
  }

  // ===== DIALOGS =====

  void _showAddTransaction(BuildContext context, AppState appState) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    TransactionType type = TransactionType.cashIn;
    String? selectedBankId = appState.bankAccounts.isNotEmpty ? appState.bankAccounts.first.id : null;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.add_circle, color: AppColors.primary), SizedBox(width: 10), Text('Add Transaction')]),
      content: SingleChildScrollView(child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Transaction type
        DropdownButtonFormField<TransactionType>(
          value: type,
          decoration: const InputDecoration(labelText: 'Transaction Type', prefixIcon: Icon(Icons.swap_vert)),
          items: TransactionType.values.map((t) => DropdownMenuItem(value: t,
            child: Text(CashBookEntry(type: t, amount: 0, description: '').typeLabel))).toList(),
          onChanged: (v) => setDialogState(() => type = v ?? type),
        ),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee))),
        const SizedBox(height: 12),
        TextField(controller: descCtrl,
          decoration: const InputDecoration(labelText: 'Description *', prefixIcon: Icon(Icons.description))),
        const SizedBox(height: 12),
        TextField(controller: refCtrl,
          decoration: const InputDecoration(labelText: 'Reference (optional)', prefixIcon: Icon(Icons.tag),
            hintText: 'Bill no, receipt no, etc.')),
        const SizedBox(height: 12),
        TextField(controller: catCtrl,
          decoration: const InputDecoration(labelText: 'Category (optional)', prefixIcon: Icon(Icons.category),
            hintText: 'e.g. Rent, Salary, Sales')),
        if (type == TransactionType.bankIn || type == TransactionType.bankOut || type == TransactionType.bankTransfer) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedBankId,
            decoration: const InputDecoration(labelText: 'Bank Account', prefixIcon: Icon(Icons.account_balance)),
            items: appState.bankAccounts.map((a) => DropdownMenuItem(value: a.id,
              child: Text('${a.bankName} (${_maskAccount(a.accountNumber)})'))).toList(),
            onChanged: (v) => setDialogState(() => selectedBankId = v),
          ),
        ],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: () async {
            final amount = double.tryParse(amountCtrl.text) ?? 0;
            if (amount <= 0 || descCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Amount and description are required')));
              return;
            }
            final entry = CashBookEntry(
              type: type, amount: amount, description: descCtrl.text.trim(),
              reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
              bankAccountId: selectedBankId,
              category: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
            );
            Navigator.pop(ctx);
            await appState.addCashBookEntry(entry);
          },
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save')),
      ],
    )));
  }

  void _showBankDialog(BuildContext context, AppState appState, {BankAccount? account}) {
    final isEditing = account != null;
    final nameCtrl = TextEditingController(text: account?.bankName ?? '');
    final accCtrl = TextEditingController(text: account?.accountNumber ?? '');
    final ifscCtrl = TextEditingController(text: account?.ifscCode ?? '');
    final branchCtrl = TextEditingController(text: account?.branch ?? '');
    final holderCtrl = TextEditingController(text: account?.accountHolder ?? '');
    final balCtrl = TextEditingController(text: account?.balance.toStringAsFixed(2) ?? '0.00');

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.account_balance, color: AppColors.primary), const SizedBox(width: 10),
        Text(isEditing ? 'Edit Bank Account' : 'Add Bank Account')]),
      content: SingleChildScrollView(child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Bank Name *', prefixIcon: Icon(Icons.business),
            hintText: 'e.g. State Bank of India')),
        const SizedBox(height: 12),
        TextField(controller: accCtrl,
          decoration: const InputDecoration(labelText: 'Account Number *', prefixIcon: Icon(Icons.numbers))),
        const SizedBox(height: 12),
        TextField(controller: ifscCtrl, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.code),
            hintText: 'e.g. SBIN0001234')),
        const SizedBox(height: 12),
        TextField(controller: branchCtrl,
          decoration: const InputDecoration(labelText: 'Branch', prefixIcon: Icon(Icons.location_on_outlined))),
        const SizedBox(height: 12),
        TextField(controller: holderCtrl,
          decoration: const InputDecoration(labelText: 'Account Holder', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        TextField(controller: balCtrl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Opening Balance (₹)', prefixIcon: Icon(Icons.currency_rupee))),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty || accCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bank name and account number are required')));
              return;
            }
            if (isEditing) {
              account.bankName = nameCtrl.text.trim();
              account.accountNumber = accCtrl.text.trim();
              account.ifscCode = ifscCtrl.text.trim().toUpperCase();
              account.branch = branchCtrl.text.trim();
              account.accountHolder = holderCtrl.text.trim();
              account.balance = double.tryParse(balCtrl.text) ?? account.balance;
              await appState.updateBankAccount(account);
            } else {
              await appState.addBankAccount(BankAccount(
                bankName: nameCtrl.text.trim(),
                accountNumber: accCtrl.text.trim(),
                ifscCode: ifscCtrl.text.trim().toUpperCase(),
                branch: branchCtrl.text.trim(),
                accountHolder: holderCtrl.text.trim(),
                balance: double.tryParse(balCtrl.text) ?? 0,
              ));
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(isEditing ? 'Save' : 'Add')),
      ],
    ));
  }

  void _confirmDeleteEntry(BuildContext context, AppState appState, CashBookEntry entry) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Transaction?'),
      content: Text('Delete "${entry.description}" (${AppFormatters.currency(entry.amount)})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () { appState.deleteCashBookEntry(entry.id); Navigator.pop(ctx); },
          child: const Text('Delete')),
      ],
    ));
  }

  void _confirmDeleteBank(BuildContext context, AppState appState, BankAccount account) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Bank Account?'),
      content: Text('Delete "${account.bankName}" (${_maskAccount(account.accountNumber)})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () { appState.deleteBankAccount(account.id); Navigator.pop(ctx); },
          child: const Text('Delete')),
      ],
    ));
  }
}
