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
  static final _safeId = RegExp(r'^[0-9]+-[0-9]+$');

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

  List<VaultFile> _decodeIndex(String content) {
    if (content.trim().isEmpty) return [];

    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('Vault index must be a list');
    }

    final files = <VaultFile>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Vault index contains an invalid entry');
      }
      files.add(VaultFile.fromJson(entry));
    }
    files.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return files;
  }

  Future<List<VaultFile>> listFiles() async {
    final index = await _indexFile();
    if (!await index.exists()) return [];

    try {
      return _decodeIndex(await index.readAsString());
    } on FormatException catch (error) {
      throw VaultStorageException('Vault index is corrupted: $error');
    } on TypeError catch (error) {
      throw VaultStorageException('Vault index is corrupted: $error');
    }
  }

  Future<void> _saveIndex(List<VaultFile> files) async {
    final index = await _indexFile();
    final temporary = File('${index.path}.tmp');
    final backup = File('${index.path}.bak');
    final encoded = jsonEncode(files.map((file) => file.toJson()).toList());

    try {
      await temporary.writeAsString(encoded, flush: true);
      if (await index.exists()) {
        await index.copy(backup.path);
      }
      await temporary.rename(index.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  File _encryptedFile(Directory vault, VaultFile file) {
    if (!_safeId.hasMatch(file.id)) {
      throw const VaultStorageException('Vault file identifier is invalid');
    }

    final expectedName = '${file.id}.vault';
    if (file.relativePath != expectedName ||
        path.basename(file.relativePath) != file.relativePath) {
      throw const VaultStorageException('Vault file path is invalid');
    }

    final candidate = path.normalize(path.join(vault.path, expectedName));
    if (path.dirname(candidate) != path.normalize(vault.path)) {
      throw const VaultStorageException('Vault file path escapes the vault');
    }
    return File(candidate);
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
        'This file type is unsupported or exceeds the 32 MiB limit',
      );
    }

    final files = await listFiles();
    if (files.isNotEmpty && !await _encryption.hasStoredKey()) {
      throw const VaultStorageException(
        'The vault key is missing; existing files must be recovered before importing',
      );
    }

    final plaintext = await source.readAsBytes();
    final encrypted = await _encryption.encrypt(plaintext);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    final vault = await _vaultDirectory();
    final encryptedFile = File(path.join(vault.path, '$id.vault'));
    final temporary = File('${encryptedFile.path}.tmp');
    final metadata = VaultFile(
      id: id,
      name: name,
      sizeBytes: size,
      mimeType: _mimeType(name),
      relativePath: '$id.vault',
      updatedAt: DateTime.now(),
    );

    try {
      await temporary.writeAsBytes(encrypted, flush: true);
      await temporary.rename(encryptedFile.path);
      files.add(metadata);
      await _saveIndex(files);
      return metadata;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await encryptedFile.exists()) await encryptedFile.delete();
      rethrow;
    }
  }

  Future<void> deleteFile(VaultFile file) async {
    final vault = await _vaultDirectory();
    final encryptedFile = _encryptedFile(vault, file);
    final tombstone = File('${encryptedFile.path}.deleting');
    final files = await listFiles();
    final updated =
        files.where((candidate) => candidate.id != file.id).toList();

    if (await encryptedFile.exists()) {
      await encryptedFile.rename(tombstone.path);
    }
    try {
      await _saveIndex(updated);
      if (await tombstone.exists()) await tombstone.delete();
    } catch (_) {
      if (await tombstone.exists()) {
        await tombstone.rename(encryptedFile.path);
      }
      rethrow;
    }
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
