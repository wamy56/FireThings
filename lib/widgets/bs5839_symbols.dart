import 'package:flutter/material.dart';

/// BS 5839 symbol types for floor plan pins.
enum BS5839Symbol {
  fireAlarmPanel, // Rectangle + "FAP"
  smokeDetector, // Circle + "S"
  heatDetector, // Circle + "H"
  callPoint, // Triangle (MCP)
  sounderBeacon, // Circle + "B"
  fireExtinguisher, // Square + "FE"
  emergencyLighting, // Circle + "EL"
  fireDoor, // Rectangle + "FD"
  aovSmokeVent, // Diamond + "AOV"
  sprinklerHead, // Circle + "SP"
  fireBlanket, // Square + "FB"
  beamDetector, // Circle + "BD"
  fireAlarmInterface, // Square + "IO"
  powerSupply, // Square + "PSU"
  refugePanel, // Rectangle + "EVC"
  refugeOutstation, // Circle + "RO"
  fireTelephone, // Circle + "FT"
  toiletAlarm, // Circle + "TA"
  other, // Circle + "?"
}

/// Maps an asset type's iconName to the corresponding BS 5839 symbol.
BS5839Symbol symbolFromIconName(String iconName) {
  switch (iconName) {
    case 'cpu':
      return BS5839Symbol.fireAlarmPanel;
    case 'radar':
      return BS5839Symbol.smokeDetector;
    case 'radar_heat':
      return BS5839Symbol.heatDetector;
    case 'danger':
      return BS5839Symbol.callPoint;
    case 'volumeHigh':
      return BS5839Symbol.sounderBeacon;
    case 'securitySafe':
      return BS5839Symbol.fireExtinguisher;
    case 'lampCharge':
      return BS5839Symbol.emergencyLighting;
    case 'door':
      return BS5839Symbol.fireDoor;
    case 'wind':
      return BS5839Symbol.aovSmokeVent;
    case 'drop':
      return BS5839Symbol.sprinklerHead;
    case 'box':
      return BS5839Symbol.fireBlanket;
    case 'radar_beam':
      return BS5839Symbol.beamDetector;
    case 'flash':
      return BS5839Symbol.fireAlarmInterface;
    case 'batteryCharging':
      return BS5839Symbol.powerSupply;
    case 'slider':
      return BS5839Symbol.refugePanel;
    case 'microphone':
      return BS5839Symbol.refugeOutstation;
    case 'call':
      return BS5839Symbol.fireTelephone;
    case 'notification':
      return BS5839Symbol.toiletAlarm;
    default:
      return BS5839Symbol.other;
  }
}

/// CustomPainter that draws BS 5839 schematic symbols.
/// Scales to any size — all proportions are relative.
class BS5839SymbolPainter extends CustomPainter {
  final BS5839Symbol symbol;
  final Color color;
  final bool isSelected;

  BS5839SymbolPainter({
    required this.symbol,
    required this.color,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? size.width * 0.08 : size.width * 0.055;

    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 4 : 2);

    switch (symbol) {
      case BS5839Symbol.fireAlarmPanel:
      case BS5839Symbol.fireDoor:
      case BS5839Symbol.refugePanel:
        _drawRectangle(canvas, size, fillPaint, borderPaint, shadowPaint);
      case BS5839Symbol.callPoint:
        _drawTriangle(canvas, size, fillPaint, borderPaint, shadowPaint);
      case BS5839Symbol.fireExtinguisher:
      case BS5839Symbol.fireBlanket:
      case BS5839Symbol.fireAlarmInterface:
      case BS5839Symbol.powerSupply:
        _drawSquare(canvas, size, fillPaint, borderPaint, shadowPaint);
      case BS5839Symbol.aovSmokeVent:
        _drawDiamond(canvas, size, fillPaint, borderPaint, shadowPaint);
      default:
        _drawCircle(canvas, size, fillPaint, borderPaint, shadowPaint);
    }

    _drawLabel(canvas, size);
  }

  void _drawCircle(Canvas canvas, Size size, Paint fill, Paint border, Paint shadow) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    canvas.drawCircle(center, radius, shadow);
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, border);
  }

  void _drawSquare(Canvas canvas, Size size, Paint fill, Paint border, Paint shadow) {
    final inset = size.width * 0.1;
    final rect = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.08));
    canvas.drawRRect(rrect, shadow);
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, border);
  }

  void _drawRectangle(Canvas canvas, Size size, Paint fill, Paint border, Paint shadow) {
    final insetX = size.width * 0.05;
    final insetY = size.height * 0.15;
    final rect = Rect.fromLTRB(insetX, insetY, size.width - insetX, size.height - insetY);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.08));
    canvas.drawRRect(rrect, shadow);
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, border);
  }

  void _drawTriangle(Canvas canvas, Size size, Paint fill, Paint border, Paint shadow) {
    final cx = size.width / 2;
    final top = size.height * 0.08;
    final bottom = size.height * 0.88;
    final halfBase = size.width * 0.42;

    final path = Path()
      ..moveTo(cx, top)
      ..lineTo(cx + halfBase, bottom)
      ..lineTo(cx - halfBase, bottom)
      ..close();

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  void _drawDiamond(Canvas canvas, Size size, Paint fill, Paint border, Paint shadow) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = size.width * 0.42;

    final path = Path()
      ..moveTo(cx, cy - half)
      ..lineTo(cx + half, cy)
      ..lineTo(cx, cy + half)
      ..lineTo(cx - half, cy)
      ..close();

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  void _drawLabel(Canvas canvas, Size size) {
    final label = _labelForSymbol(symbol);
    final fontSize = label.length <= 2
        ? size.width * 0.38
        : size.width * 0.26;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // For triangles, shift text down slightly so it's visually centred in the shape
    final yOffset = symbol == BS5839Symbol.callPoint ? size.height * 0.08 : 0.0;

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 + yOffset,
      ),
    );
  }

  static String _labelForSymbol(BS5839Symbol symbol) {
    switch (symbol) {
      case BS5839Symbol.fireAlarmPanel:
        return 'FAP';
      case BS5839Symbol.smokeDetector:
        return 'S';
      case BS5839Symbol.heatDetector:
        return 'H';
      case BS5839Symbol.callPoint:
        return 'MCP';
      case BS5839Symbol.sounderBeacon:
        return 'B';
      case BS5839Symbol.fireExtinguisher:
        return 'FE';
      case BS5839Symbol.emergencyLighting:
        return 'EL';
      case BS5839Symbol.fireDoor:
        return 'FD';
      case BS5839Symbol.aovSmokeVent:
        return 'AOV';
      case BS5839Symbol.sprinklerHead:
        return 'SP';
      case BS5839Symbol.fireBlanket:
        return 'FB';
      case BS5839Symbol.beamDetector:
        return 'BD';
      case BS5839Symbol.fireAlarmInterface:
        return 'IO';
      case BS5839Symbol.powerSupply:
        return 'PSU';
      case BS5839Symbol.refugePanel:
        return 'EVC';
      case BS5839Symbol.refugeOutstation:
        return 'RO';
      case BS5839Symbol.fireTelephone:
        return 'FT';
      case BS5839Symbol.toiletAlarm:
        return 'TA';
      case BS5839Symbol.other:
        return '?';
    }
  }

  @override
  bool shouldRepaint(BS5839SymbolPainter oldDelegate) =>
      symbol != oldDelegate.symbol ||
      color != oldDelegate.color ||
      isSelected != oldDelegate.isSelected;
}
