import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

    // Line 1: Date + Time
    final datePart = showDate ? DateFormat('dd/MM/yyyy').format(now) : '';
    final timePart = showTime ? DateFormat('HH:mm:ss').format(now) : '';
    final dateTimeLine = '$datePart  $timePart'.trim();
    if (dateTimeLine.isNotEmpty) lines.add(dateTimeLine);

    // Line 2: GPS coordinates
    if (showCoords && coords != null && coords.isNotEmpty) {
      lines.add(coords);
    }

    // Line 3: Address
    if (showAddress && address != null && address.isNotEmpty) {
      lines.add(address);
    }

    // Line 4: Custom note
    if (showNote && customNote.isNotEmpty) {
      lines.add(customNote);
    }

    return lines;
  }
}

/// Service for persisting overlay settings and watermarking photos.
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

  /// Watermark a photo with overlay text. Returns the watermarked PNG bytes.
  Future<Uint8List> watermarkPhoto(
    Uint8List imageBytes,
    List<String> overlayLines,
  ) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imgWidth = image.width.toDouble();
    final imgHeight = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw original image
    canvas.drawImage(image, Offset.zero, Paint());

    if (overlayLines.isNotEmpty) {
      final fontSize = imgHeight * 0.022;
      final lineHeight = fontSize * 1.5;
      final padding = imgWidth * 0.02;
      final barHeight = (overlayLines.length * lineHeight) + (padding * 2);

      // Semi-transparent bar at bottom
      canvas.drawRect(
        Rect.fromLTWH(0, imgHeight - barHeight, imgWidth, barHeight),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );

      // Draw each line
      for (var i = 0; i < overlayLines.length; i++) {
        final y = imgHeight - barHeight + padding + (i * lineHeight);
        final paragraph = _buildParagraph(
          overlayLines[i],
          fontSize,
          imgWidth - (padding * 2),
        );
        canvas.drawParagraph(paragraph, Offset(padding, y));
      }
    }

    final picture = recorder.endRecording();
    final outputImage = await picture.toImage(image.width, image.height);
    final byteData = await outputImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    outputImage.dispose();

    return byteData!.buffer.asUint8List();
  }

  ui.Paragraph _buildParagraph(String text, double fontSize, double maxWidth) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }

  /// Build FFmpeg drawtext filter string for video overlay burn-in.
  String buildFfmpegDrawtextFilter(List<String> overlayLines, int videoHeight) {
    if (overlayLines.isEmpty) return '';

    final fontSize = videoHeight ~/ 30;
    final filters = <String>[];
    final lineCount = overlayLines.length;
    final bottomPadding = 20;
    final lineSpacing = (fontSize * 1.5).toInt();

    for (var i = 0; i < lineCount; i++) {
      // Position from bottom, last line closest to bottom edge
      final yOffset = videoHeight -
          bottomPadding -
          ((lineCount - i) * lineSpacing);

      // Escape special characters for FFmpeg
      final escapedText = overlayLines[i]
          .replaceAll(':', r'\:')
          .replaceAll("'", r"\'");

      filters.add(
        "drawtext=text='$escapedText'"
        ':fontsize=$fontSize'
        ':fontcolor=white'
        ':x=20'
        ':y=$yOffset'
        ':box=1'
        ':boxcolor=black@0.6'
        ':boxborderw=8',
      );
    }

    return filters.join(',');
  }
}
