import 'package:uuid/uuid.dart';
import 'database_service.dart';

class TablesBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();

  TablesBackend(this._db);

  Future<List<Map<String, dynamic>>> getTables(String storeId) async {
    return await _db.query('''
      SELECT 
        id,
        store_id as "storeId",
        number,
        seats,
        position_x as "positionX",
        position_y as "positionY",
        is_active as "isActive"
      FROM tables 
      WHERE store_id = @storeId AND is_active = true 
      ORDER BY number
    ''', {'storeId': storeId});
  }

  Future<Map<String, dynamic>> createTable(
    String userId,
    Map<String, dynamic> tableData,
  ) async {
    final id = _uuid.v4();
    final position = tableData['position'] ?? {'x': 0, 'y': 0};

    await _db.execute('''
      INSERT INTO tables (id, store_id, number, seats, position_x, position_y)
      VALUES (@id, @storeId, @number, @seats, @posX, @posY)
    ''', {
      'id': id,
      'storeId': tableData['storeId'],
      'number': tableData['number'],
      'seats': tableData['seats'],
      'posX': position['x'] ?? 0,
      'posY': position['y'] ?? 0,
    });

    return {
      'id': id,
      'storeId': tableData['storeId'],
      'number': tableData['number'],
      'seats': tableData['seats'],
      'position': position,
      'isActive': true,
    };
  }

  Future<void> updateTable(String tableId, Map<String, dynamic> tableData) async {
    final position = tableData['position'];

    await _db.execute('''
      UPDATE tables SET 
        number = @number,
        seats = @seats,
        position_x = @posX,
        position_y = @posY
      WHERE id = @tableId
    ''', {
      'tableId': tableId,
      'number': tableData['number'],
      'seats': tableData['seats'],
      'posX': position?['x'] ?? 0,
      'posY': position?['y'] ?? 0,
    });
  }

  Future<void> deleteTable(String tableId) async {
    await _db.execute(
      'UPDATE tables SET is_active = false WHERE id = @tableId',
      {'tableId': tableId},
    );
  }
}