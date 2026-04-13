import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Utilities for application security and key management.
class SecurityUtils {
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'db_encryption_key';

  /// Retrieves the database encryption key from secure storage,
  /// generating a new one if it doesn't exist.
  static Future<String> getDatabaseKey() async {
    String? key;
    try {
      key = await _storage.read(key: _dbKeyName);
    } catch (e) {
      // Bắt mọi lỗi Keystore (vd: AEADBadTagException do restore dữ liệu rác, lỗi device)
      await _storage.deleteAll();
    }

    if (key == null) {
      key = _generateRandomKey();
      await _storage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  /// Generates a cryptographically secure 256-bit key encoded as Base64Url.
  static String _generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}
