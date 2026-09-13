import 'package:flutter_test/flutter_test.dart';
import 'package:nevus_safe/models/vault_file.dart';

void main() {
  test('serializes and restores vault file metadata', () {
    final original = VaultFile(
      id: 'file-1',
      name: 'photo.JPG',
      sizeBytes: 1024,
      mimeType: 'image/jpeg',
      relativePath: 'file-1.vault',
      updatedAt: DateTime.utc(2026, 1, 2),
      status: VaultFileStatus.synced,
      remoteId: 'remote-1',
    );

    final restored = VaultFile.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.sizeBytes, original.sizeBytes);
    expect(restored.mimeType, original.mimeType);
    expect(restored.relativePath, original.relativePath);
    expect(restored.updatedAt, original.updatedAt);
    expect(restored.status, original.status);
    expect(restored.remoteId, original.remoteId);
  });
}
