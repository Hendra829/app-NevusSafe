import 'package:flutter_test/flutter_test.dart';
import 'package:nevus_safe/core/file_policy.dart';

void main() {
  test('accepts supported files below the size limit', () {
    expect(isSupportedFile('photo.JPG', 1024), isTrue);
  });

  test('rejects unsupported and oversized files', () {
    expect(isSupportedFile('script.exe', 1024), isFalse);
    expect(isSupportedFile('video.mp4', maxFileBytes + 1), isFalse);
  });

  test('accepts documented text and video formats case-insensitively', () {
    expect(isSupportedFile('notes.MD', 1024), isTrue);
    expect(isSupportedFile('clip.MKV', 1024), isTrue);
  });
}
