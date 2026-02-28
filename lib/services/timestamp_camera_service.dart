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

  /// Watermark a photo with overlay text in a compact bottom-right block.
  /// Returns the watermarked PNG bytes.
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
      final fontSize = imgHeight * 0.020;
      final lineHeight = fontSize * 1.5;
      final margin = imgWidth * 0.03;
      final padding = fontSize * 0.6;

      // Build paragraphs and measure max width
      final paragraphs = <ui.Paragraph>[];
      double maxLineWidth = 0;

      for (final line in overlayLines) {
        final paragraph = _buildParagraph(line, fontSize, imgWidth * 0.6);
        paragraphs.add(paragraph);
        if (paragraph.longestLine > maxLineWidth) {
          maxLineWidth = paragraph.longestLine;
        }
      }

      final blockWidth = maxLineWidth + (padding * 2);
      final blockHeight = (overlayLines.length * lineHeight) + (padding * 2);

      // Compact rounded rect in bottom-right corner
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            imgWidth - blockWidth - margin,
            imgHeight - blockHeight - margin,
            blockWidth,
            blockHeight,
          ),
          const Radius.circular(12),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );

      // Draw each line right-aligned within the block
      for (var i = 0; i < paragraphs.length; i++) {
        final paragraph = paragraphs[i];
        final lineWidth = paragraph.longestLine;
        final x = imgWidth - margin - padding - lineWidth;
        final y =
            imgHeight - blockHeight - margin + padding + (i * lineHeight);
        canvas.drawParagraph(paragraph, Offset(x, y));
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
        textAlign: TextAlign.right,
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
  /// Text is right-aligned in the bottom-right corner.
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

      // Escape special characters for FFmpeg drawtext
      final escapedText = _escapeForFfmpegDrawtext(overlayLines[i]);

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
