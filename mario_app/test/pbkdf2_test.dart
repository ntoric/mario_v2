import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:mario_app/backend/auth_backend.dart';
import 'package:mario_app/backend/database_service.dart';

Uint8List hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

void main() {
  group('PBKDF2 & Backward Compatibility Tests', () {
    // Initialize AuthBackend with a valid DatabaseService instance
    final authBackend = AuthBackend(DatabaseService());

    test('Standard PBKDF2-HMAC-SHA256 Vector: 1 iteration', () {
      const password = 'password';
      const salt = 'salt';
      const hexOutput = '120fb6cffcf8b32c43e7225256c4f837a86548c9';
      
      final saltBase64 = base64Url.encode(utf8.encode(salt));
      final expectedBase64 = base64Url.encode(hexToBytes(hexOutput));
      final hashString = '\$pbkdf2-sha256\$i=1,l=20\$$saltBase64\$$expectedBase64';
      
      expect(authBackend.verifyPassword(password, hashString), isTrue);
    });

    test('Standard PBKDF2-HMAC-SHA256 Vector: 2 iterations', () {
      const password = 'password';
      const salt = 'salt';
      const hexOutput = 'ae4d0c95af6b46d32d0adff928f06dd02a303f8e';
      
      final saltBase64 = base64Url.encode(utf8.encode(salt));
      final expectedBase64 = base64Url.encode(hexToBytes(hexOutput));
      final hashString = '\$pbkdf2-sha256\$i=2,l=20\$$saltBase64\$$expectedBase64';
      
      expect(authBackend.verifyPassword(password, hashString), isTrue);
    });

    test('Standard PBKDF2-HMAC-SHA256 Vector: 4096 iterations', () {
      const password = 'password';
      const salt = 'salt';
      const hexOutput = 'c5e478d59288c841aa530db6845c4c8d962893a0';
      
      final saltBase64 = base64Url.encode(utf8.encode(salt));
      final expectedBase64 = base64Url.encode(hexToBytes(hexOutput));
      final hashString = '\$pbkdf2-sha256\$i=4096,l=20\$$saltBase64\$$expectedBase64';
      
      expect(authBackend.verifyPassword(password, hashString), isTrue);
    });

    test('Django-style PBKDF2 format matching', () {
      const password = 'password';
      const salt = 'salt';
      const hexOutput = 'ae4d0c95af6b46d32d0adff928f06dd02a303f8e';
      
      final saltBase64 = base64.encode(utf8.encode(salt));
      final expectedBase64 = base64.encode(hexToBytes(hexOutput));
      
      // Format: pbkdf2_sha256$iterations$salt$hash
      final hashString = 'pbkdf2_sha256\$2\$$saltBase64\$$expectedBase64';
      
      expect(authBackend.verifyPassword(password, hashString), isTrue);
    });

    test('New PBKDF2 hash generation and verification', () {
      const password = 'mySecurePassword123!';
      final hash = authBackend.hashPassword(password);
      
      // Check prefix format
      expect(hash.startsWith('\$pbkdf2-sha256\$i=100000,l=32\$'), isTrue);
      
      // Verify matches
      expect(authBackend.verifyPassword(password, hash), isTrue);
      expect(authBackend.verifyPassword('wrongPassword', hash), isFalse);
    });

    test('Legacy custom SHA-256 verification backward compatibility', () {
      const password = 'legacyPassword';
      
      final salt = base64Url.encode(utf8.encode('oldsalt'));
      final hashBytes = sha256.convert(utf8.encode('$password$salt')).bytes;
      final hash = base64Url.encode(hashBytes);
      final oldHashString = '\$2a\$10\$$salt\$$hash';
      
      expect(authBackend.verifyPassword(password, oldHashString), isTrue);
      expect(authBackend.verifyPassword('wrongPassword', oldHashString), isFalse);
    });

    test('Legacy bcrypt verification backward compatibility', () {
      const password = 'bcryptPassword';
      final dynamicBcryptHash = BCrypt.hashpw(password, BCrypt.gensalt());
      
      expect(authBackend.verifyPassword(password, dynamicBcryptHash), isTrue);
      expect(authBackend.verifyPassword('wrongPassword', dynamicBcryptHash), isFalse);
    });

    test('Plain text fallback backward compatibility', () {
      const password = 'plainTextPassword123';
      expect(authBackend.verifyPassword(password, password), isTrue);
    });

    test('Wrong password rejection', () {
      const password = 'correctPassword';
      const hash = '\$pbkdf2-sha256\$i=1000,l=32\$c2FsdA\$MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI';
      expect(authBackend.verifyPassword('wrongPassword', hash), isFalse);
    });
  });
}
