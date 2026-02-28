import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// CustomPainter that renders overlay text on top of the live camera preview.
/// Draws a compact rounded-rect block in the bottom-right corner with
/// right-aligned white bold text for each enabled overlay element.
class CameraOverlayPainter extends CustomPainter {
  final List<String> overlayLines;

  CameraOverlayPainter({required this.overlayLines});

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayLines.isEmpty) return;

    final fontSize = size.height * 0.024;
    final lineHeight = fontSize * 1.5;
    final margin = size.width * 0.03;
    final padding = fontSize * 0.6;

    // Build paragraphs and measure max width
    final paragraphs = <ui.Paragraph>[];
    double maxLineWidth = 0;

    for (final line in overlayLines) {
      final paragraph = _buildParagraph(line, fontSize, size.width * 0.6);
      paragraphs.add(paragraph);
      if (paragraph.longestLine > maxLineWidth) {
        maxLineWidth = paragraph.longestLine;
      }
    }

    final blockWidth = maxLineWidth + (padding * 2);
    final blockHeight = (overlayLines.length * lineHeight) + (padding * 2);

    // Compact rounded rect in bottom-right corner
    final blockRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - blockWidth - margin,
        size.height - blockHeight - margin,
        blockWidth,
        blockHeight,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      blockRect,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Draw each text line right-aligned within the block
    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final lineWidth = paragraph.longestLine;
      final x = size.width - margin - padding - lineWidth;
      final y = size.height - blockHeight - margin + padding + (i * lineHeight);
      canvas.drawParagraph(paragraph, Offset(x, y));
    }
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
