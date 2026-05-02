import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/bill.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(children: [
          Text('Reports', style: Theme.of(context).textTheme.headlineLarge),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '📊 Sales Report'),
                Tab(text: '🧾 GST Report'),
              ],
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Expanded(child: TabBarView(
        controller: _tabCtrl,
        children: const [
          _SalesReportTab(),
          _GSTReportTab(),
        ],
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════
//  SALES REPORT TAB
// ═══════════════════════════════════════════════
class _SalesReportTab extends StatefulWidget {
  const _SalesReportTab();
  @override
  State<_SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends State<_SalesReportTab> {
  String _period = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final now = DateTime.now();
      final bills = appState.bills.where((b) {
        if (_period == 'Today') {
          return b.createdAt.day == now.day && b.createdAt.month == now.month && b.createdAt.year == now.year;
        } else if (_period == 'This Week') {
          final weekAgo = now.subtract(const Duration(days: 7));
          return b.createdAt.isAfter(weekAgo);
        } else if (_period == 'This Month') {
          return b.createdAt.month == now.month && b.createdAt.year == now.year;
        } else if (_period == 'This Year') {
          return b.createdAt.year == now.year;
        }
        return true; // All Time
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final totalSales = bills.fold<double>(0, (s, b) => s + b.totalAmount);
      final totalTax = bills.fold<double>(0, (s, b) => s + b.totalTax);
      final totalDiscount = bills.fold<double>(0, (s, b) => s + b.discount);
      final totalPaid = bills.fold<double>(0, (s, b) => s + b.paidAmount);
      final totalDue = totalSales - totalPaid;
      final avgBill = bills.isNotEmpty ? totalSales / bills.length : 0.0;

      // Payment method breakdown
      final methodCounts = <PaymentMethod, int>{};
      final methodAmounts = <PaymentMethod, double>{};
      for (final b in bills) {
        methodCounts[b.paymentMethod] = (methodCounts[b.paymentMethod] ?? 0) + 1;
        methodAmounts[b.paymentMethod] = (methodAmounts[b.paymentMethod] ?? 0) + b.totalAmount;
      }

      // Daily breakdown for chart
      final dailySales = <String, double>{};
      for (final b in bills) {
        final key = '${b.createdAt.day}/${b.createdAt.month}';
        dailySales[key] = (dailySales[key] ?? 0) + b.totalAmount;
      }

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Period selector
            Wrap(spacing: 8, runSpacing: 8, children:
              ['Today', 'This Week', 'This Month', 'This Year', 'All Time'].map((p) =>
                ChoiceChip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  selected: _period == p,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _period = p),
                )).toList()),
            const SizedBox(height: 20),

            // Summary cards
            _buildSummaryCards(isWide, totalSales, bills.length, totalTax, totalDiscount, totalPaid, totalDue, avgBill),
            const SizedBox(height: 20),

            // Daily sales bar chart
            if (dailySales.isNotEmpty) ...[
              GlassCard(padding: const EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Daily Sales', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(height: 160, child: _buildBarChart(dailySales)),
                ])),
              const SizedBox(height: 20),
            ],

            // Payment methods
            if (methodCounts.isNotEmpty)
              GlassCard(padding: const EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.payment, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                  const SizedBox(height: 12),
                  ...methodCounts.entries.map((e) {
                    final pct = bills.isNotEmpty ? (e.value / bills.length * 100) : 0;
                    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                      _paymentIcon(e.key),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.key.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            color: _paymentColor(e.key),
                            minHeight: 6)),
                      ])),
                      const SizedBox(width: 12),
                      Text('${e.value} (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(AppFormatters.currency(methodAmounts[e.key] ?? 0),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ]));
                  }),
                ])),
            const SizedBox(height: 20),

            // Recent transactions
            GlassCard(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.list_alt, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Transactions (${bills.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                if (bills.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No sales in this period')))
                else
                  ...bills.take(20).map((b) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Container(width: 4, height: 30,
                        decoration: BoxDecoration(
                          color: b.status == BillStatus.paid ? AppColors.success : AppColors.error,
                          borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.billNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text('${b.customerName ?? 'Walk-in'} · ${AppFormatters.date(b.createdAt)}',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                      ])),
                      Text(AppFormatters.currency(b.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ]))),
              ])),
          ]),
        );
      });
    });
  }

  Widget _buildSummaryCards(bool isWide, double totalSales, int count, double tax, double discount, double paid, double due, double avg) {
    final cards = [
      _summaryCard('Total Sales', AppFormatters.currency(totalSales), '$count bills', Icons.trending_up, AppColors.primaryGradient),
      _summaryCard('Tax Collected', AppFormatters.currency(tax), 'GST', Icons.account_balance, AppColors.accentGradient),
      _summaryCard('Discount Given', AppFormatters.currency(discount), 'savings', Icons.local_offer, const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFBE185D)])),
      _summaryCard('Collected', AppFormatters.currency(paid), 'Due: ${AppFormatters.currency(due)}', Icons.payments, due > 0 ? AppColors.warningGradient : AppColors.successGradient),
    ];

    if (isWide) {
      return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList());
    }
    return Wrap(spacing: 8, runSpacing: 8, children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: c)).toList());
  }

  Widget _summaryCard(String title, String value, String subtitle, IconData icon, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _buildBarChart(Map<String, double> data) {
    final maxVal = data.values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox();
    final entries = data.entries.toList();

    return Row(crossAxisAlignment: CrossAxisAlignment.end, children:
      entries.map((e) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(AppFormatters.compactCurrency(e.value), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            height: (e.value / maxVal) * 120,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Text(e.key, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.5))),
        ])))).toList());
  }

  Widget _paymentIcon(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return const Icon(Icons.money, size: 18, color: AppColors.success);
      case PaymentMethod.upi: return const Icon(Icons.phone_android, size: 18, color: AppColors.primary);
      case PaymentMethod.card: return const Icon(Icons.credit_card, size: 18, color: AppColors.accent);
      case PaymentMethod.bank: return const Icon(Icons.account_balance, size: 18, color: AppColors.warning);
      case PaymentMethod.credit: return const Icon(Icons.schedule, size: 18, color: AppColors.error);
    }
  }

  Color _paymentColor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return AppColors.success;
      case PaymentMethod.upi: return AppColors.primary;
      case PaymentMethod.card: return AppColors.accent;
      case PaymentMethod.bank: return AppColors.warning;
      case PaymentMethod.credit: return AppColors.error;
    }
  }
}

// ═══════════════════════════════════════════════
//  GST REPORT TAB
// ═══════════════════════════════════════════════
class _GSTReportTab extends StatefulWidget {
  const _GSTReportTab();
  @override
  State<_GSTReportTab> createState() => _GSTReportTabState();
}

class _GSTReportTabState extends State<_GSTReportTab> {
  String _period = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, _) {
      final now = DateTime.now();
      final bills = appState.bills.where((b) {
        if (_period == 'This Month') {
          return b.createdAt.month == now.month && b.createdAt.year == now.year;
        } else if (_period == 'Last Month') {
          final lastMonth = DateTime(now.year, now.month - 1);
          return b.createdAt.month == lastMonth.month && b.createdAt.year == lastMonth.year;
        } else if (_period == 'This Quarter') {
          final qStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1);
          return b.createdAt.isAfter(qStart.subtract(const Duration(days: 1)));
        } else if (_period == 'This Year') {
          return b.createdAt.year == now.year;
        }
        return true;
      }).toList();

      // GST breakdown by rate
      final gstByRate = <double, _GSTSlabData>{};
      for (final bill in bills) {
        for (final item in bill.items) {
          final rate = item.taxRate;
          gstByRate.putIfAbsent(rate, () => _GSTSlabData());
          gstByRate[rate]!.taxableValue += item.subtotal;
          gstByRate[rate]!.cgst += item.cgst;
          gstByRate[rate]!.sgst += item.sgst;
          gstByRate[rate]!.totalTax += item.taxAmount;
          gstByRate[rate]!.count += 1;
        }
      }

      final totalTaxable = bills.fold<double>(0, (s, b) => s + b.subtotal);
      final totalCGST = bills.fold<double>(0, (s, b) => s + b.totalCgst);
      final totalSGST = bills.fold<double>(0, (s, b) => s + b.totalSgst);
      final totalGST = bills.fold<double>(0, (s, b) => s + b.totalTax);
      final totalInvoice = bills.fold<double>(0, (s, b) => s + b.totalAmount);

      final sortedRates = gstByRate.keys.toList()..sort();

      return LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Period selector
            Wrap(spacing: 8, runSpacing: 8, children:
              ['This Month', 'Last Month', 'This Quarter', 'This Year', 'All Time'].map((p) =>
                ChoiceChip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  selected: _period == p,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _period = p),
                )).toList()),
            const SizedBox(height: 20),

            // GST Summary cards
            _buildGSTSummary(isWide, totalTaxable, totalCGST, totalSGST, totalGST, totalInvoice, bills.length),
            const SizedBox(height: 20),

            // GST Slab-wise table
            GlassCard(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.table_chart, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('GST Slab-wise Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                const SizedBox(height: 16),
                if (sortedRates.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No GST data for this period')))
                else
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.1)),
                    columns: const [
                      DataColumn(label: Text('GST %', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Items', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text('Taxable ₹', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text('CGST ₹', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text('SGST ₹', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                      DataColumn(label: Text('Total Tax ₹', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                    ],
                    rows: [
                      ...sortedRates.map((rate) {
                        final d = gstByRate[rate]!;
                        return DataRow(cells: [
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('${rate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)))),
                          DataCell(Text('${d.count}')),
                          DataCell(Text(AppFormatters.currency(d.taxableValue))),
                          DataCell(Text(AppFormatters.currency(d.cgst))),
                          DataCell(Text(AppFormatters.currency(d.sgst))),
                          DataCell(Text(AppFormatters.currency(d.totalTax), style: const TextStyle(fontWeight: FontWeight.w700))),
                        ]);
                      }),
                      // Total row
                      DataRow(
                        color: WidgetStatePropertyAll(AppColors.success.withValues(alpha: 0.08)),
                        cells: [
                          const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800))),
                          DataCell(Text('${gstByRate.values.fold<int>(0, (s, d) => s + d.count)}')),
                          DataCell(Text(AppFormatters.currency(totalTaxable), style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(AppFormatters.currency(totalCGST), style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(AppFormatters.currency(totalSGST), style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(AppFormatters.currency(totalGST), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                        ],
                      ),
                    ],
                  )),
              ])),
            const SizedBox(height: 20),

            // GST Rate Distribution
            if (sortedRates.isNotEmpty)
              GlassCard(padding: const EdgeInsets.all(20), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.pie_chart, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text('Tax Distribution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                  const SizedBox(height: 16),
                  ...sortedRates.map((rate) {
                    final d = gstByRate[rate]!;
                    final pct = totalGST > 0 ? (d.totalTax / totalGST * 100) : 0;
                    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('GST ${rate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${pct.toStringAsFixed(1)}% · ${AppFormatters.currency(d.totalTax)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            color: _slabColor(rate),
                            minHeight: 8)),
                      ]));
                  }),
                ])),
          ]),
        );
      });
    });
  }

  Widget _buildGSTSummary(bool isWide, double taxable, double cgst, double sgst, double gst, double total, int count) {
    final cards = [
      _gstCard('Taxable Value', AppFormatters.currency(taxable), Icons.receipt, const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4338CA)])),
      _gstCard('CGST', AppFormatters.currency(cgst), Icons.account_balance, const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0284C7)])),
      _gstCard('SGST', AppFormatters.currency(sgst), Icons.account_balance_wallet, const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)])),
      _gstCard('Total GST', AppFormatters.currency(gst), Icons.summarize, const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])),
    ];

    if (isWide) {
      return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList());
    }
    return Wrap(spacing: 8, runSpacing: 8, children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: c)).toList());
  }

  Widget _gstCard(String title, String value, IconData icon, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
      ]),
    );
  }

  Color _slabColor(double rate) {
    if (rate <= 5) return const Color(0xFF10B981);
    if (rate <= 12) return const Color(0xFF06B6D4);
    if (rate <= 18) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _GSTSlabData {
  double taxableValue = 0;
  double cgst = 0;
  double sgst = 0;
  double totalTax = 0;
  int count = 0;
}
