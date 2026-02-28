import 'package:flutter/material.dart';

/// iOS-style horizontal lens selector with 0.5x / 1x / 2x pill buttons.
class LensSelectorWidget extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  const LensSelectorWidget({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stops = <_LensStop>[];

    if (minZoom <= 0.6) {
      stops.add(_LensStop(label: '.5', zoom: 0.5));
    }
    stops.add(_LensStop(label: '1x', zoom: 1.0));
    if (maxZoom >= 2.0) {
      stops.add(_LensStop(label: '2x', zoom: 2.0));
    }

    if (stops.length < 2) return const SizedBox.shrink();

    // Find closest stop
    int activeIndex = 0;
    double minDist = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final dist = (stops[i].zoom - currentZoom).abs();
      if (dist < minDist && dist <= 0.25) {
        minDist = dist;
        activeIndex = i;
      }
    }
    // If no stop is within 0.25, no pill is active
    final hasActive = minDist <= 0.25;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stops.asMap().entries.map((entry) {
        final i = entry.key;
        final stop = entry.value;
        final isActive = hasActive && i == activeIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => onZoomChanged(stop.zoom.clamp(minZoom, maxZoom)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 36 : 32,
              height: isActive ? 36 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFFFFCC00)
                    : Colors.black.withValues(alpha: 0.5),
              ),
              alignment: Alignment.center,
              child: Text(
                stop.label,
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white,
                  fontSize: isActive ? 13 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LensStop {
  final String label;
  final double zoom;

  const _LensStop({required this.label, required this.zoom});
}
