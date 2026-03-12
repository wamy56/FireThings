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
    final lineGap = fontSize * 0.4;
    final margin = size.width * 0.03;
    final padding = fontSize * 0.6;

    final isLeft = position == OverlayPosition.bottomLeft ||
        position == OverlayPosition.topLeft;
    final isTop = position == OverlayPosition.topLeft ||
        position == OverlayPosition.topRight;

    final textAlign = isLeft ? TextAlign.left : TextAlign.right;
    final maxTextWidth = size.width * 0.70;

    // Build paragraphs and measure actual dimensions
    final paragraphs = <ui.Paragraph>[];
    final paragraphHeights = <double>[];
    double maxLineWidth = 0;
    double totalTextHeight = 0;

    for (var i = 0; i < overlayLines.length; i++) {
      final paragraph =
          _buildParagraph(overlayLines[i], fontSize, maxTextWidth, textAlign);
      paragraphs.add(paragraph);

      final pHeight = paragraph.height;
      paragraphHeights.add(pHeight);
      totalTextHeight += pHeight;
      if (i < overlayLines.length - 1) totalTextHeight += lineGap;

      if (paragraph.longestLine > maxLineWidth) {
        maxLineWidth = paragraph.longestLine;
      }
    }

    // Add shadow compensation (shadow offset 1 + blur 3 ≈ 4px overshoot)
    const shadowCompensation = 4.0;
    final maxBlockWidth = size.width - (margin * 2);
    final blockWidth =
        (maxLineWidth + (padding * 2) + shadowCompensation).clamp(0.0, maxBlockWidth);
    final blockHeight = totalTextHeight + (padding * 2);

    // Safe margins to avoid overlapping camera controls / status bar
    final safeBottomMargin = size.height * 0.20;
    final safeTopMargin = size.height * 0.12;

    // Compute block X, clamped so block never extends past edges
    final rawBlockX = isLeft ? margin : size.width - blockWidth - margin;
    final clampMax = (size.width - blockWidth - margin).clamp(margin, size.width);
    final blockX = rawBlockX.clamp(margin, clampMax);

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

    // Draw each text line aligned within the block using cumulative heights
    double yOffset = blockY + padding;
    for (var i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final lineWidth = paragraph.longestLine;
      final double x;
      if (isLeft) {
        x = blockX + padding;
      } else {
        x = blockX + blockWidth - padding - lineWidth;
      }
      canvas.drawParagraph(paragraph, Offset(x, yOffset));
      yOffset += paragraphHeights[i];
      if (i < paragraphs.length - 1) yOffset += lineGap;
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
