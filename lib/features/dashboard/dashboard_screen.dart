import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_widgets.dart';

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
  }

  Future<void> _loadUserName() async {
    final appState = context.read<AppState>();
    final name = await appState.getSetting('businessName');
    if (mounted) {
      setState(() => _userName = name ?? '');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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
              Text(
                _getEmoji(),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
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
                      AppFormatters.date(DateTime.now()),
                      style: const TextStyle(
                        color: Color(0xFF818CF8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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
}

