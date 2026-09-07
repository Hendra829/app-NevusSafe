enum VaultFileStatus { local, uploading, synced, downloading, failed }

class VaultFile {
  const VaultFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.relativePath,
    required this.updatedAt,
    this.status = VaultFileStatus.local,
    this.remoteId,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final String mimeType;
  final String relativePath;
  final DateTime updatedAt;
  final VaultFileStatus status;
  final String? remoteId;
}
