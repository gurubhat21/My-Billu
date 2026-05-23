import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_state.dart';
import 'core/database/database_helper.dart';
import 'core/database/data_path_native.dart' if (dart.library.js_interop) 'core/database/data_path_web.dart'
    as data_path;
import 'core/utils/app_constants.dart';
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
import 'features/onboarding/onboarding_screen.dart';
import 'features/audit/audit_trail_screen.dart';
import 'features/cash_book/cash_book_screen.dart';
import 'features/settings/keyboard_shortcuts_screen.dart';
import 'features/serial_tracker/serial_tracker_screen.dart';
import 'features/supplier_payments/supplier_payment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for Windows/Linux desktop only
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Load saved data path for Windows
    await data_path.loadDataPathConfig();
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

/// Gate that shows Onboarding → Login → MainShell
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loggedIn = false;
  bool? _onboardingDone; // null = loading, true/false = checked
  bool _expired = false;
  String _expiryDateStr = '';

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final appState = context.read<AppState>();
    final result = await appState.getSetting('onboarding_complete');

    // Check expiry on Windows & Android only
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.android)) {
      await _checkExpiry(appState);
    }

    setState(() => _onboardingDone = result == 'true');
  }

  Future<void> _checkExpiry(AppState appState) async {
    String? expiryStr = await appState.getSetting('app_expiry_date');
    if (expiryStr == null || expiryStr.isEmpty) {
      // First launch — set expiry to 1 year from now
      final defaultExpiry = DateTime.now().add(const Duration(days: 365));
      expiryStr = defaultExpiry.toIso8601String().split('T').first;
      await appState.saveSetting('app_expiry_date', expiryStr);
    }
    _expiryDateStr = expiryStr;
    final expiryDate = DateTime.tryParse(expiryStr);
    if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
      _expired = true;
    }
  }

  void _onExpiryExtended() {
    setState(() {
      _expired = false;
    });
    _checkOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_onboardingDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    // Expired state (Windows/Android only)
    if (_expired) {
      return ExpiredScreen(
        expiryDate: _expiryDateStr,
        onExtended: _onExpiryExtended,
      );
    }
    // Show onboarding for first-time users
    if (!_onboardingDone!) {
      return OnboardingScreen(onComplete: () => setState(() => _onboardingDone = true));
    }
    // Show login
    if (!_loggedIn) {
      return LoginScreen(onLogin: () => setState(() => _loggedIn = true));
    }
    return MainShell(onLogout: () => setState(() => _loggedIn = false));
  }
}

/// Blocking screen shown when the app license has expired
class ExpiredScreen extends StatelessWidget {
  final String expiryDate;
  final VoidCallback onExtended;
  const ExpiredScreen({super.key, required this.expiryDate, required this.onExtended});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: Center(
          child: Container(
            width: 420, padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock, size: 64, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              const Text('License Expired', style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.error)),
              const SizedBox(height: 12),
              Text('Your app license expired on $expiryDate.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Text('Please contact the developer to renew.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('9449831316', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
              const SizedBox(height: 8),
              const Text('Sumukha Tech Solutions',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _showMasterPasswordDialog(context),
                icon: const Icon(Icons.key, size: 18),
                label: const Text('Enter Activation Code'),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  void _showMasterPasswordDialog(BuildContext context) {
    final pwdCtrl = TextEditingController();
    showDialog(context: context, builder: (dCtx) => AlertDialog(
      title: const Text('Enter Master Password'),
      content: TextField(
        controller: pwdCtrl,
        obscureText: true,
        decoration: InputDecoration(
          hintText: 'Master password',
          prefixIcon: const Icon(Icons.lock),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (pwdCtrl.text == AppConstants.masterPassword) {
              Navigator.pop(dCtx);
              _showDatePickerDialog(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Invalid password'), backgroundColor: AppColors.error));
            }
          },
          child: const Text('Verify'),
        ),
      ],
    ));
  }

  void _showDatePickerDialog(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      helpText: 'SET NEW EXPIRY DATE',
    );
    if (picked != null && context.mounted) {
      final newExpiry = picked.toIso8601String().split('T').first;
      final appState = context.read<AppState>();
      await appState.saveSetting('app_expiry_date', newExpiry);
      onExtended();
    }
  }
}

class MainShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainShell({super.key, required this.onLogout});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<ShortcutBinding> _customShortcuts = [];
  bool _shortcutsLoaded = false;

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
    AuditTrailScreen(),         // 16
    CashBookScreen(),           // 17
    SerialTrackerScreen(),      // 18
    SupplierPaymentScreen(),    // 19
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
    _DrawerItem(icon: Icons.payment, label: 'Supplier Payments', index: 19),
    _DrawerItem(icon: Icons.description, label: 'Quotations', index: 7),
    _DrawerItem(icon: Icons.money_off, label: 'Expenses', index: 8),
    _DrawerItem(icon: Icons.account_balance_wallet, label: 'Cash & Bank Book', index: 17),
    _DrawerItem(icon: Icons.repeat, label: 'Recurring Bills', index: 14),
    _DrawerItem(icon: Icons.assignment_return, label: 'Credit Notes', index: 10),
    _DrawerItem(icon: Icons.keyboard_return, label: 'Purchase Returns', index: 11),
    _DrawerItem(icon: Icons.account_balance_wallet, label: 'Customer Ledger', index: 12),
    _DrawerItem(icon: Icons.bar_chart, label: 'Reports', index: 9),
    _DrawerItem(icon: Icons.history, label: 'Audit Trail', index: 16),
    _DrawerItem(icon: Icons.qr_code_scanner, label: 'Serial Tracker', index: 18),
    _DrawerItem(icon: Icons.settings, label: 'Settings', index: 15),
  ];

  void _goTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.logout, color: AppColors.error), SizedBox(width: 10),
          Text('Logout')]),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onLogout();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shortcutsLoaded) {
      _shortcutsLoaded = true;
      _loadCustomShortcuts();
    }
  }

  Future<void> _loadCustomShortcuts() async {
    final appState = context.read<AppState>();
    final shortcuts = await loadShortcuts(appState);
    if (mounted) setState(() => _customShortcuts = shortcuts);
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings() {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final sc in _customShortcuts) {
      bindings[sc.toActivator()] = () => _goTo(sc.screenIndex);
    }
    // Always keep the help shortcut
    bindings[const SingleActivator(LogicalKeyboardKey.slash, control: true, shift: true)] = () => _showShortcutsHelp();
    return bindings;
  }

  void _showShortcutsHelp() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.keyboard, color: AppColors.primary), SizedBox(width: 10), Text('Keyboard Shortcuts')]),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _shortcutSection('Navigation', [
          ..._customShortcuts.map((sc) => _shortcutRow(sc.displayString, sc.label)),
        ]),
        _shortcutSection('Actions', [
          _shortcutRow('Ctrl + F', 'Global Search'),
          _shortcutRow('Ctrl + Shift + /', 'Show this help'),
        ]),
      ]))),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Widget _shortcutSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary))),
      ...children,
      const Divider(height: 16),
    ]);
  }

  Widget _shortcutRow(String keys, String action) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
          child: Text(keys, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'monospace', color: AppColors.primary))),
        const SizedBox(width: 14),
        Expanded(child: Text(action, style: const TextStyle(fontSize: 13))),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // On back press at root, show exit dialog
        if (_currentIndex != 0) {
          // If not on dashboard, go to dashboard first
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.exit_to_app, color: AppColors.error), SizedBox(width: 10),
              Text('Exit My Billu?')]),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exit')),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: CallbackShortcuts(
        bindings: _buildShortcutBindings(),
        child: Focus(
          autofocus: true,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;

      if (isWide) {
        // Desktop / Web wide layout - custom scrollable sidebar
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final appState = context.watch<AppState>();
        return Scaffold(
          body: Row(children: [
            Container(
              width: 220,
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: Column(children: [
                // Logo header
                InkWell(
                  onTap: () => _showFYPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text('My Billu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                    ]),
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                // Scrollable menu items
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: _drawerItems.map((item) {
                      final isSelected = _currentIndex == item.index;
                      // Compute badges
                      int badge = 0;
                      if (item.index == 5) badge = appState.items.where((i) => i.stockQuantity < 10).length;
                      else if (item.index == 3) badge = appState.bills.where((b) => b.status == BillStatus.unpaid || b.status == BillStatus.partial).length;
                      else if (item.index == 14) badge = appState.recurringBills.where((rb) => rb.isActive && DateTime.now().isAfter(rb.nextDueDate)).length;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -2),
                          leading: Icon(item.icon, size: 20,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54)),
                          title: Text(item.label, style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87),
                          )),
                          trailing: badge > 0 ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onTap: () => _goTo(item.index),
                        ),
                      );
                    }).toList()),
                  ),
                ),
                // Footer with Logout
                Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Text('Sumukha Tech Solutions', style: TextStyle(
                    fontSize: 10, color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black26, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
            VerticalDivider(width: 1, color: isDark
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

  void _showFYPicker(BuildContext context) {
    final appState = context.read<AppState>();
    final now = DateTime.now();
    final currentFYStart = now.month >= 4 ? now.year : now.year - 1;
    final fyOptions = List.generate(8, (i) {
      final y = currentFYStart - 5 + i;
      return '$y-${(y + 1).toString().substring(2)}';
    });

    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.date_range, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          const Text('Select Financial Year'),
        ]),
        content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Choose the financial year (April - March) you want to work with.',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          ...fyOptions.map((fy) {
            final isCurrent = fy == '$currentFYStart-${(currentFYStart + 1).toString().substring(2)}';
            return Padding(padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await appState.saveSetting('financial_year', fy);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 10),
                        Text('Financial Year set to FY $fy'),
                      ]),
                      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? AppColors.primary : Colors.grey.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Icon(Icons.calendar_month, size: 18, color: isCurrent ? AppColors.primary : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Text('FY $fy', style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? AppColors.primary : null, fontSize: 14))),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  ]),
                ),
              ));
          }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      );
    });
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark
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
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showFYPicker(context);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 28),
              ),
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
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54)),
                title: Text(item.label, style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87),
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

        // Footer with Logout
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmLogout(context);
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text('Sumukha Tech Solutions', style: TextStyle(
            fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black38, fontWeight: FontWeight.w500)),
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


