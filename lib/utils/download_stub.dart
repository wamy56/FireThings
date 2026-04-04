import 'dart:typed_data';

void downloadFile(Uint8List bytes, String filename, [String mimeType = 'application/pdf']) {
  // No-op on non-web platforms — use share/print instead
}
