import 'package:flutter/material.dart';
import '../backend/backend_service.dart';
import '../models/table.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/bill.dart';
import '../models/statistics.dart';
import 'auth_provider.dart';

class DataProvider extends ChangeNotifier {
  final BackendService _backend = BackendService();
  
  List<TableModel> _tables = [];
  List<Category> _categories = [];
  List<Item> _items = [];
  List<Order> _orders = [];
  List<Bill> _bills = [];
  SystemStats? _stats;
  
  bool _isLoading = false;
  String? _error;

  List<TableModel> get tables => _tables;
  List<Category> get categories => _categories;
  List<Item> get items => _items;
  List<Order> get orders => _orders;
  List<Order> get activeOrders => _orders.where((o) => o.isActive).toList();
  List<Bill> get bills => _bills;
  SystemStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllData(AuthProvider auth) async {
    if (auth.currentStore == null) return;
    
    final storeId = auth.currentStore!.id;
    
    await Future.wait([
      loadTables(storeId),
      loadCategories(storeId),
      loadItems(storeId),
      loadOrders(storeId),
      loadBills(storeId),
    ]);
  }

  Future<void> loadTables(String storeId) async {
    try {
      final data = await _backend.tables.getTables(storeId);
      _tables = data.map((t) => TableModel.fromJson(t)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadCategories(String storeId) async {
    try {
      final data = await _backend.categories.getCategories(storeId);
      _categories = data.map((c) => Category.fromJson(c)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadItems(String storeId) async {
    try {
      final data = await _backend.items.getItems(storeId);
      _items = data.map((i) => Item.fromJson(i)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadOrders(String storeId) async {
    try {
      final data = await _backend.orders.getOrders(storeId);
      _orders = data.map((o) => Order.fromJson(o)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadBills(String storeId) async {
    try {
      final data = await _backend.bills.getBills(storeId);
      _bills = data.map((b) => Bill.fromJson(b)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadStats() async {
    try {
      final data = await _backend.system.getStats();
      _stats = SystemStats.fromJson(data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Order? getOrderForTable(String tableId) {
    try {
      return _orders.firstWhere(
        (o) => o.tableId == tableId && o.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  bool isTableOccupied(String tableId) {
    return getOrderForTable(tableId) != null;
  }

  Future<Order?> createOrder({
    required String tableId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double taxAmount,
    required String storeId,
  }) async {
    try {
      final orderData = {
        'tableId': tableId,
        'tableNumber': tableNumber,
        'items': items,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        'discountAmount': 0,
        'storeId': storeId,
      };
      
      final data = await _backend.orders.createOrder(
        _backend.currentUserId!,
        orderData,
      );
      
      final order = Order.fromJson(data);
      _orders.insert(0, order);
      notifyListeners();
      return order;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Order?> updateOrder({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double taxAmount,
    String? tableId,
    int? tableNumber,
  }) async {
    try {
      final orderData = {
        'items': items,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        if (tableId != null) 'tableId': tableId,
        if (tableNumber != null) 'tableNumber': tableNumber,
      };
      
      final data = await _backend.orders.updateOrder(orderId, orderData);
      final order = Order.fromJson(data);
      
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders[index] = order;
      }
      notifyListeners();
      return order;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> completeOrder(String orderId, {String? paymentMethod}) async {
    try {
      await _backend.orders.completeOrder(
        orderId,
        paymentMethod: paymentMethod,
      );
      
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders[index] = Order(
          id: _orders[index].id,
          storeId: _orders[index].storeId,
          tableId: _orders[index].tableId,
          tableNumber: _orders[index].tableNumber,
          items: _orders[index].items,
          status: 'completed',
          totalAmount: _orders[index].totalAmount,
          taxAmount: _orders[index].taxAmount,
          discountAmount: _orders[index].discountAmount,
          paymentMethod: paymentMethod,
          paymentStatus: 'paid',
          createdAt: _orders[index].createdAt,
          updatedAt: DateTime.now(),
          createdBy: _orders[index].createdBy,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      
      await _backend.orders.cancelOrder(orderId);
      
      // Reload orders from database to ensure perfect sync
      await loadOrders(order.storeId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> moveOrderToTable(String orderId, String newTableId, int newTableNumber) async {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      
      await _backend.orders.updateOrder(orderId, {
        'tableId': newTableId,
        'tableNumber': newTableNumber,
        'items': order.items.map((i) => {
          'itemId': i.itemId,
          'quantity': i.quantity,
          'item': i.item.toJson(),
        }).toList(),
        'totalAmount': order.totalAmount,
        'taxAmount': order.taxAmount,
      });
      
      // Reload orders from the database to ensure perfect state synchronization
      await loadOrders(order.storeId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String> getNextInvoiceNo(String storeId) async {
    return await _backend.bills.getNextInvoiceNo(storeId);
  }

  Future<Bill?> createBill(Map<String, dynamic> billData) async {
    try {
      final data = await _backend.bills.createBill(
        _backend.currentUserId!,
        billData,
      );
      
      final bill = Bill.fromJson(data);
      _bills.insert(0, bill);
      notifyListeners();
      return bill;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> enqueueBill(Map<String, dynamic> billData) async {
    try {
      await _backend.bills.enqueueBill(
        _backend.currentUserId!,
        billData,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Category?> createCategory({
    required String name,
    String? description,
    required String storeId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final categoryData = {
        'name': name,
        'description': description,
        'storeId': storeId,
      };
      final data = await _backend.categories.createCategory(categoryData);
      final category = Category.fromJson(data);
      _categories.add(category);
      _categories.sort((a, b) => a.name.compareTo(b.name));
      _isLoading = false;
      notifyListeners();
      return category;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCategory({
    required String categoryId,
    required String name,
    String? description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final categoryData = {
        'name': name,
        'description': description,
      };
      await _backend.categories.updateCategory(categoryId, categoryData);
      
      final index = _categories.indexWhere((c) => c.id == categoryId);
      if (index >= 0) {
        _categories[index] = Category(
          id: categoryId,
          storeId: _categories[index].storeId,
          name: name,
          description: description,
          isActive: _categories[index].isActive,
        );
        _categories.sort((a, b) => a.name.compareTo(b.name));
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _backend.categories.deleteCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Item?> createItem({
    required String categoryId,
    required String name,
    String? description,
    required double price,
    String? hsnCode,
    required double taxPercent,
    required String storeId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final itemData = {
        'storeId': storeId,
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'hsnCode': hsnCode,
        'taxPercent': taxPercent,
      };
      final data = await _backend.items.createItem(itemData);
      
      final category = _categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => Category(id: categoryId, storeId: storeId, name: '', isActive: true),
      );
      data['categoryName'] = category.name;
      
      final item = Item.fromJson(data);
      _items.add(item);
      _items.sort((a, b) => a.name.compareTo(b.name));
      _isLoading = false;
      notifyListeners();
      return item;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateItem({
    required String itemId,
    required String categoryId,
    required String name,
    String? description,
    required double price,
    String? hsnCode,
    required double taxPercent,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final itemData = {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'hsnCode': hsnCode,
        'taxPercent': taxPercent,
      };
      await _backend.items.updateItem(itemId, itemData);
      
      final index = _items.indexWhere((i) => i.id == itemId);
      if (index >= 0) {
        final category = _categories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => Category(id: categoryId, storeId: _items[index].storeId, name: '', isActive: true),
        );
        _items[index] = Item(
          id: itemId,
          storeId: _items[index].storeId,
          categoryId: categoryId,
          categoryName: category.name,
          name: name,
          description: description,
          price: price,
          hsnCode: hsnCode,
          taxPercent: taxPercent,
          isActive: _items[index].isActive,
        );
        _items.sort((a, b) => a.name.compareTo(b.name));
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _backend.items.deleteItem(itemId);
      _items.removeWhere((i) => i.id == itemId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> silentUpdateTablesAndOrders(String storeId) async {
    try {
      final tablesData = await _backend.tables.getTables(storeId);
      final ordersData = await _backend.orders.getOrders(storeId);
      
      final newTables = tablesData.map((t) => TableModel.fromJson(t)).toList();
      final newOrders = ordersData.map((o) => Order.fromJson(o)).toList();
      
      bool tablesChanged = false;
      if (newTables.length != _tables.length) {
        tablesChanged = true;
      } else {
        for (int i = 0; i < newTables.length; i++) {
          if (!_areTablesEqual(newTables[i], _tables[i])) {
            tablesChanged = true;
            break;
          }
        }
      }
      
      bool ordersChanged = false;
      if (newOrders.length != _orders.length) {
        ordersChanged = true;
      } else {
        for (int i = 0; i < newOrders.length; i++) {
          if (!_areOrdersEqual(newOrders[i], _orders[i])) {
            ordersChanged = true;
            break;
          }
        }
      }
      
      if (tablesChanged || ordersChanged) {
        _tables = newTables;
        _orders = newOrders;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Silent update failed: $e');
    }
    return false;
  }

  bool _areTablesEqual(TableModel a, TableModel b) {
    return a.id == b.id &&
        a.storeId == b.storeId &&
        a.number == b.number &&
        a.seats == b.seats &&
        a.isActive == b.isActive;
  }

  bool _areOrdersEqual(Order a, Order b) {
    if (a.id != b.id ||
        a.storeId != b.storeId ||
        a.tableId != b.tableId ||
        a.tableNumber != b.tableNumber ||
        a.status != b.status ||
        a.totalAmount != b.totalAmount ||
        a.taxAmount != b.taxAmount ||
        a.discountAmount != b.discountAmount ||
        a.paymentMethod != b.paymentMethod ||
        a.paymentStatus != b.paymentStatus ||
        a.createdBy != b.createdBy ||
        a.items.length != b.items.length) {
      return false;
    }
    
    for (int i = 0; i < a.items.length; i++) {
      final itemA = a.items[i];
      final itemB = b.items[i];
      if (itemA.itemId != itemB.itemId ||
          itemA.quantity != itemB.quantity ||
          itemA.unitPrice != itemB.unitPrice ||
          itemA.taxPercent != itemB.taxPercent ||
          itemA.notes != itemB.notes ||
          itemA.item.name != itemB.item.name ||
          itemA.item.price != itemB.item.price) {
        return false;
      }
    }
    
    return true;
  }
}