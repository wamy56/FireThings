import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// CustomPainter that renders overlay text on top of the live camera preview.
/// Draws a semi-transparent black bar at the bottom with white bold text
/// for each enabled overlay element.
class CameraOverlayPainter extends CustomPainter {
  final List<String> overlayLines;

  CameraOverlayPainter({required this.overlayLines});

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayLines.isEmpty) return;

    final fontSize = size.height * 0.028;
    final lineHeight = fontSize * 1.5;
    final horizontalPadding = size.width * 0.03;
    final verticalPadding = fontSize * 0.8;
    final barHeight = (overlayLines.length * lineHeight) + (verticalPadding * 2);

    // Semi-transparent bar at bottom
    final barRect = Rect.fromLTWH(
      0,
      size.height - barHeight,
      size.width,
      barHeight,
    );
    canvas.drawRect(
      barRect,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Draw each text line
    for (var i = 0; i < overlayLines.length; i++) {
      final y = size.height - barHeight + verticalPadding + (i * lineHeight);
      final paragraph = _buildParagraph(
        overlayLines[i],
        fontSize,
        size.width - (horizontalPadding * 2),
      );
      canvas.drawParagraph(paragraph, Offset(horizontalPadding, y));
    }
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
    if (oldDelegate.overlayLines.length != overlayLines.length) return true;
    for (var i = 0; i < overlayLines.length; i++) {
      if (oldDelegate.overlayLines[i] != overlayLines[i]) return true;
    }
    return false;
  }
}
