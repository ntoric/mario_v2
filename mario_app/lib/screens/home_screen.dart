import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'tables_screen.dart';
import 'orders_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'categories_items_screen.dart';
import 'parcel_order_screen.dart';
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isCheckingStore = true;
  Timer? _storeStatusCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkStoreStatus();
    _startPeriodicStoreCheck();
  }

  @override
  void dispose() {
    _storeStatusCheckTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicStoreCheck() {
    // Check store status every 30 seconds - refresh user data from server
    _storeStatusCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final auth = context.read<AuthProvider>();
      await auth.refreshUser();
      _checkStoreStatus();
    });
  }

  Future<void> _checkStoreStatus() async {
    final auth = context.read<AuthProvider>();
    final store = auth.currentStore;
    final user = auth.user;

    // If user is not superadmin and store is inactive, show support page
    if (user?.role != 'superadmin' && store != null && !store.isActive) {
      // Fetch support config
      try {
        final response = await http.get(
          Uri.parse('${auth.backend.api.baseUrl}/support-config'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => SupportScreen(
                  email: data['email'] ?? '',
                  phone: data['phone'] ?? '',
                  whatsappLink: data['whatsappLink'] ?? '',
                  storeName: store.name,
                  storeBranch: store.branch,
                ),
              ),
            );
          }
          return;
        }
      } catch (e) {
        // If support config fetch fails, show support page with empty values
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SupportScreen(
                email: '',
                phone: '',
                whatsappLink: '',
                storeName: store.name,
                storeBranch: store.branch,
              ),
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingStore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStore) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final canViewStats = auth.canViewStats;

    final screens = [
      const TablesScreen(),
      const OrdersScreen(),
      const HistoryScreen(),
      if (canViewStats) const StatisticsScreen(),
      const CategoriesItemsScreen(),
      ParcelOrderScreen(
        onOrderSuccess: () {
          setState(() => _currentIndex = 2); // Navigate to History
        },
      ),
      const SettingsScreen(),
    ];

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.table_restaurant_outlined),
        selectedIcon: Icon(Icons.table_restaurant),
        label: 'Tables',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_outlined),
        selectedIcon: Icon(Icons.receipt),
        label: 'Orders',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'History',
      ),
      if (canViewStats)
        const NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Stats',
        ),
      const NavigationDestination(
        icon: Icon(Icons.restaurant_menu_outlined),
        selectedIcon: Icon(Icons.restaurant_menu),
        label: 'Menu',
      ),
      const NavigationDestination(
        icon: Icon(Icons.shopping_bag_outlined),
        selectedIcon: Icon(Icons.shopping_bag),
        label: 'Parcel',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isTablet || isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: isDesktop,
              minExtendedWidth: 200,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              backgroundColor: AppColors.light,
              selectedIconTheme: const IconThemeData(
                color: AppColors.primary,
                size: 28,
              ),
              unselectedIconTheme: const IconThemeData(
                color: AppColors.gray500,
                size: 24,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.gray500,
              ),
              destinations: destinations.map((d) {
                return NavigationRailDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: Text(d.label!),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: destinations,
      ),
    );
  }
}