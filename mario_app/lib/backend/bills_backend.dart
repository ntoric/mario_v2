import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'database_service.dart';

class BillsBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();

  BillsBackend(this._db);

  Future<List<Map<String, dynamic>>> getBills(String storeId) async {
    return await _db.query('''
      SELECT 
        b.*,
        COALESCE(
          json_agg(
            json_build_object(
              'itemId', oi.item_id,
              'quantity', oi.quantity,
              'unitPrice', oi.unit_price,
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
      FROM bills b
      LEFT JOIN order_items oi ON b.order_id = oi.order_id
      LEFT JOIN items i ON oi.item_id = i.id
      WHERE b.store_id = @storeId
      GROUP BY b.id
      ORDER BY b.generated_at DESC
    ''', {'storeId': storeId});
  }

  Future<String> getNextInvoiceNo(String storeId) async {
    final result = await _db.queryOne('''
      SELECT COUNT(*) as count 
      FROM bills 
      WHERE store_id = @storeId
    ''', {'storeId': storeId});

    final count = result?['count'] ?? 0;
    final nextNumber = (count as int) + 1;
    return 'INV-${nextNumber.toString().padLeft(6, '0')}';
  }

  Future<Map<String, dynamic>> createBill(
    String userId,
    Map<String, dynamic> billData,
  ) async {
    final id = _uuid.v4();
    final invoiceNo = billData['invoiceNo'] ?? await getNextInvoiceNo(billData['storeId']);

    await _db.execute('''
      INSERT INTO bills (
        id, store_id, order_id, table_number, invoice_no,
        subtotal, tax_total, discount, total,
        payment_method, customer_name, generated_by
      ) VALUES (
        @id, @storeId, @orderId, @tableNumber, @invoiceNo,
        @subtotal, @taxTotal, @discount, @total,
        @paymentMethod, @customerName, @generatedBy
      )
    ''', {
      'id': id,
      'storeId': billData['storeId'],
      'orderId': billData['orderId'],
      'tableNumber': billData['tableNumber'],
      'invoiceNo': invoiceNo,
      'subtotal': billData['subtotal'],
      'taxTotal': billData['taxTotal'] ?? 0,
      'discount': billData['discount'] ?? 0,
      'total': billData['total'],
      'paymentMethod': billData['paymentMethod'],
      'customerName': billData['customerName'],
      'generatedBy': userId,
    });

    return {
      'id': id,
      ...billData,
      'invoiceNo': invoiceNo,
      'isPrinted': false,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> enqueueBill(
    String userId,
    Map<String, dynamic> billData,
  ) async {
    final id = _uuid.v4();
    
    final payload = {
      'orderId': billData['orderId'],
      'tableNumber': billData['tableNumber'],
      'invoiceNo': billData['invoiceNo'],
      'subtotal': billData['subtotal'],
      'taxTotal': billData['taxTotal'] ?? 0,
      'discount': billData['discount'] ?? 0,
      'total': billData['total'],
      'paymentMethod': billData['paymentMethod'],
      'customerName': billData['customerName'],
      'generatedBy': userId,
    };

    await _db.execute('''
      INSERT INTO bill_queue (
        id, store_id, order_id, bill_data, status
      ) VALUES (
        @id, @storeId, @orderId, @billData::jsonb, 'pending'
      )
    ''', {
      'id': id,
      'storeId': billData['storeId'],
      'orderId': billData['orderId'],
      'billData': jsonEncode(payload),
    });

    return {
      'id': id,
      'storeId': billData['storeId'],
      'orderId': billData['orderId'],
      'billData': payload,
      'status': 'pending',
    };
  }

  Future<void> markAsPrinted(String billId) async {
    await _db.execute(
      'UPDATE bills SET is_printed = true WHERE id = @billId',
      {'billId': billId},
    );
  }
}