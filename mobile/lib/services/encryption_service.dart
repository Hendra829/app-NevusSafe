import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'key_store.dart';

class EncryptionService {
  EncryptionService(this._keys);

  final VaultKeyStore _keys;
  final _algorithm = AesGcm.with256bits();

  Future<bool> hasStoredKey() async => (await _keys.readKey()) != null;

  Future<SecretKey> _key({required bool createIfMissing}) async {
    final existing = await _keys.readKey();
    if (existing != null) {
      if (existing.length != 32) {
        throw StateError('Stored vault key has an invalid length');
      }
      return SecretKey(existing);
    }
    if (!createIfMissing) {
      throw StateError('Vault key is missing; encrypted files cannot be opened');
    }

    final generated = await _algorithm.newSecretKey();
    await _keys.writeKey(await generated.extractBytes());
    return generated;
  }

  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: await _key(createIfMissing: true),
    );
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> decrypt(Uint8List payload) async {
    if (payload.length < 28) {
      throw const FormatException('Invalid encrypted file');
    }
    final box = SecretBox(
      payload.sublist(12, payload.length - 16),
      nonce: payload.sublist(0, 12),
      mac: Mac(payload.sublist(payload.length - 16)),
    );
    return Uint8List.fromList(
      await _algorithm.decrypt(
        box,
        secretKey: await _key(createIfMissing: false),
      ),
    );
  }
}
