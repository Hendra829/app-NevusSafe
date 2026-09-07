import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'key_store.dart';

class EncryptionService {
  EncryptionService(this._keys);

  final KeyStore _keys;
  final _algorithm = AesGcm.with256bits();

  Future<SecretKey> _key() async {
    final existing = await _keys.readKey();
    if (existing != null && existing.length == 32) {
      return SecretKey(existing);
    }
    final generated = await _algorithm.newSecretKey();
    await _keys.writeKey(await generated.extractBytes());
    return generated;
  }

  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final box = await _algorithm.encrypt(plaintext, secretKey: await _key());
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> decrypt(Uint8List payload) async {
    if (payload.length < 28) throw const FormatException('Invalid encrypted file');
    final box = SecretBox(
      payload.sublist(12, payload.length - 16),
      nonce: payload.sublist(0, 12),
      mac: Mac(payload.sublist(payload.length - 16)),
    );
    return Uint8List.fromList(
      await _algorithm.decrypt(box, secretKey: await _key()),
    );
  }
}
