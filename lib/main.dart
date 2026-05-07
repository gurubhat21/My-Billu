import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_state.dart';
import 'core/models/bill.dart';
import 'features/login/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/billing/billing_screen.dart';
import 'features/items/items_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/purchase/purchase_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/quotation/quotation_screen.dart';
import 'features/expenses/expense_screen.dart';
import 'features/credit_notes/credit_note_screen.dart';
import 'features/purchase_returns/purchase_return_screen.dart';
import 'features/customer_ledger/customer_ledger_screen.dart';
import 'features/suppliers/supplier_screen.dart';
import 'features/recurring/recurring_bill_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for Windows/Linux desktop only
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyBilluApp());
}

class MyBilluApp extends StatelessWidget {
  const MyBilluApp({super.key});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadAll(),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, __) {
          return MaterialApp(
            title: 'My Billu',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Gate that shows Login first, then MainShell after authentication
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return LoginScreen(onLogin: () => setState(() => _loggedIn = true));
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // All screens indexed
  static const _allScreens = [
    DashboardScreen(),          // 0
    BillingScreen(),            // 1 - Sales
    PurchaseScreen(),           // 2 - Purchase
    HistoryScreen(),            // 3 - Payments
    ItemsScreen(),              // 4
    StockScreen(),              // 5
    CustomersScreen(),          // 6
    QuotationScreen(),          // 7
    ExpenseScreen(),            // 8
    ReportsScreen(),            // 9
    CreditNoteScreen(),         // 10
    PurchaseReturnScreen(),     // 11
    CustomerLedgerScreen(),     // 12
    SupplierScreen(),           // 13
    RecurringBillScreen(),      // 14
    SettingsScreen(),           // 15
  ];

  static const _bottomBarMapping = [0, 1, 2, 3];

  int get _bottomBarIndex {
    final idx = _bottomBarMapping.indexOf(_currentIndex);
    return idx >= 0 ? idx : -1;
  }

  static const _drawerItems = [
    _DrawerItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
    _DrawerItem(icon: Icons.add_circle, label: 'New Bill / Sales', index: 1),
    _DrawerItem(icon: Icons.shopping_bag, label: 'Purchase', index: 2),
    _DrawerItem(icon: Icons.receipt_long, label: 'Payments / History', index: 3),
    _DrawerItem(icon: Icons.inventory_2, label: 'Items', index: 4),
    _DrawerItem(icon: Icons.warehouse, label: 'Stock', index: 5),
    _DrawerItem(icon: Icons.people, label: 'Customers', index: 6),
    _DrawerItem(icon: Icons.local_shipping, label: 'Suppliers', index: 13),
    _DrawerItem(icon: Icons.description, label: 'Quotations', index: 7),
    _DrawerItem(icon: Icons.money_off, label: 'Expenses', index: 8),
    _DrawerItem(icon: Icons.repeat, label: 'Recurring Bills', index: 14),
    _DrawerItem(icon: Icons.assignment_return, label: 'Credit Notes', index: 10),
    _DrawerItem(icon: Icons.keyboard_return, label: 'Purchase Returns', index: 11),
    _DrawerItem(icon: Icons.account_balance_wallet, label: 'Customer Ledger', index: 12),
    _DrawerItem(icon: Icons.bar_chart, label: 'Reports', index: 9),
    _DrawerItem(icon: Icons.settings, label: 'Settings', index: 15),
  ];

  void _goTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;

      if (isWide) {
        // Desktop / Web wide layout - permanent side navigation rail
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => _goTo(i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface : AppColors.lightSurface,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 8),
                  const Text('My Billu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
                ]),
              ),
              destinations: _drawerItems.map((d) => NavigationRailDestination(
                icon: Icon(d.icon), selectedIcon: Icon(d.icon), label: Text(d.label),
              )).toList(),
            ),
            VerticalDivider(width: 1, color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: ValueKey(_currentIndex), child: _allScreens[_currentIndex]),
            )),
          ]),
        );
      }

      // Mobile / narrow layout - drawer + bottom bar
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 26),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
            ).createShader(bounds),
            child: const Text('My Billu', style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white, letterSpacing: -0.5)),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.search, size: 22),
              tooltip: 'Global Search',
              onPressed: () {
                final appState = context.read<AppState>();
                showSearch(context: context, delegate: _GlobalSearchDelegate(appState, _goTo));
              }),
            IconButton(
              icon: Icon(
                MyBilluApp.themeNotifier.value == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                size: 22),
              tooltip: 'Toggle Theme',
              onPressed: () {
                final isDark = MyBilluApp.themeNotifier.value == ThemeMode.dark;
                MyBilluApp.themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                setState(() {});
              }),
          ],
        ),
        drawer: _buildDrawer(context),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: ValueKey(_currentIndex), child: _allScreens[_currentIndex]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _bottomBarIndex >= 0 ? _bottomBarIndex : 0,
          onDestinationSelected: (i) => _goTo(_bottomBarMapping[i]),
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'New Bill',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'Purchase',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Payments',
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F0F23) : Colors.white,
      child: Column(children: [
        // Drawer Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A3E), Color(0xFF0F0F23)],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFFA855F7)],
              ).createShader(bounds),
              child: const Text('My Billu', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 4),
            Text('Smart Billing Software', style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
          ]),
        ),

        // Menu Items
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          ..._drawerItems.map((item) {
            final isSelected = _currentIndex == item.index;
            final appState = context.watch<AppState>();
            // Compute badges
            int badge = 0;
            if (item.index == 5) { // Stock
              badge = appState.items.where((i) => i.stockQuantity < 10).length;
            } else if (item.index == 3) { // Payments
              badge = appState.bills.where((b) => b.status == BillStatus.unpaid || b.status == BillStatus.partial).length;
            } else if (item.index == 14) { // Recurring Bills
              badge = appState.recurringBills.where((rb) => rb.isActive && DateTime.now().isAfter(rb.nextDueDate)).length;
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(item.icon, size: 22,
                  color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.6)),
                title: Text(item.label, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.8),
                )),
                trailing: badge > 0 ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  _goTo(item.index);
                  Navigator.pop(context); // Close drawer
                },
              ),
            );
          }),
        ])),

        // Footer
        Padding(padding: const EdgeInsets.all(16),
          child: Text('Sumukha Tech Solutions', style: TextStyle(
            fontSize: 11, color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final int index;
  const _DrawerItem({required this.icon, required this.label, required this.index});
}

// ===== GLOBAL SEARCH =====
class _GlobalSearchDelegate extends SearchDelegate<String> {
  final AppState appState;
  final void Function(int) goTo;

  _GlobalSearchDelegate(this.appState, this.goTo);

  @override
  String get searchFieldLabel => 'Search items, customers, bills...';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildSuggestionList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestionList(context);

  Widget _buildSuggestionList(BuildContext context) {
    if (query.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('Type to search across items, customers, suppliers & bills',
          style: TextStyle(color: Colors.grey.withValues(alpha: 0.5))),
      ]));
    }

    final q = query.toLowerCase();
    final results = <_SearchResult>[];

    // Items
    for (final item in appState.items) {
      if (item.name.toLowerCase().contains(q) || (item.hsnCode ?? '').toLowerCase().contains(q)) {
        results.add(_SearchResult(Icons.inventory_2, item.name, 'Item • ₹${item.price.toStringAsFixed(2)} • Stock: ${item.stockQuantity}', 4));
      }
    }
    // Customers
    for (final c in appState.customers) {
      if (c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q)) {
        results.add(_SearchResult(Icons.person, c.name, 'Customer • ${c.phone ?? "No phone"}', 6));
      }
    }
    // Suppliers
    for (final s in appState.suppliers) {
      if (s.name.toLowerCase().contains(q) || (s.phone ?? '').contains(q)) {
        results.add(_SearchResult(Icons.local_shipping, s.name, 'Supplier • ${s.phone ?? "No phone"}', 13));
      }
    }
    // Bills
    for (final b in appState.bills) {
      if (b.billNumber.toLowerCase().contains(q) || (b.customerName ?? '').toLowerCase().contains(q)) {
        results.add(_SearchResult(Icons.receipt, b.billNumber, 'Bill • ${b.customerName ?? "Walk-in"} • ₹${b.totalAmount.toStringAsFixed(2)}', 3));
      }
    }

    if (results.isEmpty) {
      return Center(child: Text('No results for "$query"', style: TextStyle(color: Colors.grey.withValues(alpha: 0.5))));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        return ListTile(
          leading: Icon(r.icon, color: AppColors.primary),
          title: Text(r.title),
          subtitle: Text(r.subtitle, style: const TextStyle(fontSize: 12)),
          onTap: () { close(context, ''); goTo(r.screenIndex); },
        );
      },
    );
  }
}

class _SearchResult {
  final IconData icon;
  final String title;
  final String subtitle;
  final int screenIndex;
  _SearchResult(this.icon, this.title, this.subtitle, this.screenIndex);
}
