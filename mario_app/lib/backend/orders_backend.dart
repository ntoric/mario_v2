import 'package:uuid/uuid.dart';
import 'database_service.dart';

class OrdersBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();

  OrdersBackend(this._db);

  Future<List<Map<String, dynamic>>> getOrders(
    String storeId, {
    String? status,
  }) async {
    var sql = '''
      SELECT 
        o.*,
        COALESCE(
          json_agg(
            json_build_object(
              'itemId', oi.item_id,
              'quantity', oi.quantity,
              'unitPrice', oi.unit_price,
              'taxPercent', oi.tax_percent,
              'notes', oi.notes,
              'item', json_build_object(
                'id', i.id,
                'storeId', i.store_id,
                'categoryId', i.category_id,
                'name', i.name,
                'price', i.price,
                'description', i.description,
                'hsnCode', i.hsn_code,
                'taxPercent', i.tax_percent,
                'isActive', i.is_active
              )
            ) ORDER BY oi.id
          ) FILTER (WHERE oi.id IS NOT NULL),
          '[]'
        ) as items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN items i ON oi.item_id = i.id
      WHERE o.store_id = @storeId
    ''';

    final params = <String, dynamic>{'storeId': storeId};

    if (status != null) {
      sql += ' AND o.status = @status';
      params['status'] = status;
    }

    sql += ' GROUP BY o.id ORDER BY o.created_at DESC';

    return await _db.query(sql, params);
  }

  Future<Map<String, dynamic>> createOrder(
    String userId,
    Map<String, dynamic> orderData,
  ) async {
    return await _db.transaction(() async {
      final id = _uuid.v4();

      await _db.execute('''
        INSERT INTO orders (
          id, store_id, table_id, table_number, status,
          total_amount, tax_amount, discount_amount, payment_method, created_by
        ) VALUES (
          @id, @storeId, @tableId, @tableNumber, 'active',
          @totalAmount, @taxAmount, @discountAmount, @paymentMethod, @createdBy
        )
      ''', {
        'id': id,
        'storeId': orderData['storeId'],
        'tableId': orderData['tableId'],
        'tableNumber': orderData['tableNumber'],
        'totalAmount': orderData['totalAmount'],
        'taxAmount': orderData['taxAmount'] ?? 0,
        'discountAmount': orderData['discountAmount'] ?? 0,
        'paymentMethod': orderData['paymentMethod'],
        'createdBy': userId,
      });

      // Insert order items
      for (final item in (orderData['items'] as List)) {
        await _db.execute('''
          INSERT INTO order_items (
            order_id, item_id, quantity, unit_price, tax_percent, notes
          ) VALUES (
            @orderId, @itemId, @quantity, @unitPrice, @taxPercent, @notes
          )
        ''', {
          'orderId': id,
          'itemId': item['itemId'],
          'quantity': item['quantity'],
          'unitPrice': item['item']['price'],
          'taxPercent': item['item']['taxPercent'] ?? 0,
          'notes': item['notes'],
        });
      }

      // Return the complete order
      final result = await _db.queryOne('''
        SELECT 
          o.*,
          COALESCE(
            json_agg(
              json_build_object(
                'itemId', oi.item_id,
                'quantity', oi.quantity,
                'unitPrice', oi.unit_price,
                'taxPercent', oi.tax_percent,
                'notes', oi.notes,
                'item', json_build_object(
                  'id', i.id,
                  'storeId', i.store_id,
                  'categoryId', i.category_id,
                  'name', i.name,
                  'price', i.price,
                  'description', i.description,
                  'hsnCode', i.hsn_code,
                  'taxPercent', i.tax_percent,
                  'isActive', i.is_active
                )
              )
            ) FILTER (WHERE oi.id IS NOT NULL),
            '[]'
          ) as items
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN items i ON oi.item_id = i.id
        WHERE o.id = @orderId
        GROUP BY o.id
      ''', {'orderId': id});

      return result!;
    });
  }

  Future<Map<String, dynamic>> updateOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    return await _db.transaction(() async {
      // Update order items if provided
      if (orderData['items'] != null) {
        await _db.execute(
          'DELETE FROM order_items WHERE order_id = @orderId',
          {'orderId': orderId},
        );

        for (final item in (orderData['items'] as List)) {
          await _db.execute('''
            INSERT INTO order_items (
              order_id, item_id, quantity, unit_price, tax_percent, notes
            ) VALUES (
              @orderId, @itemId, @quantity, @unitPrice, @taxPercent, @notes
            )
          ''', {
            'orderId': orderId,
            'itemId': item['itemId'],
            'quantity': item['quantity'],
            'unitPrice': item['unitPrice'] ?? item['item']['price'],
            'taxPercent': item['taxPercent'] ?? 0,
            'notes': item['notes'],
          });
        }
      }

      // Build update fields dynamically
      final updates = <String>[];
      final params = <String, dynamic>{'orderId': orderId};

      if (orderData['totalAmount'] != null) {
        updates.add('total_amount = @totalAmount');
        params['totalAmount'] = orderData['totalAmount'];
      }
      if (orderData['taxAmount'] != null) {
        updates.add('tax_amount = @taxAmount');
        params['taxAmount'] = orderData['taxAmount'];
      }
      if (orderData['discountAmount'] != null) {
        updates.add('discount_amount = @discountAmount');
        params['discountAmount'] = orderData['discountAmount'];
      }
      if (orderData['tableId'] != null) {
        updates.add('table_id = @tableId');
        params['tableId'] = orderData['tableId'];
      }
      if (orderData['tableNumber'] != null) {
        updates.add('table_number = @tableNumber');
        params['tableNumber'] = orderData['tableNumber'];
      }

      updates.add('updated_at = CURRENT_TIMESTAMP');

      if (updates.isNotEmpty) {
        await _db.execute('''
          UPDATE orders SET ${updates.join(', ')}
          WHERE id = @orderId
        ''', params);
      }

      // Return updated order
      final result = await _db.queryOne('''
        SELECT 
          o.*,
          COALESCE(
            json_agg(
              json_build_object(
                'itemId', oi.item_id,
                'quantity', oi.quantity,
                'unitPrice', oi.unit_price,
                'taxPercent', oi.tax_percent,
                'notes', oi.notes,
                'item', json_build_object(
                  'id', i.id,
                  'storeId', i.store_id,
                  'categoryId', i.category_id,
                  'name', i.name,
                  'price', i.price,
                  'description', i.description,
                  'hsnCode', i.hsn_code,
                  'taxPercent', i.tax_percent,
                  'isActive', i.is_active
                )
              )
            ) FILTER (WHERE oi.id IS NOT NULL),
            '[]'
          ) as items
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN items i ON oi.item_id = i.id
        WHERE o.id = @orderId
        GROUP BY o.id
      ''', {'orderId': orderId});

      return result!;
    });
  }

  Future<void> completeOrder(
    String orderId, {
    String? paymentMethod,
  }) async {
    await _db.execute('''
      UPDATE orders 
      SET status = 'completed', 
          payment_status = 'paid', 
          payment_method = @paymentMethod,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = @orderId
    ''', {
      'orderId': orderId,
      'paymentMethod': paymentMethod,
    });
  }

  Future<void> cancelOrder(String orderId) async {
    await _db.execute('''
      UPDATE orders 
      SET status = 'cancelled',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = @orderId
    ''', {'orderId': orderId});
  }

  Future<Map<String, dynamic>?> getOrderForTable(String tableId) async {
    final result = await _db.queryOne('''
      SELECT 
        o.*,
        COALESCE(
          json_agg(
            json_build_object(
              'itemId', oi.item_id,
              'quantity', oi.quantity,
              'unitPrice', oi.unit_price,
              'taxPercent', oi.tax_percent,
              'notes', oi.notes,
              'item', json_build_object(
                'id', i.id,
                'storeId', i.store_id,
                'categoryId', i.category_id,
                'name', i.name,
                'price', i.price,
                'description', i.description,
                'hsnCode', i.hsn_code,
                'taxPercent', i.tax_percent,
                'isActive', i.is_active
              )
            )
          ) FILTER (WHERE oi.id IS NOT NULL),
          '[]'
        ) as items
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN items i ON oi.item_id = i.id
      WHERE o.table_id = @tableId AND o.status = 'active'
      GROUP BY o.id
      LIMIT 1
    ''', {'tableId': tableId});

    return result;
  }
}