import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../services/timestamp_camera_service.dart';

/// CustomPainter that renders overlay text on top of the live camera preview.
/// Draws a compact rounded-rect block at the selected corner position with
/// aligned white bold text for each enabled overlay element.
class CameraOverlayPainter extends CustomPainter {
  final List<String> overlayLines;
  final OverlayPosition position;

  CameraOverlayPainter({
    required this.overlayLines,
    this.position = OverlayPosition.bottomLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayLines.isEmpty) return;

    final fontSize = size.height * 0.024;
    final lineHeight = fontSize * 1.5;
    final margin = size.width * 0.03;
    final padding = fontSize * 0.6;

    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    final textAlign = isLeft ? TextAlign.left : TextAlign.right;

    // Build paragraphs and measure max width
    final paragraphs = <ui.Paragraph>[];
    double maxLineWidth = 0;

    for (final line in overlayLines) {
      final paragraph =
          _buildParagraph(line, fontSize, size.width * 0.6, textAlign);
      paragraphs.add(paragraph);
      if (paragraph.longestLine > maxLineWidth) {
        maxLineWidth = paragraph.longestLine;
      }
    }

    final blockWidth = maxLineWidth + (padding * 2);
    final blockHeight = (overlayLines.length * lineHeight) + (padding * 2);

    // Safe margins to avoid overlapping camera controls / status bar
    // Bottom: ~22% clears lens selector (bottom: 140) + controls
    // Top: ~12% clears status bar area
    final safeBottomMargin = size.height * 0.22;
    final safeTopMargin = size.height * 0.12;

    // Compute block X
    final blockX = isLeft ? margin : size.width - blockWidth - margin;

    // Compute block Y
    final double blockY;
    if (isTop) {
      blockY = safeTopMargin;
    } else {
      blockY = size.height - blockHeight - safeBottomMargin;
    }

    // Compact rounded rect
    final blockRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(blockX, blockY, blockWidth, blockHeight),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      blockRect,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Draw each text line aligned within the block
    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final lineWidth = paragraph.longestLine;
      final double x;
      if (isLeft) {
        x = blockX + padding;
      } else {
        x = blockX + blockWidth - padding - lineWidth;
      }
      final y = blockY + padding + (i * lineHeight);
      canvas.drawParagraph(paragraph, Offset(x, y));
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
    if (oldDelegate.position != position) return true;
    if (oldDelegate.overlayLines.length != overlayLines.length) return true;
    for (var i = 0; i < overlayLines.length; i++) {
      if (oldDelegate.overlayLines[i] != overlayLines[i]) return true;
    }
    return false;
  }
}
