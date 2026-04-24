import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfFontRegistry {
  PdfFontRegistry._();
  static final PdfFontRegistry instance = PdfFontRegistry._();

  pw.Font? _outfitDisplay;
  pw.Font? _outfitBold;
  pw.Font? _interRegular;
  pw.Font? _interMedium;
  pw.Font? _interSemibold;
  pw.Font? _interBold;
  pw.Font? _mono;

  Future<void> ensureLoaded() async {
    if (_outfitDisplay != null) return;
    _outfitDisplay = pw.Font.ttf(await rootBundle.load('assets/fonts/Outfit/static/Outfit-ExtraBold.ttf'));
    _outfitBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Outfit/static/Outfit-Bold.ttf'));
    _interRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter/static/Inter_24pt-Regular.ttf'));
    _interMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter/static/Inter_24pt-Medium.ttf'));
    _interSemibold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter/static/Inter_24pt-SemiBold.ttf'));
    _interBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter/static/Inter_24pt-Bold.ttf'));
    _mono = pw.Font.ttf(await rootBundle.load('assets/fonts/JetBrains_Mono/static/JetBrainsMono-Medium.ttf'));
  }

  pw.Font get outfitDisplay => _requireLoaded(_outfitDisplay);
  pw.Font get outfitBold => _requireLoaded(_outfitBold);
  pw.Font get interRegular => _requireLoaded(_interRegular);
  pw.Font get interMedium => _requireLoaded(_interMedium);
  pw.Font get interSemibold => _requireLoaded(_interSemibold);
  pw.Font get interBold => _requireLoaded(_interBold);
  pw.Font get mono => _requireLoaded(_mono);

  void loadFromBytes(Map<String, Uint8List> fontBytes) {
    if (_outfitDisplay != null) return;
    _outfitDisplay = pw.Font.ttf(ByteData.sublistView(fontBytes['outfitDisplay']!));
    _outfitBold = pw.Font.ttf(ByteData.sublistView(fontBytes['outfitBold']!));
    _interRegular = pw.Font.ttf(ByteData.sublistView(fontBytes['interRegular']!));
    _interMedium = pw.Font.ttf(ByteData.sublistView(fontBytes['interMedium']!));
    _interSemibold = pw.Font.ttf(ByteData.sublistView(fontBytes['interSemibold']!));
    _interBold = pw.Font.ttf(ByteData.sublistView(fontBytes['interBold']!));
    _mono = pw.Font.ttf(ByteData.sublistView(fontBytes['mono']!));
  }

  Map<String, Uint8List> extractFontBytes() {
    return {
      'outfitDisplay': _extractBytes(_outfitDisplay!),
      'outfitBold': _extractBytes(_outfitBold!),
      'interRegular': _extractBytes(_interRegular!),
      'interMedium': _extractBytes(_interMedium!),
      'interSemibold': _extractBytes(_interSemibold!),
      'interBold': _extractBytes(_interBold!),
      'mono': _extractBytes(_mono!),
    };
  }

  static Uint8List _extractBytes(pw.Font font) {
    final ttf = font as pw.TtfFont;
    return Uint8List.fromList(
      ttf.data.buffer.asUint8List(ttf.data.offsetInBytes, ttf.data.lengthInBytes),
    );
  }

  pw.Font _requireLoaded(pw.Font? f) {
    if (f == null) {
      throw StateError('PdfFontRegistry.ensureLoaded() must be called before use');
    }
    return f;
  }
}
