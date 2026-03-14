import 'package:flutter/material.dart';

/// iOS-style yellow focus square that appears on tap-to-focus,
/// scales in, holds, then fades out.
class FocusIndicator extends StatefulWidget {
  final Offset position;
  final VoidCallback onAnimationComplete;

  const FocusIndicator({
    super.key,
    required this.position,
    required this.onAnimationComplete,
  });

  @override
  State<FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<FocusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 35,
      top: widget.position.dy - 35,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;

          // 0–15%: scale 1.3 → 1.0
          // 15–70%: hold at 1.0
          // 70–100%: fade 1.0 → 0.0
          double scale;
          double opacity;

          if (t < 0.15) {
            final scaleT = t / 0.15;
            scale = 1.3 - (0.3 * scaleT);
            opacity = 1.0;
          } else if (t < 0.70) {
            scale = 1.0;
            opacity = 1.0;
          } else {
            scale = 1.0;
            final fadeT = (t - 0.70) / 0.30;
            opacity = 1.0 - fadeT;
          }

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFFFCC00),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// [AnimatedBuilder] is identical to [AnimatedWidget] but uses a builder.
/// Flutter's built-in is [AnimatedBuilder] — just verifying the name.
