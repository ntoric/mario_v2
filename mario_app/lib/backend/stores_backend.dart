import 'package:uuid/uuid.dart';
import 'database_service.dart';

class StoresBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();

  StoresBackend(this._db);

  Future<List<Map<String, dynamic>>> getStores(String userId) async {
    final user = await _db.queryOne(
      'SELECT role FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null) return [];

    String sql = 'SELECT * FROM stores WHERE 1=1';
    Map<String, dynamic> params = {};

    if (user['role'] == 'business_owner') {
      sql += ' AND id IN (SELECT store_id FROM user_stores WHERE user_id = @userId)';
      params['userId'] = userId;
    } else if (user['role'] == 'business_admin' || user['role'] == 'staff') {
      final userStore = await _db.queryOne(
        'SELECT store_id FROM users WHERE id = @userId',
        {'userId': userId},
      );
      if (userStore != null) {
        sql += ' AND id = @storeId';
        params['storeId'] = userStore['store_id'];
      }
    }

    sql += ' ORDER BY name';

    return await _db.query(sql, params);
  }

  Future<Map<String, dynamic>?> getStore(String storeId) async {
    return await _db.queryOne(
      'SELECT * FROM stores WHERE id = @storeId',
      {'storeId': storeId},
    );
  }

  Future<Map<String, dynamic>> createStore(
    String userId,
    Map<String, dynamic> storeData,
  ) async {
    final user = await _db.queryOne(
      'SELECT role FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null || (user['role'] != 'superadmin' && user['role'] != 'business_owner')) {
      throw Exception('Not authorized');
    }

    final id = _uuid.v4();
    
    await _db.execute('''
      INSERT INTO stores (
        id, name, branch, location, gstin, fssai_no, phone,
        printer_name, printer_vendor_id, printer_product_id, 
        invoice_size, kot_print_enabled, is_active
      ) VALUES (
        @id, @name, @branch, @location, @gstin, @fssaiNo, @phone,
        @printerName, @printerVendorId, @printerProductId,
        @invoiceSize, @kotPrintEnabled, true
      )
    ''', {
      'id': id,
      'name': storeData['name'],
      'branch': storeData['branch'],
      'location': storeData['location'],
      'gstin': storeData['gstin'],
      'fssaiNo': storeData['fssaiNo'],
      'phone': storeData['phone'],
      'printerName': storeData['printerName'],
      'printerVendorId': storeData['printerVendorId'],
      'printerProductId': storeData['printerProductId'],
      'invoiceSize': storeData['invoiceSize'] ?? '3inch',
      'kotPrintEnabled': storeData['kotPrintEnabled'] ?? true,
    });

    // If business owner created it, give them access
    if (user['role'] == 'business_owner') {
      await _db.execute('''
        INSERT INTO user_stores (user_id, store_id) 
        VALUES (@userId, @storeId)
      ''', {
        'userId': userId,
        'storeId': id,
      });
    }

    return {
      'id': id,
      ...storeData,
      'isActive': true,
    };
  }

  Future<void> updateStore(
    String userId,
    String storeId,
    Map<String, dynamic> storeData,
  ) async {
    final user = await _db.queryOne(
      'SELECT role, store_id FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null) throw Exception('Not authorized');

    // Check permissions
    if (user['role'] == 'business_owner') {
      final hasAccess = await _db.queryOne('''
        SELECT 1 FROM user_stores 
        WHERE user_id = @userId AND store_id = @storeId
      ''', {
        'userId': userId,
        'storeId': storeId,
      });
      if (hasAccess == null) throw Exception('Not authorized');
    } else if (user['role'] == 'business_admin' || user['role'] == 'staff') {
      if (user['store_id'] != storeId) {
        throw Exception('Not authorized to update this store');
      }
    } else if (user['role'] != 'superadmin') {
      throw Exception('Not authorized');
    }

    await _db.execute('''
      UPDATE stores SET 
        name = COALESCE(@name, name),
        branch = COALESCE(@branch, branch),
        location = COALESCE(@location, location),
        gstin = COALESCE(@gstin, gstin),
        fssai_no = COALESCE(@fssaiNo, fssai_no),
        phone = COALESCE(@phone, phone),
        printer_name = COALESCE(@printerName, printer_name),
        printer_vendor_id = COALESCE(@printerVendorId, printer_vendor_id),
        printer_product_id = COALESCE(@printerProductId, printer_product_id),
        invoice_size = COALESCE(@invoiceSize, invoice_size),
        kot_print_enabled = COALESCE(@kotPrintEnabled, kot_print_enabled),
        is_active = COALESCE(@isActive, is_active),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = @storeId
    ''', {
      ...storeData,
      'storeId': storeId,
    });
  }

  Future<void> deleteStore(String userId, String storeId) async {
    final user = await _db.queryOne(
      'SELECT role FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null || user['role'] != 'superadmin') {
      throw Exception('Not authorized');
    }

    await _db.execute(
      'DELETE FROM stores WHERE id = @storeId',
      {'storeId': storeId},
    );
  }

  Future<Map<String, dynamic>> switchStore(String userId, String storeId) async {
    final user = await _db.queryOne(
      'SELECT role, store_id FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null) throw Exception('User not found');

    // Verify user has access to this store
    bool hasAccess = false;

    if (user['role'] == 'superadmin') {
      hasAccess = true;
    } else if (user['role'] == 'business_owner') {
      final result = await _db.queryOne('''
        SELECT 1 FROM user_stores 
        WHERE user_id = @userId AND store_id = @storeId
      ''', {
        'userId': userId,
        'storeId': storeId,
      });
      hasAccess = result != null;
    } else {
      hasAccess = user['store_id'] == storeId;
    }

    if (!hasAccess) throw Exception('Access denied to this store');

    final store = await getStore(storeId);
    if (store == null) throw Exception('Store not found');

    return {'store': store};
  }
}