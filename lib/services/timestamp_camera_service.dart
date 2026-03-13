import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Data types that can be assigned to each overlay corner.
enum OverlayDataType { date, time, gpsCoords, gpsAddress, customNote }

/// The four corners of the overlay.
enum OverlayCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Per-corner overlay settings — each corner independently assigned a data type.
class OverlaySettings {
  final OverlayDataType? topLeft;
  final OverlayDataType? topRight;
  final OverlayDataType? bottomLeft;
  final OverlayDataType? bottomRight;
  final String customNote;
  final String resolution; // 'low', 'medium', 'high'

  const OverlaySettings({
    this.topLeft = OverlayDataType.date,
    this.topRight = OverlayDataType.time,
    this.bottomLeft = OverlayDataType.gpsCoords,
    this.bottomRight,
    this.customNote = '',
    this.resolution = 'high',
  });

  OverlaySettings copyWith({
    OverlayDataType? Function()? topLeft,
    OverlayDataType? Function()? topRight,
    OverlayDataType? Function()? bottomLeft,
    OverlayDataType? Function()? bottomRight,
    String? customNote,
    String? resolution,
  }) {
    return OverlaySettings(
      topLeft: topLeft != null ? topLeft() : this.topLeft,
      topRight: topRight != null ? topRight() : this.topRight,
      bottomLeft: bottomLeft != null ? bottomLeft() : this.bottomLeft,
      bottomRight: bottomRight != null ? bottomRight() : this.bottomRight,
      customNote: customNote ?? this.customNote,
      resolution: resolution ?? this.resolution,
    );
  }

  /// Get the data type assigned to a specific corner.
  OverlayDataType? operator [](OverlayCorner corner) {
    switch (corner) {
      case OverlayCorner.topLeft:
        return topLeft;
      case OverlayCorner.topRight:
        return topRight;
      case OverlayCorner.bottomLeft:
        return bottomLeft;
      case OverlayCorner.bottomRight:
        return bottomRight;
    }
  }

  /// Whether any corner uses the customNote type.
  bool get hasCustomNote =>
      topLeft == OverlayDataType.customNote ||
      topRight == OverlayDataType.customNote ||
      bottomLeft == OverlayDataType.customNote ||
      bottomRight == OverlayDataType.customNote;

  /// Whether any corner has an assigned data type.
  bool get hasAnyOverlay =>
      topLeft != null || topRight != null || bottomLeft != null || bottomRight != null;

  /// Resolve the display text for a specific corner.
  String? textForCorner(
    OverlayCorner corner, {
    String? coords,
    String? address,
    DateTime? dateTime,
  }) {
    final type = this[corner];
    if (type == null) return null;
    final now = dateTime ?? DateTime.now();

    switch (type) {
      case OverlayDataType.date:
        return DateFormat('dd/MM/yyyy').format(now);
      case OverlayDataType.time:
        return DateFormat('HH:mm:ss').format(now);
      case OverlayDataType.gpsCoords:
        return coords;
      case OverlayDataType.gpsAddress:
        return address;
      case OverlayDataType.customNote:
        return customNote.isNotEmpty ? customNote : null;
    }
  }

  /// Build a map of corner → resolved text for all corners with data.
  Map<OverlayCorner, String> buildCornerTexts({
    String? coords,
    String? address,
    DateTime? dateTime,
  }) {
    final map = <OverlayCorner, String>{};
    for (final corner in OverlayCorner.values) {
      final text = textForCorner(corner, coords: coords, address: address, dateTime: dateTime);
      if (text != null && text.isNotEmpty) {
        map[corner] = text;
      }
    }
    return map;
  }
}

/// Shared proportional metrics for overlay sizing.
class OverlayMetrics {
  final double fontSize, margin, padding;
  const OverlayMetrics({
    required this.fontSize,
    required this.margin,
    required this.padding,
  });
}

/// Compute proportional overlay metrics from output dimensions.
OverlayMetrics computeOverlayMetrics(double width, double height) {
  final fontSize = height * 0.024;
  return OverlayMetrics(
    fontSize: fontSize,
    margin: width * 0.03,
    padding: fontSize * 0.6,
  );
}

/// Service for persisting overlay settings and watermarking photos/videos.
class TimestampCameraService {
  TimestampCameraService._();
  static final TimestampCameraService instance = TimestampCameraService._();

  static const _prefix = 'timestamp_camera_';

  /// Approximate video dimensions for each resolution setting (portrait).
  static (int, int) videoDimensionsForResolution(String resolution) {
    switch (resolution) {
      case 'low':
        return (720, 1280);
      case 'medium':
        return (1080, 1920);
      case 'high':
      default:
        return (1080, 1920);
    }
  }

  Future<OverlaySettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    OverlayDataType? readCorner(String key) {
      final val = prefs.getString('$_prefix$key');
      if (val == null || val == 'none') return null;
      return OverlayDataType.values.firstWhere(
        (e) => e.name == val,
        orElse: () => OverlayDataType.date,
      );
    }

    return OverlaySettings(
      topLeft: readCorner('topLeft') ??
          (prefs.containsKey('${_prefix}topLeft') ? null : OverlayDataType.date),
      topRight: readCorner('topRight') ??
          (prefs.containsKey('${_prefix}topRight') ? null : OverlayDataType.time),
      bottomLeft: readCorner('bottomLeft') ??
          (prefs.containsKey('${_prefix}bottomLeft') ? null : OverlayDataType.gpsCoords),
      bottomRight: readCorner('bottomRight'),
      customNote: prefs.getString('${_prefix}customNote') ?? '',
      resolution: prefs.getString('${_prefix}resolution') ?? 'high',
    );
  }

  Future<void> saveSettings(OverlaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}topLeft', settings.topLeft?.name ?? 'none');
    await prefs.setString('${_prefix}topRight', settings.topRight?.name ?? 'none');
    await prefs.setString('${_prefix}bottomLeft', settings.bottomLeft?.name ?? 'none');
    await prefs.setString('${_prefix}bottomRight', settings.bottomRight?.name ?? 'none');
    await prefs.setString('${_prefix}customNote', settings.customNote);
    await prefs.setString('${_prefix}resolution', settings.resolution);
  }

  // ─── Photo Watermark ──────────────────────────────────────────────

  /// Watermark a photo with per-corner overlay text using the `image` package
  /// in an isolate. Returns JPEG bytes.
  Future<Uint8List> watermarkPhoto(
    Uint8List imageBytes,
    Map<OverlayCorner, String> cornerTexts,
  ) async {
    if (cornerTexts.isEmpty) return imageBytes;

    // Serialize corner data for isolate (enums can't cross isolate boundary)
    final serialized = cornerTexts.map(
      (corner, text) => MapEntry(corner.index, text),
    );
    return Isolate.run(() {
      return _watermarkInIsolate(imageBytes, serialized);
    });
  }

  static Uint8List _watermarkInIsolate(
    Uint8List photoBytes,
    Map<int, String> cornerTexts,
  ) {
    final photo = img.decodeImage(photoBytes);
    if (photo == null) return photoBytes;

    final metrics = computeOverlayMetrics(
      photo.width.toDouble(),
      photo.height.toDouble(),
    );
    final margin = metrics.margin.round();
    final padding = metrics.padding.round();

    // Select closest built-in bitmap font based on target size
    final targetFontSize = metrics.fontSize;
    final img.BitmapFont font;
    if (targetFontSize >= 36) {
      font = img.arial48;
    } else if (targetFontSize >= 19) {
      font = img.arial24;
    } else {
      font = img.arial14;
    }
    final charHeight = font.lineHeight;

    for (final entry in cornerTexts.entries) {
      final cornerIndex = entry.key;
      final text = entry.value;
      final isLeft = cornerIndex == OverlayCorner.topLeft.index ||
          cornerIndex == OverlayCorner.bottomLeft.index;
      final isTop = cornerIndex == OverlayCorner.topLeft.index ||
          cornerIndex == OverlayCorner.topRight.index;

      // Measure text width
      int textWidth = 0;
      for (final ch in text.codeUnits) {
        final glyph = font.characters[ch];
        if (glyph != null) textWidth += glyph.xAdvance;
      }

      final blockWidth = textWidth + (padding * 2);
      final blockHeight = charHeight + (padding * 2);

      // Block position
      final int blockX = isLeft ? margin : photo.width - blockWidth - margin;
      final int blockY = isTop ? margin : photo.height - blockHeight - margin;

      // Draw background rectangle
      img.fillRect(
        photo,
        x1: blockX,
        y1: blockY,
        x2: blockX + blockWidth,
        y2: blockY + blockHeight,
        color: img.ColorRgba8(0, 0, 0, 140),
      );

      // Draw text
      int textX;
      if (isLeft) {
        textX = blockX + padding;
      } else {
        textX = blockX + blockWidth - padding - textWidth;
      }
      final textY = blockY + padding;

      img.drawString(
        photo,
        text,
        font: font,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
    }

    return Uint8List.fromList(img.encodeJpg(photo, quality: 92));
  }

  // ─── FFmpeg Video Overlay ─────────────────────────────────────────

  /// Build a dynamic FFmpeg drawtext filter with per-corner overlays.
  /// Date/time corners use `%{pts\:localtime\:EPOCH}` for per-frame updates.
  String buildFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final (videoW, videoH) = videoDimensionsForResolution(settings.resolution);
    final metrics = computeOverlayMetrics(videoW.toDouble(), videoH.toDouble());
    final fontSize = metrics.fontSize.round();
    final margin = metrics.margin.round();
    final padding = metrics.padding.round();
    final filters = <String>[];
    final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';
    final epoch = recordingStartTime.millisecondsSinceEpoch ~/ 1000;

    // Estimated char width for drawbox sizing
    final charWidthEst = (fontSize * 0.55).round();

    for (final corner in OverlayCorner.values) {
      final type = settings[corner];
      if (type == null) continue;

      final isLeft = corner == OverlayCorner.topLeft || corner == OverlayCorner.bottomLeft;
      final isTop = corner == OverlayCorner.topLeft || corner == OverlayCorner.topRight;

      // Resolve text or format string
      String? text;
      String? dynamicFormat;
      int estimatedChars = 0;

      switch (type) {
        case OverlayDataType.date:
          dynamicFormat = '%d/%m/%Y';
          estimatedChars = 10;
          break;
        case OverlayDataType.time:
          dynamicFormat = '%H\\:%M\\:%S';
          estimatedChars = 8;
          break;
        case OverlayDataType.gpsCoords:
          text = coords;
          estimatedChars = coords?.length ?? 0;
          break;
        case OverlayDataType.gpsAddress:
          text = address;
          estimatedChars = address?.length ?? 0;
          break;
        case OverlayDataType.customNote:
          text = settings.customNote;
          estimatedChars = settings.customNote.length;
          break;
      }

      if (text == null && dynamicFormat == null) continue;
      if (text != null && text.isEmpty) continue;

      // Drawbox
      final blockW = (padding * 2) + (estimatedChars * charWidthEst) + 4;
      final blockH = (padding * 2) + fontSize;
      final boxX = isLeft ? '$margin' : 'w-${blockW + margin}';
      final boxY = isTop ? '$margin' : 'h-${blockH + margin}';

      filters.add(
        'drawbox=x=$boxX:y=$boxY:w=$blockW:h=$blockH:color=black@0.55:t=fill',
      );

      // Drawtext
      final textX = isLeft ? '${margin + padding}' : 'w-tw-${margin + padding}';
      final textY = isTop ? '${margin + padding}' : 'h-${blockH + margin - padding}';

      if (dynamicFormat != null) {
        filters.add(
          "drawtext=text='%{pts\\:localtime\\:$epoch\\:$dynamicFormat}'"
          ':fontsize=$fontSize'
          ':fontcolor=white'
          ':x=$textX'
          ':y=$textY'
          '$fontParam',
        );
      } else {
        final escaped = _escapeForFfmpegDrawtext(text!);
        filters.add(
          "drawtext=text='$escaped'"
          ':fontsize=$fontSize'
          ':fontcolor=white'
          ':x=$textX'
          ':y=$textY'
          '$fontParam',
        );
      }
    }

    return filters.join(',');
  }

  /// Build a fallback FFmpeg filter using per-second `enable='between(t,N,N+1)'`
  /// segments for date/time corners.
  String buildFallbackFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final (videoW, videoH) = videoDimensionsForResolution(settings.resolution);
    final metrics = computeOverlayMetrics(videoW.toDouble(), videoH.toDouble());
    final fontSize = metrics.fontSize.round();
    final margin = metrics.margin.round();
    final padding = metrics.padding.round();
    final filters = <String>[];
    final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';
    final totalSeconds = (durationMs / 1000).ceil() + 1;

    final charWidthEst = (fontSize * 0.55).round();

    for (final corner in OverlayCorner.values) {
      final type = settings[corner];
      if (type == null) continue;

      final isLeft = corner == OverlayCorner.topLeft || corner == OverlayCorner.bottomLeft;
      final isTop = corner == OverlayCorner.topLeft || corner == OverlayCorner.topRight;
      final isDynamic = type == OverlayDataType.date || type == OverlayDataType.time;

      // Resolve static text
      String? staticText;
      int estimatedChars = 0;
      if (!isDynamic) {
        switch (type) {
          case OverlayDataType.gpsCoords:
            staticText = coords;
            estimatedChars = coords?.length ?? 0;
            break;
          case OverlayDataType.gpsAddress:
            staticText = address;
            estimatedChars = address?.length ?? 0;
            break;
          case OverlayDataType.customNote:
            staticText = settings.customNote;
            estimatedChars = settings.customNote.length;
            break;
          default:
            break;
        }
        if (staticText == null || staticText.isEmpty) continue;
      } else {
        estimatedChars = type == OverlayDataType.date ? 10 : 8;
      }

      // Drawbox
      final blockW = (padding * 2) + (estimatedChars * charWidthEst) + 4;
      final blockH = (padding * 2) + fontSize;
      final boxX = isLeft ? '$margin' : 'w-${blockW + margin}';
      final boxY = isTop ? '$margin' : 'h-${blockH + margin}';

      filters.add(
        'drawbox=x=$boxX:y=$boxY:w=$blockW:h=$blockH:color=black@0.55:t=fill',
      );

      final textX = isLeft ? '${margin + padding}' : 'w-tw-${margin + padding}';
      final textY = isTop ? '${margin + padding}' : 'h-${blockH + margin - padding}';

      if (isDynamic) {
        // Per-second drawtext for date/time
        for (var s = 0; s < totalSeconds; s++) {
          final t = recordingStartTime.add(Duration(seconds: s));
          String text;
          if (type == OverlayDataType.date) {
            text = DateFormat('dd/MM/yyyy').format(t);
          } else {
            text = DateFormat('HH:mm:ss').format(t);
          }
          final escaped = _escapeForFfmpegDrawtext(text);

          filters.add(
            "drawtext=text='$escaped'"
            ':fontsize=$fontSize'
            ':fontcolor=white'
            ':x=$textX'
            ':y=$textY'
            '$fontParam'
            ":enable='between(t,$s,${s + 1})'",
          );
        }
      } else {
        final escaped = _escapeForFfmpegDrawtext(staticText!);
        filters.add(
          "drawtext=text='$escaped'"
          ':fontsize=$fontSize'
          ':fontcolor=white'
          ':x=$textX'
          ':y=$textY'
          '$fontParam',
        );
      }
    }

    return filters.join(',');
  }

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
