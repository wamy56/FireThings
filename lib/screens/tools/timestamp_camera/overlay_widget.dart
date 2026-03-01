import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/location_service.dart';
import '../../../services/timestamp_camera_service.dart';
import 'camera_overlay_painter.dart';

/// Self-contained overlay widget that owns its own 1-second clock timer.
/// Wrapped in a RepaintBoundary by the parent so timer-driven rebuilds
/// never propagate to the camera preview or controls.
class OverlayWidget extends StatefulWidget {
  final OverlaySettings settings;
  final LocationService locationService;

  const OverlayWidget({
    super.key,
    required this.settings,
    required this.locationService,
  });

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  Timer? _clockTimer;
  List<String> _overlayLines = [];

  @override
  void initState() {
    super.initState();
    _updateLines();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateLines();
    });
  }

  @override
  void didUpdateWidget(OverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pick up settings changes from parent immediately
    if (!_settingsEqual(oldWidget.settings, widget.settings)) {
      _updateLines();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateLines() {
    if (!mounted) return;
    final newLines = widget.settings.buildOverlayLines(
      coords: widget.locationService.currentCoords,
      address: widget.locationService.currentAddress,
    );
    // Skip rebuild if lines haven't changed
    if (!listEquals(_overlayLines, newLines)) {
      setState(() => _overlayLines = newLines);
    }
  }

  bool _settingsEqual(OverlaySettings a, OverlaySettings b) {
    return a.showDate == b.showDate &&
        a.showTime == b.showTime &&
        a.showCoords == b.showCoords &&
        a.showAddress == b.showAddress &&
        a.showNote == b.showNote &&
        a.customNote == b.customNote &&
        a.position == b.position;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CameraOverlayPainter(
        overlayLines: _overlayLines,
        position: widget.settings.position,
      ),
    );
  }
}
