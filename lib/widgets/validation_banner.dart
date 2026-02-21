import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';

/// A slim animated banner that slides down to show validation errors.
/// Includes a shake animation on appearance for emphasis.
/// Can auto-dismiss when [onDismiss] is called or after a timeout.
class ValidationBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;
  final Duration? autoDismissAfter;

  const ValidationBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.autoDismissAfter,
  });

  @override
  State<ValidationBanner> createState() => ValidationBannerState();
}

class ValidationBannerState extends State<ValidationBanner>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shakeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppTheme.defaultCurve,
    ));

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOut,
    ));

    HapticFeedback.mediumImpact();
    _slideController.forward().then((_) {
      if (mounted) _shakeController.forward();
    });

    if (widget.autoDismissAfter != null) {
      Future.delayed(widget.autoDismissAfter!, dismiss);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _slideController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.errorRed.withValues(alpha: 0.15)
                : AppTheme.errorRed.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.errorRed.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.danger,
                color: AppTheme.errorRed,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: dismiss,
                child: Icon(
                  AppIcons.close,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppTheme.errorRed.withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper to show a validation banner as an overlay.
/// Returns a dismiss callback so you can programmatically dismiss it.
VoidCallback showValidationBanner({
  required BuildContext context,
  required String message,
  Duration? autoDismissAfter = const Duration(seconds: 5),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  final bannerKey = GlobalKey<ValidationBannerState>();

  entry = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;
      return Positioned(
        top: topPadding,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: ValidationBanner(
            key: bannerKey,
            message: message,
            autoDismissAfter: autoDismissAfter,
            onDismiss: () => entry.remove(),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  return () => bannerKey.currentState?.dismiss();
}
