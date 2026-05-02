import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_state.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/billing/billing_screen.dart';
import 'features/items/items_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for Windows/Linux desktop
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadAll(),
      child: MaterialApp(
        title: 'My Billu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    BillingScreen(),
    ItemsScreen(),
    CustomersScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  final _navItems = const [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'New Bill'),
    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
    NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'History'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;

      if (isWide) {
        // Desktop / Web wide layout - side navigation rail
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
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
              destinations: _navItems.map((n) => NavigationRailDestination(
                icon: n.icon, selectedIcon: n.selectedIcon, label: Text(n.label),
              )).toList(),
            ),
            VerticalDivider(width: 1, color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
            Expanded(child: _screens[_currentIndex]),
          ]),
        );
      }

      // Mobile / narrow layout - bottom navigation
      return Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: _navItems,
          height: 70,
        ),
      );
    });
  }
}
