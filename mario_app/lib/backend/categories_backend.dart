import 'package:uuid/uuid.dart';
import 'database_service.dart';

class CategoriesBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();

  CategoriesBackend(this._db);

  Future<List<Map<String, dynamic>>> getCategories(String storeId) async {
    return await _db.query('''
      SELECT 
        id,
        store_id as "storeId",
        name,
        description,
        is_active as "isActive"
      FROM categories 
      WHERE store_id = @storeId AND is_active = true 
      ORDER BY name
    ''', {'storeId': storeId});
  }

  Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> categoryData,
  ) async {
    final id = _uuid.v4();

    await _db.execute('''
      INSERT INTO categories (id, store_id, name, description)
      VALUES (@id, @storeId, @name, @description)
    ''', {
      'id': id,
      'storeId': categoryData['storeId'],
      'name': categoryData['name'],
      'description': categoryData['description'],
    });

    return {
      'id': id,
      'storeId': categoryData['storeId'],
      'name': categoryData['name'],
      'description': categoryData['description'],
      'isActive': true,
    };
  }

  Future<void> updateCategory(
    String categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    await _db.execute('''
      UPDATE categories SET 
        name = @name,
        description = @description
      WHERE id = @categoryId
    ''', {
      'categoryId': categoryId,
      'name': categoryData['name'],
      'description': categoryData['description'],
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.execute(
      'UPDATE categories SET is_active = false WHERE id = @categoryId',
      {'categoryId': categoryId},
    );
  }
}