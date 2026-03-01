import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Overlay settings data class.
class OverlaySettings {
  final bool showDate;
  final bool showTime;
  final bool showCoords;
  final bool showAddress;
  final bool showNote;
  final String customNote;
  final String resolution; // 'low', 'medium', 'high'

  const OverlaySettings({
    this.showDate = true,
    this.showTime = true,
    this.showCoords = true,
    this.showAddress = false,
    this.showNote = false,
    this.customNote = '',
    this.resolution = 'high',
  });

  OverlaySettings copyWith({
    bool? showDate,
    bool? showTime,
    bool? showCoords,
    bool? showAddress,
    bool? showNote,
    String? customNote,
    String? resolution,
  }) {
    return OverlaySettings(
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showCoords: showCoords ?? this.showCoords,
      showAddress: showAddress ?? this.showAddress,
      showNote: showNote ?? this.showNote,
      customNote: customNote ?? this.customNote,
      resolution: resolution ?? this.resolution,
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
    return OverlaySettings(
      showDate: prefs.getBool('${_prefix}showDate') ?? true,
      showTime: prefs.getBool('${_prefix}showTime') ?? true,
      showCoords: prefs.getBool('${_prefix}showCoords') ?? true,
      showAddress: prefs.getBool('${_prefix}showAddress') ?? false,
      showNote: prefs.getBool('${_prefix}showNote') ?? false,
      customNote: prefs.getString('${_prefix}customNote') ?? '',
      resolution: prefs.getString('${_prefix}resolution') ?? 'high',
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
  }

  /// Watermark a photo with overlay text off the main thread.
  /// Uses the `image` package inside [Isolate.run] for zero UI jank.
  /// Returns JPEG bytes.
  Future<Uint8List> watermarkPhoto(
    Uint8List imageBytes,
    List<String> overlayLines,
  ) async {
    if (overlayLines.isEmpty) return imageBytes;

    return Isolate.run(() {
      return _watermarkInIsolate(imageBytes, overlayLines);
    });
  }

  /// Pure function that runs in an isolate — no Flutter imports allowed.
  static Uint8List _watermarkInIsolate(
    Uint8List imageBytes,
    List<String> overlayLines,
  ) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final imgHeight = image.height;
    final imgWidth = image.width;

    // Use arial48 (largest built-in font). For very high-res photos we
    // accept the fixed size — it's readable at 1080p+ and avoids the
    // complexity of TTF rendering in an isolate.
    final font = img.arial48;
    final lineHeight = (font.lineHeight * 1.3).round();
    final margin = (imgWidth * 0.03).round();
    final padding = (font.lineHeight * 0.5).round();

    // Measure max line width
    int maxLineWidth = 0;
    for (final line in overlayLines) {
      final w = _measureTextWidth(font, line);
      if (w > maxLineWidth) maxLineWidth = w;
    }

    final blockWidth = maxLineWidth + (padding * 2);
    final blockHeight = (overlayLines.length * lineHeight) + (padding * 2);

    // Draw semi-transparent background rect in bottom-right corner
    final rectX = imgWidth - blockWidth - margin;
    final rectY = imgHeight - blockHeight - margin;

    img.fillRect(
      image,
      x1: rectX,
      y1: rectY,
      x2: rectX + blockWidth,
      y2: rectY + blockHeight,
      color: img.ColorRgba8(0, 0, 0, 140),
      alphaBlend: true,
    );

    // Draw each line right-aligned within the block
    for (var i = 0; i < overlayLines.length; i++) {
      final line = overlayLines[i];
      final lineWidth = _measureTextWidth(font, line);
      final x = imgWidth - margin - padding - lineWidth;
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

  /// Build a dynamic FFmpeg drawtext filter where the date/time line updates
  /// per-frame using `%{pts\:localtime\:EPOCH}`.
  ///
  /// Static lines (coords, address, note) remain constant.
  String buildDynamicFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    required int videoHeight,
    String? coords,
    String? address,
  }) {
    final fontSize = videoHeight ~/ 30;
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

    final bottomPadding = 20;
    final lineSpacing = (fontSize * 1.5).toInt();
    int lineIndex = 0;

    // Dynamic date/time line using pts:localtime expansion
    if (hasDateTime) {
      final epoch = recordingStartTime.millisecondsSinceEpoch ~/ 1000;

      // Build strftime format based on settings
      String format = '';
      if (settings.showDate) format += '%d/%m/%Y';
      if (settings.showDate && settings.showTime) format += '  ';
      if (settings.showTime) format += '%H\\:%M\\:%S';

      final yOffset = videoHeight -
          bottomPadding -
          ((totalLines - lineIndex) * lineSpacing);

      filters.add(
        "drawtext=text='%{pts\\:localtime\\:$epoch\\:$format}'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=w-tw-20'
        ':y=$yOffset'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8',
      );
      lineIndex++;
    }

    // Static lines
    for (final line in staticLines) {
      final yOffset = videoHeight -
          bottomPadding -
          ((totalLines - lineIndex) * lineSpacing);
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=w-tw-20'
        ':y=$yOffset'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8',
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
    required int videoHeight,
    String? coords,
    String? address,
  }) {
    final fontSize = videoHeight ~/ 30;
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

    final bottomPadding = 20;
    final lineSpacing = (fontSize * 1.5).toInt();

    // Generate per-second drawtext for the dynamic date/time line
    if (hasDateTime) {
      final yOffset = videoHeight -
          bottomPadding -
          (totalLines * lineSpacing);

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
          ':x=w-tw-20'
          ':y=$yOffset'
          ':box=1'
          ':boxcolor=black@0.6'
          ':boxborderw=8'
          ":enable='between(t,$s,${s + 1})'",
        );
      }
    }

    // Static lines (always visible)
    int lineIndex = hasDateTime ? 1 : 0;
    for (final line in staticLines) {
      final yOffset = videoHeight -
          bottomPadding -
          ((totalLines - lineIndex) * lineSpacing);
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=w-tw-20'
        ':y=$yOffset'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8',
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
