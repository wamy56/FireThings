import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Transparent gesture layer that handles pinch-to-zoom.
/// Writes zoom changes to a [ValueNotifier] so only
/// [ValueListenableBuilder] consumers rebuild — never the parent.
class ZoomGestureLayer extends StatefulWidget {
  final CameraController controller;
  final ValueNotifier<double> zoomNotifier;
  final double minZoom;
  final double maxZoom;

  /// Optional tap callback for tap-to-focus passthrough.
  final void Function(Offset localPosition, BoxConstraints constraints)?
      onTapDown;

  const ZoomGestureLayer({
    super.key,
    required this.controller,
    required this.zoomNotifier,
    required this.minZoom,
    required this.maxZoom,
    this.onTapDown,
  });

  @override
  State<ZoomGestureLayer> createState() => _ZoomGestureLayerState();
}

class _ZoomGestureLayerState extends State<ZoomGestureLayer> {
  double _baseZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: widget.onTapDown != null
              ? (details) =>
                  widget.onTapDown!(details.localPosition, constraints)
              : null,
          onScaleStart: (_) {
            _baseZoom = widget.zoomNotifier.value;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount < 2) return;
            final newZoom =
                (_baseZoom * details.scale).clamp(widget.minZoom, widget.maxZoom);
            widget.zoomNotifier.value = newZoom;
            try {
              widget.controller.setZoomLevel(newZoom);
            } catch (_) {}
          },
        );
      },
    );
  }
}
