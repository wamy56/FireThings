import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Position of the overlay block on the camera preview and output media.
enum OverlayPosition { bottomLeft, bottomRight, topLeft, topRight }

/// Overlay settings data class.
class OverlaySettings {
  final bool showDate;
  final bool showTime;
  final bool showCoords;
  final bool showAddress;
  final bool showNote;
  final String customNote;
  final String resolution; // 'low', 'medium', 'high'
  final OverlayPosition position;

  const OverlaySettings({
    this.showDate = true,
    this.showTime = true,
    this.showCoords = true,
    this.showAddress = false,
    this.showNote = false,
    this.customNote = '',
    this.resolution = 'high',
    this.position = OverlayPosition.bottomLeft,
  });

  OverlaySettings copyWith({
    bool? showDate,
    bool? showTime,
    bool? showCoords,
    bool? showAddress,
    bool? showNote,
    String? customNote,
    String? resolution,
    OverlayPosition? position,
  }) {
    return OverlaySettings(
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showCoords: showCoords ?? this.showCoords,
      showAddress: showAddress ?? this.showAddress,
      showNote: showNote ?? this.showNote,
      customNote: customNote ?? this.customNote,
      resolution: resolution ?? this.resolution,
      position: position ?? this.position,
    );
  }

  /// Build the overlay text lines for the current settings.
  List<String> buildOverlayLines({
    String? coords,
    String? address,
    DateTime? dateTime,
  }) {
    final lines = <String>[];
    final now = dateTime ?? DateTime.now();

    final datePart = showDate ? DateFormat('dd/MM/yyyy').format(now) : '';
    final timePart = showTime ? DateFormat('HH:mm:ss').format(now) : '';
    final dateTimeLine = '$datePart  $timePart'.trim();
    if (dateTimeLine.isNotEmpty) lines.add(dateTimeLine);

    if (showCoords && coords != null && coords.isNotEmpty) {
      lines.add(coords);
    }
    if (showAddress && address != null && address.isNotEmpty) {
      lines.add(address);
    }
    if (showNote && customNote.isNotEmpty) {
      lines.add(customNote);
    }

    return lines;
  }
}

/// Service for persisting overlay settings and watermarking photos/videos.
class TimestampCameraService {
  TimestampCameraService._();
  static final TimestampCameraService instance = TimestampCameraService._();

  static const _prefix = 'timestamp_camera_';

  Future<OverlaySettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final positionName = prefs.getString('${_prefix}position') ?? 'bottomLeft';
    final position = OverlayPosition.values.firstWhere(
      (e) => e.name == positionName,
      orElse: () => OverlayPosition.bottomLeft,
    );
    return OverlaySettings(
      showDate: prefs.getBool('${_prefix}showDate') ?? true,
      showTime: prefs.getBool('${_prefix}showTime') ?? true,
      showCoords: prefs.getBool('${_prefix}showCoords') ?? true,
      showAddress: prefs.getBool('${_prefix}showAddress') ?? false,
      showNote: prefs.getBool('${_prefix}showNote') ?? false,
      customNote: prefs.getString('${_prefix}customNote') ?? '',
      resolution: prefs.getString('${_prefix}resolution') ?? 'high',
      position: position,
    );
  }

  Future<void> saveSettings(OverlaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}showDate', settings.showDate);
    await prefs.setBool('${_prefix}showTime', settings.showTime);
    await prefs.setBool('${_prefix}showCoords', settings.showCoords);
    await prefs.setBool('${_prefix}showAddress', settings.showAddress);
    await prefs.setBool('${_prefix}showNote', settings.showNote);
    await prefs.setString('${_prefix}customNote', settings.customNote);
    await prefs.setString('${_prefix}resolution', settings.resolution);
    await prefs.setString('${_prefix}position', settings.position.name);
  }

  /// Watermark a photo with overlay text off the main thread.
  /// Uses the `image` package inside [Isolate.run] for zero UI jank.
  /// Returns JPEG bytes.
  Future<Uint8List> watermarkPhoto(
    Uint8List imageBytes,
    List<String> overlayLines, {
    OverlayPosition position = OverlayPosition.bottomLeft,
  }) async {
    if (overlayLines.isEmpty) return imageBytes;

    // Pass position index since enums can't cross isolate boundaries directly
    final posIndex = position.index;
    return Isolate.run(() {
      return _watermarkInIsolate(imageBytes, overlayLines, posIndex);
    });
  }

  /// Pure function that runs in an isolate — no Flutter imports allowed.
  static Uint8List _watermarkInIsolate(
    Uint8List imageBytes,
    List<String> overlayLines,
    int positionIndex,
  ) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final imgHeight = image.height;
    final imgWidth = image.width;
    final isLeft = positionIndex == 0 || positionIndex == 2; // bottomLeft or topLeft
    final isTop = positionIndex == 2 || positionIndex == 3;  // topLeft or topRight

    // Scale factor relative to 1080p baseline
    final scale = (imgWidth / 1080).clamp(1.0, 3.0);

    final font = img.arial48;
    final lineHeight = (font.lineHeight * 1.5 * scale).round();
    final margin = (imgWidth * 0.03).round();
    final padding = (font.lineHeight * 0.5 * scale).round();
    final maxTextWidth = (imgWidth * 0.55).round();

    // Word-wrap lines that exceed max text width
    final wrappedLines = <String>[];
    for (final line in overlayLines) {
      wrappedLines.addAll(_wrapText(font, line, maxTextWidth));
    }

    // Measure max line width
    int maxLineWidth = 0;
    for (final line in wrappedLines) {
      final w = _measureTextWidth(font, line);
      if (w > maxLineWidth) maxLineWidth = w;
    }

    final blockWidth = maxLineWidth + (padding * 2);
    final blockHeight = (wrappedLines.length * lineHeight) + (padding * 2);

    // Position the background rect, clamped to image bounds
    int rectX = isLeft ? margin : imgWidth - blockWidth - margin;
    int rectY = isTop ? margin : imgHeight - blockHeight - margin;
    rectX = rectX.clamp(0, (imgWidth - blockWidth).clamp(0, imgWidth));
    rectY = rectY.clamp(0, (imgHeight - blockHeight).clamp(0, imgHeight));

    final rectX2 = (rectX + blockWidth).clamp(0, imgWidth);
    final rectY2 = (rectY + blockHeight).clamp(0, imgHeight);

    img.fillRect(
      image,
      x1: rectX,
      y1: rectY,
      x2: rectX2,
      y2: rectY2,
      color: img.ColorRgba8(0, 0, 0, 140),
      alphaBlend: true,
    );

    // Draw each line aligned within the block
    for (var i = 0; i < wrappedLines.length; i++) {
      final line = wrappedLines[i];
      final lineWidth = _measureTextWidth(font, line);
      final x = isLeft
          ? rectX + padding
          : rectX + blockWidth - padding - lineWidth;
      final y = rectY + padding + (i * lineHeight);

      img.drawString(
        image,
        line,
        font: font,
        x: x,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  /// Word-wrap a text line to fit within maxWidth pixels using the bitmap font.
  static List<String> _wrapText(img.BitmapFont font, String text, int maxWidth) {
    if (_measureTextWidth(font, text) <= maxWidth) return [text];

    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      if (_measureTextWidth(font, testLine) <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);

    return lines.isEmpty ? [text] : lines;
  }

  /// Measure the pixel width of a text string using the bitmap font.
  static int _measureTextWidth(img.BitmapFont font, String text) {
    int width = 0;
    for (final char in text.codeUnits) {
      final glyph = font.characters[char];
      if (glyph != null) {
        width += glyph.xAdvance;
      }
    }
    return width;
  }

  // ─── FFmpeg Video Overlay ─────────────────────────────────────────

  /// Derive font size from resolution setting (not from videoHeight which
  /// may report sensor dimensions in the wrong orientation).
  static int _fontSizeForResolution(String resolution) {
    switch (resolution) {
      case 'low':
        return 20;
      case 'medium':
        return 28;
      case 'high':
      default:
        return 36;
    }
  }

  /// Return the FFmpeg `x` expression for the given [position].
  static String _ffmpegX(OverlayPosition position) {
    switch (position) {
      case OverlayPosition.bottomLeft:
      case OverlayPosition.topLeft:
        return '20';
      case OverlayPosition.bottomRight:
      case OverlayPosition.topRight:
        return 'w-tw-20';
    }
  }

  /// Return the FFmpeg `y` expression for a line at [lineIndex] of [totalLines].
  static String _ffmpegY({
    required OverlayPosition position,
    required int lineIndex,
    required int totalLines,
    required int fontSize,
  }) {
    final lineSpacing = (fontSize * 1.5).toInt();
    final edgePadding = 20;
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    if (isTop) {
      // Top-down: first line at edgePadding, subsequent below
      final topOffset = edgePadding + (lineIndex * lineSpacing);
      return '$topOffset';
    } else {
      // Bottom-up: last line near bottom, earlier lines above
      final bottomOffset =
          edgePadding + ((totalLines - 1 - lineIndex) * lineSpacing);
      return 'h-$bottomOffset-th';
    }
  }

  /// Build a dynamic FFmpeg drawtext filter where the date/time line updates
  /// per-frame using `%{pts\:localtime\:EPOCH}`.
  ///
  /// Static lines (coords, address, note) remain constant.
  /// Uses FFmpeg's built-in `h` / `w` variables so the overlay renders at the
  /// correct position regardless of the actual video dimensions.
  String buildDynamicFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final fontSize = _fontSizeForResolution(settings.resolution);
    final xExpr = _ffmpegX(settings.position);
    final filters = <String>[];

    // Collect all lines — date/time is dynamic, rest are static
    final staticLines = <String>[];
    bool hasDateTime = false;

    // Date/time line (dynamic)
    if (settings.showDate || settings.showTime) {
      hasDateTime = true;
    }

    // Static lines
    if (settings.showCoords && coords != null && coords.isNotEmpty) {
      staticLines.add(coords);
    }
    if (settings.showAddress && address != null && address.isNotEmpty) {
      staticLines.add(address);
    }
    if (settings.showNote && settings.customNote.isNotEmpty) {
      staticLines.add(settings.customNote);
    }

    final totalLines = (hasDateTime ? 1 : 0) + staticLines.length;
    if (totalLines == 0) return '';

    int lineIndex = 0;

    // Dynamic date/time line using pts:localtime expansion
    if (hasDateTime) {
      final epoch = recordingStartTime.millisecondsSinceEpoch ~/ 1000;

      // Build strftime format based on settings
      String format = '';
      if (settings.showDate) format += '%d/%m/%Y';
      if (settings.showDate && settings.showTime) format += '  ';
      if (settings.showTime) format += '%H\\:%M\\:%S';

      final yExpr = _ffmpegY(
        position: settings.position,
        lineIndex: lineIndex,
        totalLines: totalLines,
        fontSize: fontSize,
      );

      final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';
      filters.add(
        "drawtext=text='%{pts\\:localtime\\:$epoch\\:$format}'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=$xExpr'
        ':y=$yExpr'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8'
        '$fontParam',
      );
      lineIndex++;
    }

    // Static lines
    final staticFontParam = fontPath != null ? ":fontfile='$fontPath'" : '';
    for (final line in staticLines) {
      final yExpr = _ffmpegY(
        position: settings.position,
        lineIndex: lineIndex,
        totalLines: totalLines,
        fontSize: fontSize,
      );
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=$xExpr'
        ':y=$yExpr'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8'
        '$staticFontParam',
      );
      lineIndex++;
    }

    return filters.join(',');
  }

  /// Build a fallback FFmpeg filter using per-second `enable='between(t,N,N+1)'`
  /// segments. Works with any FFmpeg build that doesn't support `%{pts:localtime}`.
  String buildFallbackFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final fontSize = _fontSizeForResolution(settings.resolution);
    final xExpr = _ffmpegX(settings.position);
    final filters = <String>[];
    final totalSeconds = (durationMs / 1000).ceil() + 1;

    // Static lines (coords, address, note)
    final staticLines = <String>[];
    if (settings.showCoords && coords != null && coords.isNotEmpty) {
      staticLines.add(coords);
    }
    if (settings.showAddress && address != null && address.isNotEmpty) {
      staticLines.add(address);
    }
    if (settings.showNote && settings.customNote.isNotEmpty) {
      staticLines.add(settings.customNote);
    }

    final hasDateTime = settings.showDate || settings.showTime;
    final totalLines = (hasDateTime ? 1 : 0) + staticLines.length;
    if (totalLines == 0) return '';

    // Generate per-second drawtext for the dynamic date/time line
    final fallbackFontParam = fontPath != null ? ":fontfile='$fontPath'" : '';
    if (hasDateTime) {
      final yExpr = _ffmpegY(
        position: settings.position,
        lineIndex: 0,
        totalLines: totalLines,
        fontSize: fontSize,
      );

      for (var s = 0; s < totalSeconds; s++) {
        final t = recordingStartTime.add(Duration(seconds: s));
        final datePart =
            settings.showDate ? DateFormat('dd/MM/yyyy').format(t) : '';
        final timePart =
            settings.showTime ? DateFormat('HH:mm:ss').format(t) : '';
        final text = '$datePart  $timePart'.trim();
        final escaped = _escapeForFfmpegDrawtext(text);

        filters.add(
          "drawtext=text='$escaped'"
          ':fontsize=$fontSize'
          ':fontcolor=white'
          ':x=$xExpr'
          ':y=$yExpr'
          ':box=1'
          ':boxcolor=black@0.6'
          ':boxborderw=8'
          '$fallbackFontParam'
          ":enable='between(t,$s,${s + 1})'",
        );
      }
    }

    // Static lines (always visible)
    int lineIndex = hasDateTime ? 1 : 0;
    for (final line in staticLines) {
      final yExpr = _ffmpegY(
        position: settings.position,
        lineIndex: lineIndex,
        totalLines: totalLines,
        fontSize: fontSize,
      );
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=$xExpr'
        ':y=$yExpr'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8'
        '$fallbackFontParam',
      );
      lineIndex++;
    }

    return filters.join(',');
  }

  /// Escape all characters that are special in FFmpeg's drawtext filter.
  String _escapeForFfmpegDrawtext(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('%', r'%%')
        .replaceAll(':', r'\:')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll(';', r'\;');
  }
}
