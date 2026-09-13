import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nevus_safe/services/encryption_service.dart';

class _MemoryKeyStore implements VaultKeyStore {
  List<int>? _key;

  @override
  Future<List<int>?> readKey() async => _key;

  @override
  Future<void> writeKey(List<int> key) async => _key = key;
}

void main() {
  test('encrypts and decrypts with a persistent key', () async {
    final service = EncryptionService(_MemoryKeyStore());
    final plaintext = Uint8List.fromList('NevusSafe'.codeUnits);

    final encrypted = await service.encrypt(plaintext);
    final decrypted = await service.decrypt(encrypted);

    expect(encrypted, isNot(orderedEquals(plaintext)));
    expect(decrypted, orderedEquals(plaintext));
  });

  test('rejects a malformed stored key instead of rotating it', () async {
    final keys = _MemoryKeyStore().._key = [1, 2, 3];
    final service = EncryptionService(keys);

    expect(
      service.encrypt(Uint8List.fromList([1])),
      throwsA(isA<StateError>()),
    );
  });
}
