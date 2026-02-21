import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/adaptive_widgets.dart';

/// Show an adaptive alert dialog (Cupertino on iOS, Material on Android)
Future<T?> showAdaptiveAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool isDestructive = false,
  bool enableHaptics = true,
}) {
  if (enableHaptics) {
    HapticFeedback.mediumImpact();
  }

  if (PlatformUtils.isApple) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          if (cancelLabel != null)
            CupertinoDialogAction(
              onPressed: () {
                onCancel?.call();
                Navigator.of(context).pop();
              },
              child: Text(cancelLabel),
            ),
          CupertinoDialogAction(
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop(true);
            },
            isDestructiveAction: isDestructive,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (context) => _PremiumMaterialDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      onCancel: onCancel,
      isDestructive: isDestructive,
    ),
  );
}

/// Premium Material dialog with slide-up animation
class _PremiumMaterialDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const _PremiumMaterialDialog({
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  State<_PremiumMaterialDialog> createState() => _PremiumMaterialDialogState();
}

class _PremiumMaterialDialogState extends State<_PremiumMaterialDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          content: widget.message != null
              ? Text(
                  widget.message!,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                )
              : null,
          actions: [
            if (widget.cancelLabel != null)
              TextButton(
                onPressed: () {
                  widget.onCancel?.call();
                  Navigator.of(context).pop();
                },
                child: Text(
                  widget.cancelLabel!,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                widget.onConfirm?.call();
                Navigator.of(context).pop(true);
              },
              child: Text(
                widget.confirmLabel,
                style: TextStyle(
                  color: widget.isDestructive
                      ? AppTheme.errorRed
                      : (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action sheet option
class ActionSheetOption {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isDefault;

  const ActionSheetOption({
    required this.label,
    this.icon,
    this.onTap,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

/// Show an adaptive action sheet (Cupertino on iOS, Material bottom sheet on Android)
Future<T?> showAdaptiveActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<ActionSheetOption> options,
  String cancelLabel = 'Cancel',
  bool enableHaptics = true,
}) {
  if (enableHaptics) {
    HapticFeedback.mediumImpact();
  }

  if (PlatformUtils.isApple) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: options
            .map((option) => CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                    option.onTap?.call();
                  },
                  isDestructiveAction: option.isDestructive,
                  isDefaultAction: option.isDefault,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (option.icon != null) ...[
                        Icon(option.icon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(option.label),
                    ],
                  ),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _PremiumActionSheet(
      title: title,
      message: message,
      options: options,
      cancelLabel: cancelLabel,
    ),
  );
}

/// Premium Material action sheet
class _PremiumActionSheet extends StatefulWidget {
  final String? title;
  final String? message;
  final List<ActionSheetOption> options;
  final String cancelLabel;

  const _PremiumActionSheet({
    this.title,
    this.message,
    required this.options,
    required this.cancelLabel,
  });

  @override
  State<_PremiumActionSheet> createState() => _PremiumActionSheetState();
}

class _PremiumActionSheetState extends State<_PremiumActionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppTheme.defaultCurve,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: 8 + bottomPadding,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkDivider : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (widget.title != null || widget.message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                    if (widget.message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            ),
            ...widget.options.map((option) => _buildOption(option, isDark)),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            ),
            _buildCancelButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(ActionSheetOption option, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        option.onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 22,
                color: option.isDestructive
                    ? AppTheme.errorRed
                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              option.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: option.isDefault ? FontWeight.w600 : FontWeight.normal,
                color: option.isDestructive
                    ? AppTheme.errorRed
                    : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton(bool isDark) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          widget.cancelLabel,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}

/// Custom dialog with content slot
Future<T?> showPremiumDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  bool enableHaptics = true,
}) {
  if (enableHaptics) {
    HapticFeedback.mediumImpact();
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: AppTheme.normalAnimation,
    pageBuilder: (context, animation, secondaryAnimation) {
      return child;
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: AppTheme.defaultCurve,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
