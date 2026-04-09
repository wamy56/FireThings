import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web-native image compression using the browser's Canvas API.
/// Much faster than the pure-Dart `image` package on web.
Future<Uint8List> compressImageBytesWeb(
  Uint8List bytes, {
  int maxWidth = 2048,
  double quality = 0.80,
}) async {
  try {
    // Decode image using the browser's native decoder
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final img = html.ImageElement();
    final loadCompleter = Completer<void>();
    img.onLoad.first.then((_) => loadCompleter.complete());
    img.onError.first.then((_) => loadCompleter.completeError('Failed to load image'));
    img.src = url;
    await loadCompleter.future.timeout(const Duration(seconds: 15));

    final origW = img.naturalWidth;
    final origH = img.naturalHeight;

    // Calculate target dimensions
    int targetW = origW;
    int targetH = origH;
    if (origW > maxWidth || origH > maxWidth) {
      if (origW >= origH) {
        targetW = maxWidth;
        targetH = (origH * maxWidth / origW).round();
      } else {
        targetH = maxWidth;
        targetW = (origW * maxWidth / origH).round();
      }
    } else if (bytes.length <= 500 * 1024) {
      // Already small dimensions and file size — return as-is
      html.Url.revokeObjectUrl(url);
      return bytes;
    }

    // Draw onto a canvas at the target size
    final canvas = html.CanvasElement(width: targetW, height: targetH);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, targetW, targetH);
    html.Url.revokeObjectUrl(url);

    // Encode as JPEG using the browser's native encoder
    final dataUrl = canvas.toDataUrl('image/jpeg', quality);
    // dataUrl is "data:image/jpeg;base64,<base64data>"
    final base64 = dataUrl.split(',').last;
    final compressed = _base64Decode(base64);

    return compressed;
  } catch (_) {
    return bytes;
  }
}

Uint8List _base64Decode(String input) {
  // Use dart:html's window.atob for base64 decoding
  final decoded = html.window.atob(input);
  final bytes = Uint8List(decoded.length);
  for (int i = 0; i < decoded.length; i++) {
    bytes[i] = decoded.codeUnitAt(i);
  }
  return bytes;
}
