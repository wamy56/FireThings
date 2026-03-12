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

  /// Watermark a photo with overlay text using the `image` package in an
  /// isolate. Uses the same 3% margin ratio as the live preview painter.
  /// Returns JPEG bytes.
  Future<Uint8List> watermarkPhoto(
    Uint8List imageBytes,
    List<String> overlayLines, {
    OverlayPosition position = OverlayPosition.bottomLeft,
  }) async {
    if (overlayLines.isEmpty) return imageBytes;

    final posIndex = position.index;
    return Isolate.run(() {
      return _watermarkInIsolate(imageBytes, overlayLines, posIndex);
    });
  }

  /// Draw overlay text directly onto a photo using the `image` package.
  static Uint8List _watermarkInIsolate(
    Uint8List photoBytes,
    List<String> overlayLines,
    int positionIndex,
  ) {
    final photo = img.decodeImage(photoBytes);
    if (photo == null) return photoBytes;

    final position = OverlayPosition.values[positionIndex];
    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    // Use arial48 font from image package — scale by choosing appropriate font
    final font = img.arial48;
    final charHeight = font.lineHeight;
    final margin = (photo.width * 0.03).round();
    final padding = (charHeight * 0.6).round();
    final lineGap = (charHeight * 0.4).round();

    // Measure text widths
    int maxTextWidth = 0;
    for (final line in overlayLines) {
      int lineWidth = 0;
      for (final ch in line.codeUnits) {
        final glyph = font.characters[ch];
        if (glyph != null) lineWidth += glyph.xAdvance;
      }
      if (lineWidth > maxTextWidth) maxTextWidth = lineWidth;
    }

    // Block dimensions
    final blockWidth = maxTextWidth + (padding * 2);
    final blockHeight = (overlayLines.length * charHeight) +
        ((overlayLines.length - 1) * lineGap) +
        (padding * 2);

    // Block position — 3% margin from edges (matches live preview)
    final int blockX;
    if (isLeft) {
      blockX = margin;
    } else {
      blockX = photo.width - blockWidth - margin;
    }

    final int blockY;
    if (isTop) {
      blockY = margin;
    } else {
      blockY = photo.height - blockHeight - margin;
    }

    // Draw background rectangle
    img.fillRect(
      photo,
      x1: blockX,
      y1: blockY,
      x2: blockX + blockWidth,
      y2: blockY + blockHeight,
      color: img.ColorRgba8(0, 0, 0, 140),
    );

    // Draw each text line
    for (var i = 0; i < overlayLines.length; i++) {
      final textY = blockY + padding + (i * (charHeight + lineGap));

      int textX;
      if (isLeft) {
        textX = blockX + padding;
      } else {
        // Right-align: measure this line's width
        int lineWidth = 0;
        for (final ch in overlayLines[i].codeUnits) {
          final glyph = font.characters[ch];
          if (glyph != null) lineWidth += glyph.xAdvance;
        }
        textX = blockX + blockWidth - padding - lineWidth;
      }

      img.drawString(
        photo,
        overlayLines[i],
        font: font,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
    }

    return Uint8List.fromList(img.encodeJpg(photo, quality: 92));
  }

  // ─── FFmpeg Video Overlay ─────────────────────────────────────────

  /// Pre-computed integer font size based on resolution setting.
  static int _ffmpegFontSize(String resolution) {
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

  /// Margin in pixels proportional to resolution (~3% of width).
  static int _ffmpegMargin(String resolution) {
    switch (resolution) {
      case 'low':
        return 14;
      case 'medium':
        return 20;
      case 'high':
      default:
        return 28;
    }
  }

  /// Padding: ~60% of font size.
  static int _ffmpegPadding(int fontSize) => (fontSize * 0.6).round();

  /// Line gap: ~40% of font size.
  static int _ffmpegLineGap(int fontSize) => (fontSize * 0.4).round();

  /// Return the FFmpeg `x` value for text within the block.
  static String _ffmpegTextX({
    required OverlayPosition position,
    required int margin,
    required int padding,
  }) {
    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    if (isLeft) {
      return '${margin + padding}';
    } else {
      return 'w-tw-${margin + padding}';
    }
  }

  /// Build a drawbox filter for the grouped background rect using integer values.
  static String _ffmpegDrawBox({
    required OverlayPosition position,
    required int totalLines,
    required int maxTextChars,
    required int margin,
    required int padding,
    required int fontSize,
    required int lineGap,
  }) {
    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    // Estimate block width from max char count * average char width (0.55 * fontSize)
    final blockW = (padding * 2) + (maxTextChars * fontSize * 0.55).round() + 4;
    final blockH = (padding * 2) +
        (totalLines * fontSize) +
        ((totalLines - 1) * lineGap);

    final x = isLeft ? '$margin' : 'w-${blockW + margin}';
    final y = isTop ? '$margin' : 'h-${blockH + margin}';

    return 'drawbox=x=$x:y=$y:w=$blockW:h=$blockH'
        ':color=black@0.55:t=fill';
  }

  /// Build a dynamic FFmpeg drawtext filter where the date/time line updates
  /// per-frame using `%{pts\:localtime\:EPOCH}`.
  ///
  /// Uses pre-computed integer values — no single-quoted FFmpeg expressions.
  String buildDynamicFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final fontSize = _ffmpegFontSize(settings.resolution);
    final margin = _ffmpegMargin(settings.resolution);
    final padding = _ffmpegPadding(fontSize);
    final lineGap = _ffmpegLineGap(fontSize);
    final filters = <String>[];

    final isTop = settings.position == OverlayPosition.topLeft ||
        settings.position == OverlayPosition.topRight;

    // Collect all lines — date/time is dynamic, rest are static
    final staticLines = <String>[];
    bool hasDateTime = false;
    int maxChars = 0;

    if (settings.showDate || settings.showTime) {
      hasDateTime = true;
      int dtChars = 0;
      if (settings.showDate) dtChars += 10;
      if (settings.showDate && settings.showTime) dtChars += 2;
      if (settings.showTime) dtChars += 8;
      if (dtChars > maxChars) maxChars = dtChars;
    }

    if (settings.showCoords && coords != null && coords.isNotEmpty) {
      staticLines.add(coords);
      if (coords.length > maxChars) maxChars = coords.length;
    }
    if (settings.showAddress && address != null && address.isNotEmpty) {
      staticLines.add(address);
      if (address.length > maxChars) maxChars = address.length;
    }
    if (settings.showNote && settings.customNote.isNotEmpty) {
      staticLines.add(settings.customNote);
      if (settings.customNote.length > maxChars) maxChars = settings.customNote.length;
    }

    final totalLines = (hasDateTime ? 1 : 0) + staticLines.length;
    if (totalLines == 0) return '';

    final blockH = (padding * 2) +
        (totalLines * fontSize) +
        ((totalLines - 1) * lineGap);

    // Single grouped background box
    filters.add(_ffmpegDrawBox(
      position: settings.position,
      totalLines: totalLines,
      maxTextChars: maxChars,
      margin: margin,
      padding: padding,
      fontSize: fontSize,
      lineGap: lineGap,
    ));

    int lineIndex = 0;
    final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';

    // Helper to compute y for a given line index
    String yForLine(int idx) {
      final lineOffset = padding + (idx * (fontSize + lineGap));
      if (isTop) {
        return '${margin + lineOffset}';
      } else {
        return 'h-${blockH + margin - lineOffset}';
      }
    }

    final xVal = _ffmpegTextX(
      position: settings.position,
      margin: margin,
      padding: padding,
    );

    // Dynamic date/time line
    if (hasDateTime) {
      final epoch = recordingStartTime.millisecondsSinceEpoch ~/ 1000;

      String format = '';
      if (settings.showDate) format += '%d/%m/%Y';
      if (settings.showDate && settings.showTime) format += '  ';
      if (settings.showTime) format += '%H\\:%M\\:%S';

      filters.add(
        "drawtext=text='%{pts\\:localtime\\:$epoch\\:$format}'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=$xVal'
        ':y=${yForLine(lineIndex)}'
        '$fontParam',
      );
      lineIndex++;
    }

    // Static lines
    for (final line in staticLines) {
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=$xVal'
        ':y=${yForLine(lineIndex)}'
        '$fontParam',
      );
      lineIndex++;
    }

    return filters.join(',');
  }

  /// Build a fallback FFmpeg filter using per-second `enable='between(t,N,N+1)'`
  /// segments. Uses pre-computed integer values.
  String buildFallbackFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final fontSize = _ffmpegFontSize(settings.resolution);
    final margin = _ffmpegMargin(settings.resolution);
    final padding = _ffmpegPadding(fontSize);
    final lineGap = _ffmpegLineGap(fontSize);
    final filters = <String>[];
    final totalSeconds = (durationMs / 1000).ceil() + 1;

    final isTop = settings.position == OverlayPosition.topLeft ||
        settings.position == OverlayPosition.topRight;

    final staticLines = <String>[];
    int maxChars = 0;

    if (settings.showCoords && coords != null && coords.isNotEmpty) {
      staticLines.add(coords);
      if (coords.length > maxChars) maxChars = coords.length;
    }
    if (settings.showAddress && address != null && address.isNotEmpty) {
      staticLines.add(address);
      if (address.length > maxChars) maxChars = address.length;
    }
    if (settings.showNote && settings.customNote.isNotEmpty) {
      staticLines.add(settings.customNote);
      if (settings.customNote.length > maxChars) maxChars = settings.customNote.length;
    }

    final hasDateTime = settings.showDate || settings.showTime;
    if (hasDateTime) {
      int dtChars = 0;
      if (settings.showDate) dtChars += 10;
      if (settings.showDate && settings.showTime) dtChars += 2;
      if (settings.showTime) dtChars += 8;
      if (dtChars > maxChars) maxChars = dtChars;
    }

    final totalLines = (hasDateTime ? 1 : 0) + staticLines.length;
    if (totalLines == 0) return '';

    final blockH = (padding * 2) +
        (totalLines * fontSize) +
        ((totalLines - 1) * lineGap);

    // Single grouped background box
    filters.add(_ffmpegDrawBox(
      position: settings.position,
      totalLines: totalLines,
      maxTextChars: maxChars,
      margin: margin,
      padding: padding,
      fontSize: fontSize,
      lineGap: lineGap,
    ));

    final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';

    // Helper to compute y for a given line index
    String yForLine(int idx) {
      final lineOffset = padding + (idx * (fontSize + lineGap));
      if (isTop) {
        return '${margin + lineOffset}';
      } else {
        return 'h-${blockH + margin - lineOffset}';
      }
    }

    final xVal = _ffmpegTextX(
      position: settings.position,
      margin: margin,
      padding: padding,
    );

    // Generate per-second drawtext for the dynamic date/time line
    if (hasDateTime) {
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
          ':x=$xVal'
          ':y=${yForLine(0)}'
          '$fontParam'
          ":enable='between(t,$s,${s + 1})'",
        );
      }
    }

    // Static lines (always visible)
    int lineIndex = hasDateTime ? 1 : 0;
    for (final line in staticLines) {
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=$xVal'
        ':y=${yForLine(lineIndex)}'
        '$fontParam',
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
