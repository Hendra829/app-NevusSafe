import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStore {
  KeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'vault_aes256_key';
  final FlutterSecureStorage _storage;

  Future<List<int>?> readKey() async {
    final encoded = await _storage.read(key: _keyName);
    return encoded == null ? null : base64Url.decode(encoded);
  }

  Future<void> writeKey(List<int> key) => _storage.write(
        key: _keyName,
        value: base64UrlEncode(key),
      );
}
