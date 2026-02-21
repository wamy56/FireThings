import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable flutter_animate extensions to avoid repeating animation config.
extension AnimateEntrance on Widget {
  /// Standard entrance animation — fadeIn + slideY upward.
  /// [delay] offsets the start for staggered section animations.
  Widget animateEntrance({
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return animate(delay: delay).fadeIn(duration: duration, curve: curve).slideY(
          begin: 0.15,
          end: 0,
          duration: duration,
          curve: curve,
        );
  }

  /// Staggered list-item entrance — each [index] delays 60ms after the previous.
  Widget animateListItem(int index, {Duration interval = const Duration(milliseconds: 60)}) {
    return animateEntrance(delay: interval * index);
  }
}
