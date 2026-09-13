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

  factory VaultFile.fromJson(Map<String, dynamic> json) => VaultFile(
        id: json['id'] as String,
        name: json['name'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        mimeType: json['mimeType'] as String,
        relativePath: json['relativePath'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: VaultFileStatus.values.firstWhere(
          (status) => status.name == json['status'],
          orElse: () => VaultFileStatus.local,
        ),
        remoteId: json['remoteId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        'relativePath': relativePath,
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        if (remoteId != null) 'remoteId': remoteId,
      };
}
