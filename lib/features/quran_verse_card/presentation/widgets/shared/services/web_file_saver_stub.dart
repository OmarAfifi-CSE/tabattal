import 'dart:typed_data';

/// Fallback saver for non-web environments.
Future<bool> saveBytesInBrowser({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  return false;
}
