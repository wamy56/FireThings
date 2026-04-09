import 'dart:typed_data';

/// Stub for non-web platforms — should never be called.
/// Mobile uses compressImageBytes from image_utils.dart instead.
Future<Uint8List> compressImageBytesWeb(
  Uint8List bytes, {
  int maxWidth = 2048,
  double quality = 0.80,
}) async {
  throw UnsupportedError('compressImageBytesWeb is only available on web');
}
