import 'database_service.dart';

class SystemBackend {
  final DatabaseService _db;

  SystemBackend(this._db);

  Future<Map<String, dynamic>> getStats() async {
    final results = await Future.wait([
      _db.queryOne('SELECT COUNT(*) as count FROM users'),
      _db.queryOne('SELECT COUNT(*) as count FROM stores'),
      _db.queryOne('SELECT COUNT(*) as count FROM categories'),
      _db.queryOne('SELECT COUNT(*) as count FROM items'),
      _db.queryOne('SELECT COUNT(*) as count FROM orders'),
      _db.queryOne('SELECT COUNT(*) as count FROM tables'),
      _db.queryOne('SELECT COUNT(*) as count FROM bills'),
    ]);

    return {
      'users': results[0]?['count'] ?? 0,
      'stores': results[1]?['count'] ?? 0,
      'categories': results[2]?['count'] ?? 0,
      'items': results[3]?['count'] ?? 0,
      'orders': results[4]?['count'] ?? 0,
      'tables': results[5]?['count'] ?? 0,
      'bills': results[6]?['count'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> resetSystem(
    String userId,
    Map<String, bool> options,
  ) async {
    final user = await _db.queryOne(
      'SELECT role FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null || user['role'] != 'superadmin') {
      throw Exception('Only superadmin can perform system reset');
    }

    final results = <String, Map<String, dynamic>>{};

    await _db.transaction(() async {
      // Reset bills first (depends on orders)
      if (options['bills'] == true) {
        await _db.execute('DELETE FROM bills');
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM bills');
        results['bills'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }

      // Reset orders
      if (options['orders'] == true) {
        await _db.execute('DELETE FROM order_items');
        await _db.execute('DELETE FROM orders');
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM orders');
        results['orders'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }

      // Reset tables
      if (options['tables'] == true) {
        await _db.execute('DELETE FROM tables');
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM tables');
        results['tables'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }

      // Reset items
      if (options['items'] == true) {
        await _db.execute('DELETE FROM items');
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM items');
        results['items'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }

      // Reset categories
      if (options['categories'] == true) {
        await _db.execute('DELETE FROM categories');
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM categories');
        results['categories'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }

      // Reset stores
      if (options['stores'] == true) {
        // First reset dependent entities if not already reset
        if (options['bills'] != true) await _db.execute('DELETE FROM bills');
        if (options['orders'] != true) {
          await _db.execute('DELETE FROM order_items');
          await _db.execute('DELETE FROM orders');
        }
        if (options['tables'] != true) await _db.execute('DELETE FROM tables');
        if (options['items'] != true) await _db.execute('DELETE FROM items');
        if (options['categories'] != true) await _db.execute('DELETE FROM categories');

        // Clear store_id from users
        await _db.execute("UPDATE users SET store_id = NULL WHERE role IN ('business_admin', 'staff')");
        await _db.execute('DELETE FROM user_stores');
        await _db.execute('DELETE FROM stores');
        
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM stores');
        results['stores'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }

      // Reset users - keep only superadmin
      if (options['users'] == true) {
        await _db.execute("DELETE FROM users WHERE role != 'superadmin'");
        if (options['stores'] != true) {
          await _db.execute('DELETE FROM user_stores');
        }
        
        final count = await _db.queryOne('SELECT COUNT(*) as count FROM users');
        results['users'] = {'success': true, 'remaining': count?['count'] ?? 0};
      }
    });

    return {
      'message': 'System reset completed successfully',
      'resetResults': results,
    };
  }
}