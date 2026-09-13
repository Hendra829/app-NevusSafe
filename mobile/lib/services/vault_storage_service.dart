import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/file_policy.dart';
import '../models/vault_file.dart';
import 'encryption_service.dart';

class VaultStorageException implements Exception {
  const VaultStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VaultStorageService {
  VaultStorageService(this._encryption);

  final EncryptionService _encryption;
  final _random = Random.secure();

  Future<Directory> _vaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final vault = Directory(path.join(documents.path, 'vault'));
    await vault.create(recursive: true);
    return vault;
  }

  Future<File> _indexFile() async {
    final vault = await _vaultDirectory();
    return File(path.join(vault.path, 'index.json'));
  }

  Future<List<VaultFile>> listFiles() async {
    final index = await _indexFile();
    if (!await index.exists()) return [];

    final content = await index.readAsString();
    if (content.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        throw const FormatException('Vault index must be a list');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(VaultFile.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } on FormatException catch (error) {
      throw VaultStorageException('Vault index is corrupted: $error');
    } on TypeError catch (error) {
      throw VaultStorageException('Vault index is corrupted: $error');
    }
  }

  Future<void> _saveIndex(List<VaultFile> files) async {
    final index = await _indexFile();
    await index.writeAsString(
      jsonEncode(files.map((file) => file.toJson()).toList()),
      flush: true,
    );
  }

  File _encryptedFile(Directory vault, VaultFile file) {
    final expectedName = '${file.id}.vault';
    if (file.relativePath != expectedName) {
      throw const VaultStorageException('Vault file path is invalid');
    }
    return File(path.join(vault.path, expectedName));
  }

  Future<VaultFile> importFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const VaultStorageException('Selected file is no longer available');
    }

    final name = path.basename(source.path);
    final size = await source.length();
    if (!isSupportedFile(name, size)) {
      throw const VaultStorageException(
        'This file type is unsupported or exceeds the 10 GiB limit',
      );
    }

    final plaintext = await source.readAsBytes();
    final encrypted = await _encryption.encrypt(Uint8List.fromList(plaintext));
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    final vault = await _vaultDirectory();
    final encryptedFile = File(path.join(vault.path, '$id.vault'));
    final metadata = VaultFile(
      id: id,
      name: name,
      sizeBytes: size,
      mimeType: _mimeType(name),
      relativePath: '$id.vault',
      updatedAt: DateTime.now(),
    );

    try {
      await encryptedFile.writeAsBytes(encrypted, flush: true);
      final files = await listFiles();
      files.add(metadata);
      await _saveIndex(files);
      return metadata;
    } catch (_) {
      if (await encryptedFile.exists()) await encryptedFile.delete();
      rethrow;
    }
  }

  Future<void> deleteFile(VaultFile file) async {
    final vault = await _vaultDirectory();
    final encryptedFile = _encryptedFile(vault, file);
    if (await encryptedFile.exists()) await encryptedFile.delete();

    final files = await listFiles();
    files.removeWhere((candidate) => candidate.id == file.id);
    await _saveIndex(files);
  }

  Future<Uint8List> decryptFile(VaultFile file) async {
    final vault = await _vaultDirectory();
    final encryptedFile = _encryptedFile(vault, file);
    if (!await encryptedFile.exists()) {
      throw const VaultStorageException('Encrypted file is missing');
    }
    return _encryption.decrypt(await encryptedFile.readAsBytes());
  }

  String _mimeType(String filename) {
    final extension = path.extension(filename).toLowerCase();
    const mimeTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.heic': 'image/heic',
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.pdf': 'application/pdf',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.csv': 'text/csv',
      '.md': 'text/markdown',
      '.zip': 'application/zip',
      '.apk': 'application/vnd.android.package-archive',
    };
    return mimeTypes[extension] ?? 'application/octet-stream';
  }
}
