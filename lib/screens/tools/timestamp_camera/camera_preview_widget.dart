import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Isolated camera preview widget wrapped in [RepaintBoundary] by the parent.
/// Receives the controller — never rebuilds from timer or zoom changes.
/// Center/AspectRatio wrapping is handled by the parent screen.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return CameraPreview(controller);
  }
}
