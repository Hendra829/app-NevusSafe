const maxFileBytes = 64 * 1024 * 1024;
const uploadChunkBytes = 8 * 1024 * 1024;

const supportedExtensions = <String>{
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'mp4', 'mov',
  'raw', 'mpeg4', 'mkv', 'vlc', 'pdf', 'docx', 'xlsx', 'pptx', 'txt',
  'csv', 'zip', 'md', 'apk',
};

bool isSupportedFile(String filename, int sizeBytes) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || sizeBytes < 0 || sizeBytes > maxFileBytes) return false;
  return supportedExtensions.contains(filename.substring(dot + 1).toLowerCase());
}
