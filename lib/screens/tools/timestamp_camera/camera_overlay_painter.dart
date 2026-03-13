import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../services/timestamp_camera_service.dart';
import '../../../services/location_service.dart';

/// CustomPainter that renders per-corner overlay text on the live camera preview.
/// Each corner independently draws a rounded rect with semi-transparent black bg
/// and white bold text with shadow.
class CameraOverlayPainter extends CustomPainter {
  final Map<OverlayCorner, String> cornerTexts;
  final double safeAreaTop;

  CameraOverlayPainter({
    required this.cornerTexts,
    this.safeAreaTop = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cornerTexts.isEmpty) return;

    final metrics = computeOverlayMetrics(size.width, size.height);
    final fontSize = metrics.fontSize;
    final margin = metrics.margin;
    final padding = metrics.padding;
    final maxTextWidth = size.width * 0.45;

    for (final entry in cornerTexts.entries) {
      final corner = entry.key;
      final text = entry.value;

      final isLeft = corner == OverlayCorner.topLeft || corner == OverlayCorner.bottomLeft;
      final isTop = corner == OverlayCorner.topLeft || corner == OverlayCorner.topRight;
      final textAlign = isLeft ? TextAlign.left : TextAlign.right;

      // Build paragraph
      final paragraph = _buildParagraph(text, fontSize, maxTextWidth, textAlign);
      final lineWidth = paragraph.longestLine;
      final lineHeight = paragraph.height;

      const shadowCompensation = 4.0;
      final blockWidth = (lineWidth + (padding * 2) + shadowCompensation)
          .clamp(0.0, size.width - (margin * 2));
      final blockHeight = lineHeight + (padding * 2);

      // Block X
      final double blockX = isLeft ? margin : size.width - blockWidth - margin;

      // Block Y — top corners avoid Dynamic Island / safe area
      final double blockY;
      if (isTop) {
        blockY = margin > safeAreaTop + 4.0 ? margin : safeAreaTop + 4.0;
      } else {
        blockY = size.height - blockHeight - margin;
      }

      // Rounded rect background
      final blockRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(blockX, blockY, blockWidth, blockHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        blockRect,
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );

      // Text position
      final double textX;
      if (isLeft) {
        textX = blockX + padding;
      } else {
        textX = blockX + blockWidth - padding - lineWidth;
      }
      final textY = blockY + padding;

      canvas.drawParagraph(paragraph, Offset(textX, textY));
    }
  }

  ui.Paragraph _buildParagraph(
    String text,
    double fontSize,
    double maxWidth,
    TextAlign align,
  ) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: align,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 3,
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ],
      ))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }

  @override
  bool shouldRepaint(CameraOverlayPainter oldDelegate) {
    if (oldDelegate.safeAreaTop != safeAreaTop) return true;
    if (oldDelegate.cornerTexts.length != cornerTexts.length) return true;
    for (final entry in cornerTexts.entries) {
      if (oldDelegate.cornerTexts[entry.key] != entry.value) return true;
    }
    return false;
  }
}

/// Self-contained overlay widget that owns its own 1-second clock timer.
/// Wrapped in a RepaintBoundary by the parent so timer-driven rebuilds
/// never propagate to the camera preview or controls.
class OverlayWidget extends StatefulWidget {
  final OverlaySettings settings;
  final LocationService locationService;
  final double safeAreaTop;

  const OverlayWidget({
    super.key,
    required this.settings,
    required this.locationService,
    this.safeAreaTop = 0.0,
  });

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  Timer? _clockTimer;
  Map<OverlayCorner, String> _cornerTexts = {};

  @override
  void initState() {
    super.initState();
    _updateCornerTexts();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCornerTexts();
    });
  }

  @override
  void didUpdateWidget(OverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateCornerTexts();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateCornerTexts() {
    if (!mounted) return;
    final newTexts = widget.settings.buildCornerTexts(
      coords: widget.locationService.currentCoords,
      address: widget.locationService.currentAddress,
    );
    // Skip rebuild if texts haven't changed
    if (!_mapsEqual(_cornerTexts, newTexts)) {
      setState(() => _cornerTexts = newTexts);
    }
  }

  bool _mapsEqual(Map<OverlayCorner, String> a, Map<OverlayCorner, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CameraOverlayPainter(
        cornerTexts: _cornerTexts,
        safeAreaTop: widget.safeAreaTop,
      ),
    );
  }
}
