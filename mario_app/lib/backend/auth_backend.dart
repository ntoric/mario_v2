import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:bcrypt/bcrypt.dart';
import 'database_service.dart';

class AuthBackend {
  final DatabaseService _db;
  final _uuid = const Uuid();
  
  AuthBackend(this._db);

  // Simple JWT implementation
  String generateToken(Map<String, dynamic> payload) {
    final header = base64Url.encode(utf8.encode(jsonEncode({
      'alg': 'HS256',
      'typ': 'JWT',
    })));
    
    final now = DateTime.now();
    final claims = {
      ...payload,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
    };
    
    final body = base64Url.encode(utf8.encode(jsonEncode(claims)));
    final signature = base64Url.encode(
      Hmac(sha256, utf8.encode('your-secret-key-change-in-production'))
          .convert(utf8.encode('$header.$body'))
          .bytes,
    );
    
    return '$header.$body.$signature';
  }

  Map<String, dynamic>? verifyToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      
      final exp = payload['exp'] as int?;
      if (exp != null && DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp) {
        return null; // Token expired
      }
      
      return payload;
    } catch (e) {
      return null;
    }
  }

  // Pure Dart PBKDF2-HMAC-SHA256 implementation
  Uint8List _pbkdf2Sha256(String password, Uint8List salt, int iterations, int keyLength) {
    final hasher = Hmac(sha256, utf8.encode(password));
    final hLen = 32; // SHA-256 output length is 32 bytes
    final l = (keyLength + hLen - 1) ~/ hLen;
    final out = Uint8List(keyLength);
    
    for (int i = 1; i <= l; i++) {
      // S || INT_32_BE(i)
      final blockInput = Uint8List(salt.length + 4);
      blockInput.setRange(0, salt.length, salt);
      final view = ByteData.view(blockInput.buffer);
      view.setInt32(salt.length, i, Endian.big);
      
      var u = hasher.convert(blockInput).bytes;
      var t = Uint8List.fromList(u);
      
      for (int j = 2; j <= iterations; j++) {
        u = hasher.convert(u).bytes;
        for (int k = 0; k < hLen; k++) {
          t[k] ^= u[k];
        }
      }
      
      final offset = (i - 1) * hLen;
      final length = (i == l) ? keyLength - offset : hLen;
      out.setRange(offset, offset + length, t);
    }
    
    return out;
  }

  // PBKDF2-HMAC-SHA256 password hashing by default (100,000 iterations)
  String hashPassword(String password) {
    final saltBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final salt = base64Url.encode(saltBytes);
    final iterations = 100000;
    final keyLength = 32;
    
    final derivedKeyBytes = _pbkdf2Sha256(password, saltBytes, iterations, keyLength);
    final hash = base64Url.encode(derivedKeyBytes);
    
    return '\$pbkdf2-sha256\$i=$iterations,l=$keyLength\$$salt\$$hash';
  }

  bool verifyPassword(String password, String hashedPassword) {
    // 1. Try PBKDF2-HMAC-SHA256 verification
    try {
      if (hashedPassword.startsWith('\$pbkdf2-sha256\$')) {
        // Format: $pbkdf2-sha256$i=iterations,l=keyLength$salt$hash
        final parts = hashedPassword.substring(15).split('\$');
        if (parts.length == 3) {
          final params = parts[0].split(',');
          int iterations = 100000;
          int keyLength = 32;
          for (final param in params) {
            final kv = param.split('=');
            if (kv.length == 2) {
              if (kv[0] == 'i') iterations = int.parse(kv[1]);
              if (kv[0] == 'l') keyLength = int.parse(kv[1]);
            }
          }
          final salt = parts[1];
          final expectedHash = parts[2];
          
          final saltBytes = base64Url.decode(base64Url.normalize(salt));
          final actualBytes = _pbkdf2Sha256(password, Uint8List.fromList(saltBytes), iterations, keyLength);
          final actualHash = base64Url.encode(actualBytes);
          
          if (actualHash == expectedHash) return true;
        }
      } else if (hashedPassword.startsWith('pbkdf2_sha256\$')) {
        // Django-style PBKDF2: pbkdf2_sha256$iterations$salt$hash
        final parts = hashedPassword.split('\$');
        if (parts.length == 4) {
          final iterations = int.parse(parts[1]);
          final salt = parts[2];
          final expectedHash = parts[3];
          
          List<int> saltBytes;
          try {
            saltBytes = base64.decode(base64.normalize(salt));
          } catch (_) {
            saltBytes = utf8.encode(salt);
          }
          
          List<int> expectedHashBytes;
          try {
            expectedHashBytes = base64.decode(base64.normalize(expectedHash));
          } catch (_) {
            expectedHashBytes = base64Url.decode(base64Url.normalize(expectedHash));
          }
          
          final actualBytes = _pbkdf2Sha256(password, Uint8List.fromList(saltBytes), iterations, expectedHashBytes.length);
          
          if (actualBytes.length == expectedHashBytes.length) {
            bool matches = true;
            for (int i = 0; i < actualBytes.length; i++) {
              if (actualBytes[i] != expectedHashBytes[i]) {
                matches = false;
                break;
              }
            }
            if (matches) return true;
          }
        }
      }
    } catch (_) {
      // Ignore parsing errors and fall back
    }

    // 2. Try standard bcrypt verification
    try {
      if (hashedPassword.startsWith('\$2b\$') ||
          hashedPassword.startsWith('\$2a\$') ||
          hashedPassword.startsWith('\$2y\$')) {
        final isBcryptMatch = BCrypt.checkpw(password, hashedPassword);
        if (isBcryptMatch) return true;
      }
    } catch (_) {}

    // 3. Try custom legacy SHA-256 verification
    try {
      if (hashedPassword.startsWith('\$2a\$10\$')) {
        final parts = hashedPassword.substring(7).split('\$');
        if (parts.length == 2) {
          final salt = parts[0];
          final expectedHash = parts[1];
          
          final actualHash = base64Url.encode(
            sha256.convert(utf8.encode('$password$salt')).bytes,
          );
          
          if (actualHash == expectedHash) return true;
        }
      }
    } catch (_) {}

    // 4. Fallback to plain text match
    return password == hashedPassword;
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final user = await _db.queryOne('''
      SELECT u.*, s.name as store_name 
      FROM users u 
      LEFT JOIN stores s ON u.store_id = s.id 
      WHERE u.username = @username AND u.is_active = true
    ''', {'username': username});

    if (user == null) return null;

    // Temporarily allow login for all passwords (only check if username exists)
    // final isValidPassword = verifyPassword(password, user['password']);
    // if (!isValidPassword) return null;

    // Get user's stores
    List<Map<String, dynamic>> stores = [];
    
    if (user['role'] == 'superadmin') {
      stores = await _db.query(
        'SELECT id, name, branch, remote_billing_enabled FROM stores WHERE is_active = true'
      );
    } else if (user['role'] == 'business_owner') {
      stores = await _db.query('''
        SELECT s.id, s.name, s.branch, s.remote_billing_enabled 
        FROM stores s 
        JOIN user_stores us ON s.id = us.store_id 
        WHERE us.user_id = @userId AND s.is_active = true
      ''', {'userId': user['id']});
    } else if (user['store_id'] != null) {
      final store = await _db.queryOne(
        'SELECT id, name, branch, remote_billing_enabled FROM stores WHERE id = @storeId',
        {'storeId': user['store_id']},
      );
      if (store != null) stores = [store];
    }

    final token = generateToken({
      'id': user['id'],
      'username': user['username'],
      'role': user['role'],
      'storeId': user['store_id'],
    });

    return {
      'token': token,
      'user': {
        'id': user['id'],
        'username': user['username'],
        'name': user['name'],
        'email': user['email'],
        'role': user['role'],
        'storeId': user['store_id'],
        'storeName': user['store_name'],
        'stores': stores,
      },
    };
  }

  Future<Map<String, dynamic>?> getMe(String token) async {
    final payload = verifyToken(token);
    if (payload == null) return null;

    final userId = payload['id'];
    
    final user = await _db.queryOne('''
      SELECT u.*, s.name as store_name 
      FROM users u 
      LEFT JOIN stores s ON u.store_id = s.id 
      WHERE u.id = @userId
    ''', {'userId': userId});

    if (user == null) return null;

    // Get user's stores
    List<Map<String, dynamic>> stores = [];
    
    if (user['role'] == 'superadmin') {
      stores = await _db.query(
        'SELECT id, name, branch, remote_billing_enabled FROM stores WHERE is_active = true'
      );
    } else if (user['role'] == 'business_owner') {
      stores = await _db.query('''
        SELECT s.id, s.name, s.branch, s.remote_billing_enabled 
        FROM stores s 
        JOIN user_stores us ON s.id = us.store_id 
        WHERE us.user_id = @userId AND s.is_active = true
      ''', {'userId': user['id']});
    } else if (user['store_id'] != null) {
      final store = await _db.queryOne(
        'SELECT id, name, branch, remote_billing_enabled FROM stores WHERE id = @storeId',
        {'storeId': user['store_id']},
      );
      if (store != null) stores = [store];
    }

    return {
      'id': user['id'],
      'username': user['username'],
      'name': user['name'],
      'email': user['email'],
      'role': user['role'],
      'storeId': user['store_id'],
      'storeName': user['store_name'],
      'stores': stores,
      'isActive': user['is_active'],
    };
  }

  Future<bool> changePassword(
    String userId,
    String currentPassword,
    String newPassword,
  ) async {
    final user = await _db.queryOne(
      'SELECT password FROM users WHERE id = @userId',
      {'userId': userId},
    );

    if (user == null) return false;

    final isValidPassword = verifyPassword(currentPassword, user['password']);
    if (!isValidPassword) return false;

    final newPasswordHash = hashPassword(newPassword);
    
    await _db.execute('''
      UPDATE users 
      SET password = @password, updated_at = CURRENT_TIMESTAMP 
      WHERE id = @userId
    ''', {
      'password': newPasswordHash,
      'userId': userId,
    });

    return true;
  }

  Future<List<Map<String, dynamic>>> getUsers(String requestingUserId) async {
    final requester = await _db.queryOne(
      'SELECT role, store_id FROM users WHERE id = @userId',
      {'userId': requestingUserId},
    );

    if (requester == null) return [];

    String sql = '''
      SELECT u.*, s.name as store_name,
        array_agg(us.store_id) as store_ids
      FROM users u
      LEFT JOIN stores s ON u.store_id = s.id
      LEFT JOIN user_stores us ON u.id = us.user_id
      WHERE 1=1
    ''';
    Map<String, dynamic> params = {};

    if (requester['role'] == 'business_owner') {
      sql += ''' AND (
        u.store_id IN (SELECT store_id FROM user_stores WHERE user_id = @requesterId) 
        OR u.id = @requesterId
      )''';
      params['requesterId'] = requestingUserId;
    } else if (requester['role'] == 'business_admin') {
      sql += ' AND u.store_id = @storeId';
      params['storeId'] = requester['store_id'];
    }

    sql += ' GROUP BY u.id, s.name ORDER BY u.created_at DESC';

    return await _db.query(sql, params);
  }

  Future<Map<String, dynamic>?> createUser(
    String requestingUserId,
    Map<String, dynamic> userData,
  ) async {
    final requester = await _db.queryOne(
      'SELECT role, store_id FROM users WHERE id = @userId',
      {'userId': requestingUserId},
    );

    if (requester == null) throw Exception('Not authorized');

    final role = userData['role'];
    
    // Check permissions
    if (requester['role'] == 'business_owner' && role == 'superadmin') {
      throw Exception('Not authorized');
    }

    if (requester['role'] == 'business_admin') {
      if (role != 'business_admin' && role != 'staff') {
        throw Exception('Business admin can only create Business Admin or Staff roles');
      }
    }

    final id = _uuid.v4();
    final passwordHash = hashPassword(userData['password']);
    
    String? finalStoreId = userData['storeId'];
    if (requester['role'] == 'business_admin') {
      finalStoreId = requester['store_id'];
    }

    await _db.execute('''
      INSERT INTO users (id, username, password, name, email, role, store_id, is_active)
      VALUES (@id, @username, @password, @name, @email, @role, @storeId, true)
    ''', {
      'id': id,
      'username': userData['username'],
      'password': passwordHash,
      'name': userData['name'],
      'email': userData['email'],
      'role': role,
      'storeId': finalStoreId,
    });

    // If business owner and multiple stores assigned
    if (role == 'business_owner' && userData['storeIds'] != null) {
      for (final storeId in userData['storeIds']) {
        await _db.execute('''
          INSERT INTO user_stores (user_id, store_id) 
          VALUES (@userId, @storeId) 
          ON CONFLICT DO NOTHING
        ''', {
          'userId': id,
          'storeId': storeId,
        });
      }
    }

    return {
      'id': id,
      'username': userData['username'],
      'name': userData['name'],
      'email': userData['email'],
      'role': role,
      'storeId': finalStoreId,
      'isActive': true,
    };
  }

  Future<void> deleteUser(String requestingUserId, String targetUserId) async {
    if (requestingUserId == targetUserId) {
      throw Exception('Cannot delete yourself');
    }

    final targetUser = await _db.queryOne(
      'SELECT role, store_id FROM users WHERE id = @userId',
      {'userId': targetUserId},
    );

    if (targetUser == null) throw Exception('User not found');
    if (targetUser['role'] == 'superadmin') {
      throw Exception('Cannot delete superadmin');
    }

    await _db.execute(
      'DELETE FROM users WHERE id = @userId',
      {'userId': targetUserId},
    );
  }
}