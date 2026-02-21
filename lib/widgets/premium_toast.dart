import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/icon_map.dart';
import '../utils/theme.dart';

/// Toast variant types
enum ToastVariant {
  success,
  error,
  warning,
  info,
}

/// Toast position
enum ToastPosition {
  top,
  bottom,
}

/// Show a premium toast notification
void showPremiumToast({
  required BuildContext context,
  required String message,
  String? title,
  ToastVariant variant = ToastVariant.info,
  ToastPosition position = ToastPosition.bottom,
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
  VoidCallback? onTap,
  bool enableHaptics = true,
  bool showCloseButton = false,
}) {
  if (enableHaptics) {
    switch (variant) {
      case ToastVariant.success:
        HapticFeedback.lightImpact();
        break;
      case ToastVariant.error:
        HapticFeedback.heavyImpact();
        break;
      case ToastVariant.warning:
        HapticFeedback.mediumImpact();
        break;
      case ToastVariant.info:
        HapticFeedback.selectionClick();
        break;
    }
  }

  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _PremiumToast(
      message: message,
      title: title,
      variant: variant,
      position: position,
      duration: duration,
      icon: icon,
      onTap: onTap,
      showCloseButton: showCloseButton,
      onDismiss: () => overlayEntry.remove(),
    ),
  );

  overlay.insert(overlayEntry);
}

class _PremiumToast extends StatefulWidget {
  final String message;
  final String? title;
  final ToastVariant variant;
  final ToastPosition position;
  final Duration duration;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showCloseButton;
  final VoidCallback onDismiss;

  const _PremiumToast({
    required this.message,
    this.title,
    required this.variant,
    required this.position,
    required this.duration,
    this.icon,
    this.onTap,
    required this.showCloseButton,
    required this.onDismiss,
  });

  @override
  State<_PremiumToast> createState() => _PremiumToastState();
}

class _PremiumToastState extends State<_PremiumToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );

    final beginOffset = widget.position == ToastPosition.top
        ? const Offset(0, -1)
        : const Offset(0, 1);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppTheme.defaultCurve,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppTheme.defaultCurve,
      ),
    );

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (!_isDismissed && mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color get _backgroundColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.variant) {
      case ToastVariant.success:
        return isDark
            ? AppTheme.successGreen.withValues(alpha: 0.9)
            : AppTheme.successGreen;
      case ToastVariant.error:
        return isDark
            ? AppTheme.errorRed.withValues(alpha: 0.9)
            : AppTheme.errorRed;
      case ToastVariant.warning:
        return isDark
            ? AppTheme.warningOrange.withValues(alpha: 0.9)
            : AppTheme.warningOrange;
      case ToastVariant.info:
        return isDark
            ? AppTheme.darkSurfaceElevated
            : AppTheme.darkGrey;
    }
  }

  IconData get _defaultIcon {
    switch (widget.variant) {
      case ToastVariant.success:
        return AppIcons.tickCircle;
      case ToastVariant.error:
        return AppIcons.danger;
      case ToastVariant.warning:
        return AppIcons.warning;
      case ToastVariant.info:
        return AppIcons.infoCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Positioned(
      top: widget.position == ToastPosition.top ? topPadding + 16 : null,
      bottom: widget.position == ToastPosition.bottom ? bottomPadding + 16 : null,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Dismissible(
            key: UniqueKey(),
            direction: widget.position == ToastPosition.top
                ? DismissDirection.up
                : DismissDirection.down,
            onDismissed: (_) {
              _isDismissed = true;
              widget.onDismiss();
            },
            child: GestureDetector(
              onTap: () {
                widget.onTap?.call();
                _dismiss();
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon ?? _defaultIcon,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: widget.title != null ? 13 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.showCloseButton) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Icon(
                            AppIcons.close,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience methods for showing toasts
extension ToastExtension on BuildContext {
  void showSuccessToast(String message, {String? title}) {
    showPremiumToast(
      context: this,
      message: message,
      title: title,
      variant: ToastVariant.success,
    );
  }

  void showErrorToast(String message, {String? title}) {
    showPremiumToast(
      context: this,
      message: message,
      title: title,
      variant: ToastVariant.error,
    );
  }

  void showWarningToast(String message, {String? title}) {
    showPremiumToast(
      context: this,
      message: message,
      title: title,
      variant: ToastVariant.warning,
    );
  }

  void showInfoToast(String message, {String? title}) {
    showPremiumToast(
      context: this,
      message: message,
      title: title,
      variant: ToastVariant.info,
    );
  }
}
