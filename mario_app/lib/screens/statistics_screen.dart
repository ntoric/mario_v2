import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../utils/constants.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    final data = context.read<DataProvider>();
    if (auth.currentStore != null) {
      await Future.wait([
        data.loadStats(),
        data.loadBills(auth.currentStore!.id),
        data.loadOrders(auth.currentStore!.id),
      ]);
    } else {
      await data.loadStats();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final stats = data.stats;
    final bills = data.bills;
    
    final totalRevenue = bills.fold<double>(
      0,
      (sum, bill) => sum + bill.total,
    );
    
    final completedOrders = data.orders.where((o) => o.isCompleted).length;
    final activeOrders = data.orders.where((o) => o.isActive).length;
    
    final paymentMethods = <String, double>{};
    for (final bill in bills) {
      final method = bill.paymentMethod ?? 'Unknown';
      paymentMethods[method] = (paymentMethods[method] ?? 0) + bill.total;
    }

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
        title: const Text('Statistics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
          ),
        ],
      ),
      body: _isLoading || stats == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Overview'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: ResponsiveHelper.isTablet(context) ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard(
                        'Total Revenue',
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        Icons.currency_rupee,
                        AppColors.success,
                      ),
                      _buildStatCard(
                        'Total Orders',
                        '${data.orders.length}',
                        Icons.receipt,
                        AppColors.primary,
                      ),
                      _buildStatCard(
                        'Completed',
                        '$completedOrders',
                        Icons.check_circle,
                        AppColors.info,
                      ),
                      _buildStatCard(
                        'Active',
                        '$activeOrders',
                        Icons.hourglass_top,
                        AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('System Statistics'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildStatRow('Users', stats.users, Icons.people),
                          _buildStatRow('Stores', stats.stores, Icons.store),
                          _buildStatRow('Categories', stats.categories, Icons.category),
                          _buildStatRow('Items', stats.items, Icons.fastfood),
                          _buildStatRow('Tables', stats.tables, Icons.table_restaurant),
                          _buildStatRow('Bills', stats.bills, Icons.receipt_long),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (paymentMethods.isNotEmpty) ...[
                    _buildSectionTitle('Payment Methods'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: paymentMethods.entries.map((entry) {
                            final percentage = totalRevenue > 0
                                ? (entry.value / totalRevenue * 100)
                                : 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '₹${entry.value.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
                                        style: const TextStyle(
                                          color: AppColors.gray600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: AppColors.gray200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle('Recent Bills'),
                  if (bills.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No bills yet',
                            style: TextStyle(color: AppColors.gray600),
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bills.take(10).length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final bill = bills[index];
                          final dateFormat = DateFormat('MMM dd, HH:mm');
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.success.withOpacity(0.1),
                              child: const Icon(
                                Icons.receipt,
                                color: AppColors.success,
                              ),
                            ),
                            title: Text(bill.invoiceNo ?? 'Unknown'),
                            subtitle: Text(
                              'Table ${bill.tableNumber} • ${dateFormat.format(bill.generatedAt)}',
                            ),
                            trailing: Text(
                              '₹${bill.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.gray600,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gray600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.gray700,
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}