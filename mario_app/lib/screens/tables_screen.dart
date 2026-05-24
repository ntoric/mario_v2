import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/table.dart';
import '../models/order.dart';
import '../utils/constants.dart';
import '../main.dart';
import 'order_screen.dart';
import 'bill_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> with RouteAware {
  bool _isRefreshing = false;
  Timer? _silentUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      _startSilentUpdateTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopSilentUpdateTimer();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when this route becomes visible again
    _refreshData();
    _startSilentUpdateTimer();
  }

  @override
  void didPushNext() {
    // Called when navigating to another route
    _stopSilentUpdateTimer();
  }

  void _startSilentUpdateTimer() {
    _silentUpdateTimer?.cancel();
    _silentUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _silentRefreshData();
    });
  }

  void _stopSilentUpdateTimer() {
    _silentUpdateTimer?.cancel();
    _silentUpdateTimer = null;
  }

  Future<void> _silentRefreshData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.currentStore != null) {
      await context.read<DataProvider>().silentUpdateTablesAndOrders(auth.currentStore!.id);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    final auth = context.read<AuthProvider>();
    if (auth.currentStore != null) {
      await context.read<DataProvider>().loadTables(auth.currentStore!.id);
      await context.read<DataProvider>().loadOrders(auth.currentStore!.id);
    }
    setState(() => _isRefreshing = false);
  }

  void _showStoreSwitcher(BuildContext screenContext, AuthProvider auth) {
    final stores = auth.user?.stores ?? [];
    if (stores.isEmpty) return;

    showModalBottomSheet(
      context: screenContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final navigator = Navigator.of(screenContext);
        final scaffoldMessenger = ScaffoldMessenger.of(screenContext);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Switch Store',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a storefront to manage',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.gray600,
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stores.length,
                  itemBuilder: (itemBuilderContext, index) {
                    final store = stores[index];
                    final isCurrent = auth.currentStore?.id == store.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent 
                            ? AppColors.primary.withOpacity(0.2) 
                            : AppColors.gray100,
                        child: Icon(
                          Icons.storefront,
                          color: isCurrent ? AppColors.primary : AppColors.gray600,
                        ),
                      ),
                      title: Text(
                        store.name,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.dark,
                        ),
                      ),
                      subtitle: Text(
                        store.branch ?? store.location ?? 'Main Branch',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: AppColors.success)
                          : null,
                      onTap: () async {
                        navigator.pop(); // Dismiss bottom sheet
                        
                        // Show loading indicator using the captured navigator context
                        showDialog(
                          context: navigator.context,
                          barrierDismissible: false,
                          builder: (loadingContext) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        try {
                          await auth.switchStore(store);
                          if (mounted) {
                            final data = screenContext.read<DataProvider>();
                            await data.loadAllData(auth);
                            
                            // Pop loading using captured navigator
                            navigator.pop();
                            
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Switched to ${store.displayName}'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            navigator.pop(); // Pop loading using captured navigator
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error switching store: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showChangeTableDialog(Order order, List<TableModel> tables, DataProvider data) {
    final parentContext = context;
    final availableTables = tables.where((t) => 
      t.id != order.tableId && !data.isTableOccupied(t.id)
    ).toList();

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text('No available tables to move to'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        final navigator = Navigator.of(parentContext);
        final scaffoldMessenger = ScaffoldMessenger.of(parentContext);

        return AlertDialog(
          title: const Text('Move Order to Table'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: availableTables.length,
              itemBuilder: (itemBuilderContext, index) {
                final table = availableTables[index];
                return InkWell(
                  onTap: () async {
                    Navigator.pop(dialogContext); // Dismiss Move Order dialog using dialogContext
                    
                    // Show progress indicator overlay using captured navigator
                    showDialog(
                      context: navigator.context,
                      barrierDismissible: false,
                      builder: (loadingContext) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );

                    try {
                      final success = await data.moveOrderToTable(
                        order.id,
                        table.id,
                        table.number,
                      );
                      
                      // Dismiss progress indicator using captured navigator
                      navigator.pop();
                      
                      if (success) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Order moved to Table ${table.number}'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } else {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(data.error ?? 'Failed to move order.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    } catch (e) {
                      // Dismiss progress indicator using captured navigator
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gray300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${table.number}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                          ),
                        ),
                        Text(
                          '${table.seats} seats',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showTableOptions(TableModel table, Order? order, DataProvider data) {
    final parentContext = context;
    final auth = parentContext.read<AuthProvider>();
    
    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Table ${table.number}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    order != null ? 'Occupied' : 'Available',
                    style: TextStyle(
                      color: order != null ? AppColors.primary : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (order == null)
              ListTile(
                leading: const Icon(Icons.add_circle, color: AppColors.primary),
                title: const Text('Create Order'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (_) => OrderScreen(
                        table: table,
                        isNewOrder: true,
                      ),
                    ),
                  );
                },
              ),
            if (order != null) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.info),
                title: const Text('Edit Order'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (_) => OrderScreen(
                        table: table,
                        order: order,
                        isNewOrder: false,
                      ),
                    ),
                  );
                },
              ),
              if (auth.currentStore?.remoteBillingEnabled == true)
                ListTile(
                  leading: const Icon(Icons.receipt, color: AppColors.success),
                  title: const Text('Generate Bill'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      parentContext,
                      MaterialPageRoute(
                        builder: (_) => BillScreen(order: order),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppColors.warning),
                title: const Text('Move to Another Table'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showChangeTableDialog(order, data.tables, data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: AppColors.danger),
                title: const Text('Cancel Order'),
                onTap: () async {
                  final navigator = Navigator.of(parentContext);
                  final scaffoldMessenger = ScaffoldMessenger.of(parentContext);

                  Navigator.pop(sheetContext); // Dismiss bottom options sheet
                  
                  final confirm = await showDialog<bool>(
                    context: navigator.context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Cancel Order?'),
                      content: const Text('Are you sure you want to cancel this order?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('No'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          child: const Text('Yes, Cancel'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    // Show progress indicator overlay using captured navigator context
                    showDialog(
                      context: navigator.context,
                      barrierDismissible: false,
                      builder: (loadingContext) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );

                    try {
                      final success = await data.cancelOrder(order.id);
                      
                      // Dismiss progress indicator using captured navigator
                      navigator.pop();
                      
                      if (success) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Order cancelled and table released'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      } else {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(data.error ?? 'Failed to cancel order.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    } catch (e) {
                      // Dismiss progress indicator using captured navigator
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final tables = data.tables;
    
    final isTablet = ResponsiveHelper.isTablet(context);
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tables'),
            if (auth.currentStore != null)
              Text(
                auth.currentStore!.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppColors.gray600,
                ),
              ),
          ],
        ),
        actions: [
          if (auth.user != null &&
              (auth.user!.role == 'superadmin' || auth.user!.role == 'business_owner') &&
              (auth.user!.stores?.isNotEmpty ?? false))
            IconButton(
              icon: const Icon(Icons.storefront),
              tooltip: 'Switch Store',
              onPressed: () => _showStoreSwitcher(context, auth),
            ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: tables.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.table_restaurant_outlined,
                      size: 64,
                      color: AppColors.gray400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No tables available',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: isTablet ? 1.15 : 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final order = data.getOrderForTable(table.id);
                  final isOccupied = order != null;

                  return Card(
                    elevation: isOccupied ? 4 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isOccupied
                          ? const BorderSide(color: AppColors.primary, width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () => _showTableOptions(table, order, data),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: isOccupied
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    AppColors.primary.withOpacity(0.05),
                                  ],
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isOccupied
                                    ? AppColors.primary.withOpacity(0.2)
                                    : AppColors.gray100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.table_restaurant,
                                size: 24,
                                color: isOccupied
                                    ? AppColors.primary
                                    : AppColors.gray500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Table ${table.number}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${table.seats} seats',
                              style: TextStyle(
                                fontSize: 11,
                                color: isOccupied
                                    ? AppColors.primary
                                    : AppColors.gray600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOccupied
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.gray100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOccupied ? 'Occupied' : 'Available',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isOccupied
                                      ? AppColors.primary
                                      : AppColors.gray600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOccupied) ...[
                              const SizedBox(height: 4),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}