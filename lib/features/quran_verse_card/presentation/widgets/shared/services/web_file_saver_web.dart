// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Browser-native file download using Blob and dynamic anchor.
Future<bool> saveBytesInBrowser({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'image/png',
}) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final downloadUrl = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: downloadUrl)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(downloadUrl);
    return true;
  } catch (_) {
    return false;
  }
}
