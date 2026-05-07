import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/models/bill.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String _userName = '';
  String _logoUrl = '';
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _loadUserName();
    // Live clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  Future<void> _loadUserName() async {
    final appState = context.read<AppState>();
    final name = await appState.getSetting('businessName');
    final logo = await appState.getSetting('businessLogo');
    if (mounted) {
      setState(() {
        _userName = name ?? '';
        _logoUrl = logo ?? '';
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final stats = appState.dashboardStats;
        final todaySales = (stats['todaySales'] as num?)?.toDouble() ?? 0.0;
        final todayCount = (stats['todayBillCount'] as num?)?.toInt() ?? 0;
        final monthSales = (stats['monthSales'] as num?)?.toDouble() ?? 0.0;
        final monthCount = (stats['monthBillCount'] as num?)?.toInt() ?? 0;
        final outstanding = (stats['outstanding'] as num?)?.toDouble() ?? 0.0;
        final customerCount = (stats['customerCount'] as num?)?.toInt() ?? 0;
        final itemCount = (stats['itemCount'] as num?)?.toInt() ?? 0;

        return FadeTransition(
          opacity: _fadeAnim,
          child: RefreshIndicator(
            onRefresh: () => appState.loadDashboardStats(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✨ Neon Gradient Greeting Banner
                      _buildNeonGreeting(context),
                      const SizedBox(height: 24),

                      // Stat Cards
                      _buildStatGrid(isWide, todaySales, todayCount,
                          monthSales, monthCount, outstanding, itemCount),

                      const SizedBox(height: 24),

                      // 📊 Dashboard Charts
                      _buildSalesChart(context, appState, isWide),
                      const SizedBox(height: 20),
                      _buildTopItemsChart(context, appState, isWide),
                      const SizedBox(height: 20),

                      // 📈 Monthly Comparison (Sales vs Expenses)
                      _buildMonthlyComparison(context, appState, isWide),
                      const SizedBox(height: 20),

                      // 💡 Profit Insights
                      _buildProfitInsights(context, appState, isWide),
                      const SizedBox(height: 24),

                      // 🔔 Payment Reminders
                      _buildPaymentReminders(context, appState, isWide),

                      // 🔴 Low Stock Alerts
                      _buildLowStockAlerts(context, appState, isWide),

                      // 💰 Outstanding Dues
                      _buildOutstandingDues(context, appState, isWide),

                      // Recent Bills
                      _buildRecentBills(context, appState, isWide),

                      const SizedBox(height: 24),

                      // Quick Stats Row
                      _buildQuickStats(
                          context, customerCount, itemCount, todayCount),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNeonGreeting(BuildContext context) {
    final displayName = _userName.isNotEmpty ? _userName : 'Boss';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(-10, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting emoji + text
          Row(
            children: [
              // Business Logo
              if (_logoUrl.isNotEmpty) ...
                [Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
                    image: DecorationImage(image: NetworkImage(_logoUrl), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),]
              else ...
                [Text(_getEmoji(), style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),],
              // Date chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF818CF8)),
                    const SizedBox(width: 6),
                    Text(
                      AppFormatters.date(_currentTime),
                      style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Time chip (live)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF00F5A0)),
                    const SizedBox(width: 6),
                    Text(
                      '${(_currentTime.hour % 12 == 0 ? 12 : _currentTime.hour % 12).toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')} ${_currentTime.hour >= 12 ? 'PM' : 'AM'}',
                      style: const TextStyle(color: Color(0xFF00F5A0), fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Main greeting with neon gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF00F5A0), // Neon green
                Color(0xFF00D9F5), // Neon cyan
                Color(0xFFA855F7), // Neon purple
                Color(0xFFEC4899), // Neon pink
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(
              '${_getGreetingText()}, $displayName!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Motivational subtitle with softer neon glow
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF06B6D4), // Cyan
                Color(0xFF818CF8), // Indigo
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              '✨ Have a profitable day! Make it count 💰',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildStatGrid(bool isWide, double todaySales, int todayCount,
      double monthSales, int monthCount, double outstanding, int itemCount) {
    final cards = [
      StatCard(
        title: "Today's Sales",
        value: AppFormatters.currency(todaySales),
        subtitle: '$todayCount bills',
        icon: Icons.trending_up_rounded,
        gradient: AppColors.primaryGradient,
      ),
      StatCard(
        title: 'Monthly Revenue',
        value: AppFormatters.compactCurrency(monthSales),
        subtitle: '$monthCount bills',
        icon: Icons.bar_chart_rounded,
        gradient: AppColors.accentGradient,
      ),
      StatCard(
        title: 'Outstanding',
        value: AppFormatters.currency(outstanding),
        subtitle: 'pending',
        icon: Icons.account_balance_wallet_rounded,
        gradient: outstanding > 0
            ? AppColors.warningGradient
            : AppColors.successGradient,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map((card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: card,
                  ),
                ))
            .toList(),
      );
    }

    return Column(
      children: cards
          .map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              ))
          .toList(),
    );
  }

  Widget _buildRecentBills(
      BuildContext context, AppState appState, bool isWide) {
    final recentBills = appState.bills.take(5).toList();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Recent Bills',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Navigate to history - handled by parent
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentBills.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No bills yet. Create your first bill!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentBills.map((bill) => _buildBillTile(context, bill)),
        ],
      ),
    );
  }

  Widget _buildBillTile(BuildContext context, dynamic bill) {
    final statusColor = bill.status.name == 'paid'
        ? AppColors.success
        : bill.status.name == 'partial'
            ? AppColors.warning
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.billNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  bill.customerName ?? 'Walk-in Customer',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.currency(bill.totalAmount),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bill.status.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(BuildContext context, AppState appState, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dailySales = <String, double>{};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.day}/${d.month}';
      dailySales[key] = 0;
    }
    for (final b in appState.bills) {
      final d = b.createdAt;
      if (d.isAfter(now.subtract(const Duration(days: 7)))) {
        final key = '${d.day}/${d.month}';
        dailySales[key] = (dailySales[key] ?? 0) + b.totalAmount;
      }
    }
    final labels = dailySales.keys.toList();
    final values = dailySales.values.toList();
    final maxY = values.isEmpty ? 1000.0 : (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100, double.infinity);

    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('7-Day Sales Trend', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 20),
        SizedBox(height: 180, child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 8),
                child: Text(v.toInt() < labels.length ? labels[v.toInt()] : '', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.black38))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50,
              getTitlesWidget: (v, _) => Text(AppFormatters.compactCurrency(v), style: TextStyle(fontSize: 8, color: isDark ? Colors.white38 : Colors.black38)))),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: 6, minY: 0, maxY: maxY.toDouble(),
          lineBarsData: [LineChartBarData(
            spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true, color: AppColors.primary, barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeWidth: 2, strokeColor: Colors.white)),
            belowBarData: BarAreaData(show: true,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.0)])),
          )],
        ))),
      ]));
  }

  Widget _buildTopItemsChart(BuildContext context, AppState appState, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemSales = <String, double>{};
    for (final b in appState.bills) {
      for (final item in b.items) {
        itemSales[item.itemName] = (itemSales[item.itemName] ?? 0) + item.subtotal;
      }
    }
    if (itemSales.isEmpty) return const SizedBox();
    final sorted = itemSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final maxVal = top5.first.value;
    final colors = [AppColors.primary, AppColors.accent, AppColors.success, AppColors.warning, const Color(0xFFEC4899)];

    return GlassCard(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.leaderboard, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Top Selling Items', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 16),
        ...top5.asMap().entries.map((e) {
          final pct = maxVal > 0 ? (e.value.value / maxVal) : 0.0;
          final color = colors[e.key % colors.length];
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            SizedBox(width: 20, child: Text('${e.key + 1}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: color))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.value.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: pct, backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  color: color, minHeight: 6)),
            ])),
            const SizedBox(width: 12),
            Text(AppFormatters.currency(e.value.value), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          ]));
        }),
      ]));
  }

  Widget _buildLowStockAlerts(BuildContext context, AppState appState, bool isWide) {
    final lowStockItems = appState.items.where((i) => i.stockQuantity <= 5).toList()
      ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    if (lowStockItems.isEmpty) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20)),
            const SizedBox(width: 10),
            Text('Low Stock Alerts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
              child: Text('${lowStockItems.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          ...lowStockItems.take(10).map((item) {
            final isOut = item.stockQuantity == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isOut ? AppColors.error : AppColors.warning).withValues(alpha: isDark ? 0.06 : 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (isOut ? AppColors.error : AppColors.warning).withValues(alpha: 0.15))),
              child: Row(children: [
                Icon(isOut ? Icons.error : Icons.inventory, size: 18,
                  color: isOut ? AppColors.error : AppColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(item.category ?? item.unit, style: TextStyle(fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black45)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOut ? AppColors.error : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isOut ? Icons.remove_shopping_cart : Icons.inventory_2,
                      size: 12, color: isOut ? AppColors.error : AppColors.warning),
                    const SizedBox(width: 4),
                    Text(isOut ? 'OUT OF STOCK' : '${item.stockQuantity} ${item.unit} left',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: isOut ? AppColors.error : AppColors.warning)),
                  ])),
              ]));
          }),
          if (lowStockItems.length > 10)
            Padding(padding: const EdgeInsets.only(top: 4), child:
              Text('+ ${lowStockItems.length - 10} more items low on stock',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38))),
        ])),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildOutstandingDues(BuildContext context, AppState appState, bool isWide) {
    final unpaidBills = appState.bills.where((b) => b.status != BillStatus.paid && b.balanceDue > 0).toList()
      ..sort((a, b) => b.balanceDue.compareTo(a.balanceDue));
    if (unpaidBills.isEmpty) return const SizedBox();

    final totalDue = unpaidBills.fold<double>(0, (s, b) => s + b.balanceDue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group by customer
    final customerDues = <String, double>{};
    for (final b in unpaidBills) {
      final name = b.customerName ?? 'Walk-in';
      customerDues[name] = (customerDues[name] ?? 0) + b.balanceDue;
    }
    final sortedCustomers = customerDues.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(children: [
      GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet, color: AppColors.warning, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Outstanding Dues', style: Theme.of(context).textTheme.titleLarge),
              Text('${unpaidBills.length} unpaid bills', style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.warningGradient,
                borderRadius: BorderRadius.circular(10)),
              child: Text(AppFormatters.currency(totalDue),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white))),
          ]),
          const SizedBox(height: 16),
          // Customer-wise dues
          const Text('By Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          ...sortedCustomers.take(8).map((entry) {
            final pct = totalDue > 0 ? (entry.value / totalDue) : 0.0;
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                child: Center(child: Text(entry.key[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.warning)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 3),
                ClipRRect(borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    color: AppColors.warning,
                    minHeight: 4)),
              ])),
              const SizedBox(width: 10),
              Text(AppFormatters.currency(entry.value),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.warning)),
            ]));
          }),
          const SizedBox(height: 10),
          // Recent unpaid bills
          const Divider(),
          const SizedBox(height: 8),
          const Text('Recent Unpaid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          ...unpaidBills.take(5).map((bill) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Container(width: 4, height: 28,
                decoration: BoxDecoration(
                  color: bill.status == BillStatus.partial ? AppColors.warning : AppColors.error,
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text('${bill.customerName ?? 'Walk-in'} · ${AppFormatters.date(bill.createdAt)}',
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(AppFormatters.currency(bill.balanceDue),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.error)),
                if (bill.paidAmount > 0)
                  Text('Paid: ${AppFormatters.currency(bill.paidAmount)}',
                    style: const TextStyle(fontSize: 9, color: AppColors.success)),
              ]),
            ]))),
        ])),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildQuickStats(
      BuildContext context, int customers, int items, int todayBills) {
    return Row(
      children: [
        _quickStatTile(context, Icons.people_rounded, '$customers',
            'Customers', AppColors.accent),
        const SizedBox(width: 12),
        _quickStatTile(context, Icons.inventory_2_rounded, '$items', 'Items',
            AppColors.primary),
        const SizedBox(width: 12),
        _quickStatTile(context, Icons.today_rounded, '$todayBills',
            'Today\'s Bills', AppColors.success),
      ],
    );
  }

  Widget _quickStatTile(BuildContext context, IconData icon, String value,
      String label, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== MONTHLY COMPARISON CHART =====
  Widget _buildMonthlyComparison(BuildContext context, AppState appState, bool isWide) {
    final now = DateTime.now();
    final months = <String>[];
    final salesData = <double>[];
    final expenseData = <double>[];

    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      months.add(monthNames[m.month - 1]);

      double mSales = 0, mExpense = 0;
      for (final b in appState.bills) {
        if (b.createdAt.year == m.year && b.createdAt.month == m.month) mSales += b.totalAmount;
      }
      for (final e in appState.expenses) {
        if (e.date.year == m.year && e.date.month == m.month) mExpense += e.amount;
      }
      salesData.add(mSales);
      expenseData.add(mExpense);
    }

    final maxVal = [...salesData, ...expenseData].fold<double>(1, (a, b) => a > b ? a : b);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.compare_arrows, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Text('Monthly Comparison', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          _legendDot(AppColors.success, 'Sales'),
          const SizedBox(width: 12),
          _legendDot(AppColors.error, 'Expenses'),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => const Color(0xFF1A1A3E))),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50,
                getTitlesWidget: (v, _) => Text(AppFormatters.compactCurrency(v), style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4))))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v, _) => Text(months[v.toInt()], style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawHorizontalLine: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(6, (i) => BarChartGroupData(
              x: i, barRods: [
                BarChartRodData(toY: salesData[i], color: AppColors.success, width: isWide ? 14 : 10, borderRadius: BorderRadius.circular(4)),
                BarChartRodData(toY: expenseData[i], color: AppColors.error, width: isWide ? 14 : 10, borderRadius: BorderRadius.circular(4)),
              ])),
          )),
        ),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
    ]);
  }

  // ===== PAYMENT DUE REMINDERS =====
  Widget _buildPaymentReminders(BuildContext context, AppState appState, bool isWide) {
    final dueBills = appState.bills.where((b) =>
      b.status == BillStatus.unpaid || b.status == BillStatus.partial).toList();
    if (dueBills.isEmpty) return const SizedBox.shrink();

    dueBills.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest first
    final overdue = dueBills.where((b) => DateTime.now().difference(b.createdAt).inDays > 30).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.notifications_active, color: AppColors.warning, size: 20),
        const SizedBox(width: 8),
        Text('Payment Reminders (${dueBills.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (overdue.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text('${overdue.length} overdue', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error))),
        ],
      ]),
      const SizedBox(height: 12),
      ...dueBills.take(5).map((bill) {
        final daysOld = DateTime.now().difference(bill.createdAt).inDays;
        final isOverdue = daysOld > 30;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: (isOverdue ? AppColors.error : AppColors.warning).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(isOverdue ? Icons.warning_amber : Icons.schedule, size: 18,
                  color: isOverdue ? AppColors.error : AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${bill.customerName ?? "Walk-in"} • ${daysOld}d ago',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(AppFormatters.currency(bill.balanceDue),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isOverdue ? AppColors.error : AppColors.warning)),
                Text(isOverdue ? 'OVERDUE' : 'PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: isOverdue ? AppColors.error : AppColors.warning)),
              ]),
            ])),
        );
      }),
      const SizedBox(height: 20),
    ]);
  }

  // ===== PROFIT INSIGHTS =====
  Widget _buildProfitInsights(BuildContext context, AppState appState, bool isWide) {
    final now = DateTime.now();
    double monthSales = 0, monthExpenses = 0, monthPurchases = 0;
    for (final b in appState.bills) {
      if (b.createdAt.year == now.year && b.createdAt.month == now.month) monthSales += b.totalAmount;
    }
    for (final e in appState.expenses) {
      if (e.date.year == now.year && e.date.month == now.month) monthExpenses += e.amount;
    }
    for (final p in appState.purchases) {
      if (p.createdAt.year == now.year && p.createdAt.month == now.month) monthPurchases += p.totalAmount;
    }
    final profit = monthSales - monthExpenses - monthPurchases;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.insights, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('This Month Insights', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _insightTile('Revenue', AppFormatters.currency(monthSales), AppColors.success),
          const SizedBox(width: 12),
          _insightTile('Purchases', AppFormatters.currency(monthPurchases), AppColors.warning),
          const SizedBox(width: 12),
          _insightTile('Expenses', AppFormatters.currency(monthExpenses), AppColors.error),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              (profit >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
              (profit >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down, size: 22,
              color: profit >= 0 ? AppColors.success : AppColors.error),
            const SizedBox(width: 8),
            Text('Net ${profit >= 0 ? "Profit" : "Loss"}: ${AppFormatters.currency(profit.abs())}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                color: profit >= 0 ? AppColors.success : AppColors.error)),
          ]),
        ),
      ]),
    );
  }

  Widget _insightTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}
