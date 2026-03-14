import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../utils/icon_map.dart';

enum CameraMode { photo, video }

/// Bottom control bar with flash, mode toggle, shutter button, and camera flip.
class CameraControlsWidget extends StatelessWidget {
  final CameraMode mode;
  final FlashMode flashMode;
  final bool isRecording;
  final Duration recordingDuration;
  final VoidCallback onCapture;
  final VoidCallback onFlipCamera;
  final VoidCallback onCycleFlash;
  final ValueChanged<CameraMode> onModeChanged;
  final bool canFlip;

  const CameraControlsWidget({
    super.key,
    required this.mode,
    required this.flashMode,
    required this.isRecording,
    required this.recordingDuration,
    required this.onCapture,
    required this.onFlipCamera,
    required this.onCycleFlash,
    required this.onModeChanged,
    this.canFlip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.black.withValues(alpha: 0.3),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle (hidden while recording)
            if (!isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildModeToggle(context),
              ),
            // Controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Flash button
                _buildCircleButton(
                  icon: _flashIcon(),
                  onTap: isRecording ? null : onCycleFlash,
                  size: 48,
                ),
                // Shutter button
                _buildShutterButton(),
                // Flip camera button
                _buildCircleButton(
                  icon: AppIcons.rotateRight,
                  onTap: (canFlip && !isRecording) ? onFlipCamera : null,
                  size: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(context, CameraMode.photo, 'Photo', AppIcons.camera),
          const SizedBox(width: 4),
          _buildModeChip(context, CameraMode.video, 'Video', AppIcons.video),
        ],
      ),
    );
  }

  Widget _buildModeChip(
    BuildContext context,
    CameraMode chipMode,
    String label,
    IconData icon,
  ) {
    final isSelected = mode == chipMode;
    return GestureDetector(
      onTap: () => onModeChanged(chipMode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    final isVideo = mode == CameraMode.video;

    return GestureDetector(
      onTap: onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording ? Colors.red : Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isVideo ? Colors.red : Colors.white,
            shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isRecording ? BorderRadius.circular(8) : null,
          ),
          margin: isRecording ? const EdgeInsets.all(10) : EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: onTap != null ? 0.2 : 0.08),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? Colors.white
              : Colors.white.withValues(alpha: 0.3),
          size: size * 0.5,
        ),
      ),
    );
  }

  IconData _flashIcon() {
    switch (flashMode) {
      case FlashMode.auto:
        return AppIcons.flash;
      case FlashMode.always:
        return AppIcons.flashBold;
      case FlashMode.off:
        return AppIcons.flashSlash;
      case FlashMode.torch:
        return AppIcons.flashBold;
    }
  }
}
