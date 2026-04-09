import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compresses image bytes: decodes, resizes if larger than [maxWidth],
/// and re-encodes as JPEG at the given [quality].
/// Returns original bytes if already small enough or if decoding fails.
Uint8List compressImageBytes(
  Uint8List bytes, {
  int maxWidth = 2048,
  int quality = 80,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    // Already within bounds and small file — skip
    if (decoded.width <= maxWidth &&
        decoded.height <= maxWidth &&
        bytes.length <= 500 * 1024) {
      return bytes;
    }

    // Resize if either dimension exceeds maxWidth
    final needsResize =
        decoded.width > maxWidth || decoded.height > maxWidth;
    final image = needsResize
        ? (decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxWidth)
            : img.copyResize(decoded, height: maxWidth))
        : decoded;

    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  } catch (_) {
    return bytes;
  }
}
