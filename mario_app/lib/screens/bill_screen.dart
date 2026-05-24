import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/order.dart';
import '../utils/constants.dart';

class BillScreen extends StatefulWidget {
  final Order order;

  const BillScreen({super.key, required this.order});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  String _selectedPaymentMethod = 'cash';
  final _customerNameController = TextEditingController();
  bool _isGenerating = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'cash', 'name': 'Cash', 'icon': Icons.money},
    {'id': 'card', 'name': 'Card', 'icon': Icons.credit_card},
    {'id': 'upi', 'name': 'UPI', 'icon': Icons.qr_code},
  ];

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _generateBill() async {
    setState(() => _isGenerating = true);
    
    final auth = context.read<AuthProvider>();
    final data = context.read<DataProvider>();
    
    try {
      final invoiceNo = await data.getNextInvoiceNo(auth.currentStore!.id);
      
      final billData = {
        'orderId': widget.order.id,
        'tableNumber': widget.order.tableNumber,
        'invoiceNo': invoiceNo,
        'items': widget.order.items.map((i) => {
          'itemId': i.itemId,
          'quantity': i.quantity,
          'unitPrice': i.item.price,
        }).toList(),
        'subtotal': widget.order.totalAmount - widget.order.taxAmount,
        'taxTotal': widget.order.taxAmount,
        'discount': 0,
        'total': widget.order.totalAmount,
        'paymentMethod': _selectedPaymentMethod,
        'customerName': _customerNameController.text.isEmpty 
            ? null 
            : _customerNameController.text,
        'storeId': auth.currentStore!.id,
      };
      
      if (auth.currentStore?.remoteBillingEnabled == true) {
        await data.enqueueBill(billData);
      }
      await data.completeOrder(widget.order.id, paymentMethod: _selectedPaymentMethod);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill generated: $invoiceNo'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final subtotal = order.totalAmount - order.taxAmount;

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
        title: const Text('Generate Bill'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Table ${order.tableNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...order.items.map((item) {
                      final itemTotal = item.item.price * item.quantity;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} x ₹${item.item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${itemTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 32),
                    _buildBillRow('Subtotal', subtotal),
                    if (order.taxAmount > 0)
                      _buildBillRow('Tax', order.taxAmount),
                    const Divider(),
                    _buildBillRow('Total', order.totalAmount, isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._paymentMethods.map((method) {
              final isSelected = _selectedPaymentMethod == method['id'];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = method['id'];
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          method['icon'],
                          color: isSelected ? AppColors.primary : AppColors.gray600,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            method['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.dark : AppColors.gray700,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name (Optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateBill,
                child: _isGenerating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Generate Bill',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.dark : AppColors.gray600,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 20 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.primary : AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}