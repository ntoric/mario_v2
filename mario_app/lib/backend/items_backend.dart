import 'package:uuid/uuid.dart';
import 'database_service.dart';

class ItemsBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();

  ItemsBackend(this._db);

  Future<List<Map<String, dynamic>>> getItems(String storeId) async {
    return await _db.query('''
      SELECT 
        i.id,
        i.store_id as "storeId",
        i.category_id as "categoryId",
        c.name as "categoryName",
        i.name,
        i.description,
        i.price,
        i.hsn_code as "hsnCode",
        i.tax_percent as "taxPercent",
        i.is_active as "isActive"
      FROM items i
      LEFT JOIN categories c ON i.category_id = c.id
      WHERE i.store_id = @storeId AND i.is_active = true
      ORDER BY i.name
    ''', {'storeId': storeId});
  }

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> itemData) async {
    final id = _uuid.v4();

    await _db.execute('''
      INSERT INTO items (
        id, store_id, category_id, name, description, 
        price, hsn_code, tax_percent
      ) VALUES (
        @id, @storeId, @categoryId, @name, @description,
        @price, @hsnCode, @taxPercent
      )
    ''', {
      'id': id,
      'storeId': itemData['storeId'],
      'categoryId': itemData['categoryId'],
      'name': itemData['name'],
      'description': itemData['description'],
      'price': itemData['price'],
      'hsnCode': itemData['hsnCode'],
      'taxPercent': itemData['taxPercent'] ?? 0,
    });

    return {
      'id': id,
      'storeId': itemData['storeId'],
      'categoryId': itemData['categoryId'],
      'name': itemData['name'],
      'description': itemData['description'],
      'price': itemData['price'],
      'hsnCode': itemData['hsnCode'],
      'taxPercent': itemData['taxPercent'] ?? 0,
      'isActive': true,
    };
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> itemData) async {
    await _db.execute('''
      UPDATE items SET 
        category_id = @categoryId,
        name = @name,
        description = @description,
        price = @price,
        hsn_code = @hsnCode,
        tax_percent = @taxPercent
      WHERE id = @itemId
    ''', {
      'itemId': itemId,
      'categoryId': itemData['categoryId'],
      'name': itemData['name'],
      'description': itemData['description'],
      'price': itemData['price'],
      'hsnCode': itemData['hsnCode'],
      'taxPercent': itemData['taxPercent'],
    });
  }

  Future<void> deleteItem(String itemId) async {
    await _db.execute(
      'UPDATE items SET is_active = false WHERE id = @itemId',
      {'itemId': itemId},
    );
  }
}