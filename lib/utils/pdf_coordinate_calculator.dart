import 'dart:ui' show Offset;

/// Utility class for converting between PDF coordinate systems.
///
/// PDF coordinates use points (1/72 inch) with origin at top-left.
/// This class provides conversion between percentage-based coordinates
/// (0-100 representing % of page dimensions) and absolute PDF points.
class PdfCoordinateCalculator {
  /// Convert percentage (0-100) to PDF points.
  ///
  /// Use this when placing fields on a PDF page.
  /// - [xPercent]: Horizontal position as percentage of page width (0 = left edge, 100 = right edge)
  /// - [yPercent]: Vertical position as percentage of page height (0 = top edge, 100 = bottom edge)
  /// - [pageWidth]: Page width in PDF points (A4 = 595.28)
  /// - [pageHeight]: Page height in PDF points (A4 = 841.89)
  static Offset percentToPoints({
    required double xPercent,
    required double yPercent,
    required double pageWidth,
    required double pageHeight,
  }) {
    return Offset(
      (xPercent / 100) * pageWidth,
      (yPercent / 100) * pageHeight,
    );
  }

  /// Convert PDF points to percentage (for calibration tool).
  ///
  /// Use this when measuring positions from a PDF to create field definitions.
  /// - [x]: Horizontal position in PDF points
  /// - [y]: Vertical position in PDF points
  /// - [pageWidth]: Page width in PDF points
  /// - [pageHeight]: Page height in PDF points
  static Offset pointsToPercent({
    required double x,
    required double y,
    required double pageWidth,
    required double pageHeight,
  }) {
    return Offset(
      (x / pageWidth) * 100,
      (y / pageHeight) * 100,
    );
  }

  /// Convert percentage dimensions to PDF points.
  ///
  /// Use this for field width and height calculations.
  static Offset percentDimensionsToPoints({
    required double widthPercent,
    required double heightPercent,
    required double pageWidth,
    required double pageHeight,
  }) {
    return Offset(
      (widthPercent / 100) * pageWidth,
      (heightPercent / 100) * pageHeight,
    );
  }

  /// Standard A4 page dimensions in PDF points.
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;

  /// Convert percentage to A4 points (convenience method).
  static Offset percentToA4Points({
    required double xPercent,
    required double yPercent,
  }) {
    return percentToPoints(
      xPercent: xPercent,
      yPercent: yPercent,
      pageWidth: a4Width,
      pageHeight: a4Height,
    );
  }

  /// Convert A4 points to percentage (convenience method).
  static Offset a4PointsToPercent({
    required double x,
    required double y,
  }) {
    return pointsToPercent(
      x: x,
      y: y,
      pageWidth: a4Width,
      pageHeight: a4Height,
    );
  }
}
