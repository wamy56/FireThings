import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../screens/tools/timestamp_camera/camera_overlay_painter.dart';

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

  /// Watermark a photo with overlay text using the same CameraOverlayPainter
  /// as the live preview, then compositing onto the photo in an isolate.
  /// Returns JPEG bytes.
  Future<Uint8List> watermarkPhoto(
    Uint8List imageBytes,
    List<String> overlayLines, {
    OverlayPosition position = OverlayPosition.bottomLeft,
  }) async {
    if (overlayLines.isEmpty) return imageBytes;

    // Decode image dimensions on isolate first
    final dimensions = await Isolate.run(() {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;
      return [image.width, image.height];
    });
    if (dimensions == null) return imageBytes;

    final imgWidth = dimensions[0].toDouble();
    final imgHeight = dimensions[1].toDouble();

    // Render overlay using dart:ui Canvas (same painter as live preview)
    final overlayBytes = await _renderOverlayImage(
      overlayLines,
      position,
      imgWidth,
      imgHeight,
    );

    // Composite overlay onto photo in isolate
    final posIndex = position.index;
    return Isolate.run(() {
      return _compositeInIsolate(imageBytes, overlayBytes, posIndex);
    });
  }

  /// Render the overlay as a PNG image using CameraOverlayPainter (dart:ui).
  /// This runs on the main thread but is very fast (just text + a rounded rect).
  Future<Uint8List> _renderOverlayImage(
    List<String> overlayLines,
    OverlayPosition position,
    double width,
    double height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width, height);

    final painter = CameraOverlayPainter(
      overlayLines: overlayLines,
      position: position,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Composite a PNG overlay onto a photo in an isolate.
  static Uint8List _compositeInIsolate(
    Uint8List photoBytes,
    Uint8List overlayPngBytes,
    int positionIndex,
  ) {
    final photo = img.decodeImage(photoBytes);
    if (photo == null) return photoBytes;

    final overlay = img.decodePng(overlayPngBytes);
    if (overlay == null) return photoBytes;

    img.compositeImage(photo, overlay);

    return Uint8List.fromList(img.encodeJpg(photo, quality: 92));
  }

  // ─── FFmpeg Video Overlay ─────────────────────────────────────────

  /// Font size proportional to video height (~2.4% to match live preview).
  static String _ffmpegFontSizeExpr() => '(h*0.024)';

  /// Margin expression: 3% of width (matching live preview).
  static String _ffmpegMarginExpr() => '(w*0.03)';

  /// Padding expression: 60% of font size (matching live preview).
  static String _ffmpegPaddingExpr() => '(h*0.024*0.6)';

  /// Line gap expression: 40% of font size.
  static String _ffmpegLineGapExpr() => '(h*0.024*0.4)';

  /// Return the FFmpeg `x` expression for text within the block.
  static String _ffmpegTextX(OverlayPosition position) {
    final margin = _ffmpegMarginExpr();
    final padding = _ffmpegPaddingExpr();
    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    if (isLeft) {
      return '$margin+$padding';
    } else {
      return 'w-tw-$margin-$padding';
    }
  }

  /// Return the FFmpeg `y` expression for a text line at [lineIndex].
  static String _ffmpegTextY({
    required OverlayPosition position,
    required int lineIndex,
    required int totalLines,
  }) {
    final padding = _ffmpegPaddingExpr();
    final fontSize = _ffmpegFontSizeExpr();
    final lineGap = _ffmpegLineGapExpr();
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    // Offset from block top edge to this line
    final lineOffset = lineIndex == 0
        ? padding
        : '$padding+$lineIndex*($fontSize+$lineGap)';

    if (isTop) {
      // Safe top margin ~12% of height
      return '(h*0.12)+$lineOffset';
    } else {
      // Block total height = padding*2 + totalLines*fontSize + (totalLines-1)*lineGap
      final blockH = totalLines == 1
          ? '$padding*2+$fontSize'
          : '$padding*2+$totalLines*$fontSize+${totalLines - 1}*$lineGap';
      // Safe bottom margin ~20% of height
      return 'h-($blockH)-(h*0.20)+$lineOffset';
    }
  }

  /// Build a drawbox filter for the grouped background rect.
  static String _ffmpegDrawBox({
    required OverlayPosition position,
    required int totalLines,
    required int maxTextChars,
  }) {
    final margin = _ffmpegMarginExpr();
    final padding = _ffmpegPaddingExpr();
    final fontSize = _ffmpegFontSizeExpr();
    final lineGap = _ffmpegLineGapExpr();
    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    // Block dimensions — width is estimated from max char count * average char width
    // Average char width ≈ 0.55 * fontSize for bold Inter
    final blockW = '$padding*2+$maxTextChars*$fontSize*0.55+4';
    final blockH = totalLines == 1
        ? '$padding*2+$fontSize'
        : '$padding*2+$totalLines*$fontSize+${totalLines - 1}*$lineGap';

    final x = isLeft ? margin : 'w-($blockW)-$margin';
    final y = isTop ? '(h*0.12)' : 'h-($blockH)-(h*0.20)';

    return "drawbox=x='$x':y='$y':w='$blockW':h='$blockH'"
        ":color=black@0.55:t=fill";
  }

  /// Build a dynamic FFmpeg drawtext filter where the date/time line updates
  /// per-frame using `%{pts\:localtime\:EPOCH}`.
  ///
  /// Static lines (coords, address, note) remain constant.
  /// Uses a single drawbox for the grouped background, matching the live
  /// preview's rounded-rect block style (without rounded corners in FFmpeg).
  String buildDynamicFfmpegFilter({
    required OverlaySettings settings,
    required DateTime recordingStartTime,
    required int durationMs,
    String? coords,
    String? address,
    String? fontPath,
  }) {
    final fontSizeExpr = _ffmpegFontSizeExpr();
    final filters = <String>[];

    // Collect all lines — date/time is dynamic, rest are static
    final staticLines = <String>[];
    bool hasDateTime = false;
    int maxChars = 0;

    // Date/time line (dynamic)
    if (settings.showDate || settings.showTime) {
      hasDateTime = true;
      // Estimate max char count for date/time: "dd/MM/yyyy  HH:mm:ss" = 20
      int dtChars = 0;
      if (settings.showDate) dtChars += 10;
      if (settings.showDate && settings.showTime) dtChars += 2;
      if (settings.showTime) dtChars += 8;
      if (dtChars > maxChars) maxChars = dtChars;
    }

    // Static lines
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

    // Single grouped background box
    filters.add(_ffmpegDrawBox(
      position: settings.position,
      totalLines: totalLines,
      maxTextChars: maxChars,
    ));

    int lineIndex = 0;
    final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';

    // Dynamic date/time line using pts:localtime expansion
    if (hasDateTime) {
      final epoch = recordingStartTime.millisecondsSinceEpoch ~/ 1000;

      String format = '';
      if (settings.showDate) format += '%d/%m/%Y';
      if (settings.showDate && settings.showTime) format += '  ';
      if (settings.showTime) format += '%H\\:%M\\:%S';

      final xExpr = _ffmpegTextX(settings.position);
      final yExpr = _ffmpegTextY(
        position: settings.position,
        lineIndex: lineIndex,
        totalLines: totalLines,
      );

      filters.add(
        "drawtext=text='%{pts\\:localtime\\:$epoch\\:$format}'"
        ":fontsize='$fontSizeExpr'"
        ':fontcolor=white'
        ":x='$xExpr'"
        ":y='$yExpr'"
        '$fontParam',
      );
      lineIndex++;
    }

    // Static lines
    for (final line in staticLines) {
      final xExpr = _ffmpegTextX(settings.position);
      final yExpr = _ffmpegTextY(
        position: settings.position,
        lineIndex: lineIndex,
        totalLines: totalLines,
      );
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ":fontsize='$fontSizeExpr'"
        ':fontcolor=white'
        ":x='$xExpr'"
        ":y='$yExpr'"
        '$fontParam',
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
    final fontSizeExpr = _ffmpegFontSizeExpr();
    final filters = <String>[];
    final totalSeconds = (durationMs / 1000).ceil() + 1;

    // Static lines (coords, address, note)
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

    // Single grouped background box
    filters.add(_ffmpegDrawBox(
      position: settings.position,
      totalLines: totalLines,
      maxTextChars: maxChars,
    ));

    final fontParam = fontPath != null ? ":fontfile='$fontPath'" : '';

    // Generate per-second drawtext for the dynamic date/time line
    if (hasDateTime) {
      final xExpr = _ffmpegTextX(settings.position);
      final yExpr = _ffmpegTextY(
        position: settings.position,
        lineIndex: 0,
        totalLines: totalLines,
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
          ":fontsize='$fontSizeExpr'"
          ':fontcolor=white'
          ":x='$xExpr'"
          ":y='$yExpr'"
          '$fontParam'
          ":enable='between(t,$s,${s + 1})'",
        );
      }
    }

    // Static lines (always visible)
    int lineIndex = hasDateTime ? 1 : 0;
    for (final line in staticLines) {
      final xExpr = _ffmpegTextX(settings.position);
      final yExpr = _ffmpegTextY(
        position: settings.position,
        lineIndex: lineIndex,
        totalLines: totalLines,
      );
      final escapedText = _escapeForFfmpegDrawtext(line);

      filters.add(
        "drawtext=text='$escapedText'"
        ":fontsize='$fontSizeExpr'"
        ':fontcolor=white'
        ":x='$xExpr'"
        ":y='$yExpr'"
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
