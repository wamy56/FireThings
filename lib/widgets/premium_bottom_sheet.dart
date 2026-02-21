import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/icon_map.dart';
import '../utils/theme.dart';

/// Snap point for the bottom sheet
enum SheetSnapPoint {
  /// Sheet takes minimum space
  collapsed,
  /// Sheet takes about half the screen
  partial,
  /// Sheet takes full available space
  expanded,
}

/// Show a premium bottom sheet with snap points and drag handle
Future<T?> showPremiumBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController scrollController)
      builder,
  SheetSnapPoint initialSnapPoint = SheetSnapPoint.partial,
  bool enableBlur = true,
  bool showDragHandle = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  double? borderRadius,
  bool enableHaptics = true,
}) {
  if (enableHaptics) {
    HapticFeedback.mediumImpact();
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => PremiumBottomSheet(
      builder: builder,
      initialSnapPoint: initialSnapPoint,
      enableBlur: enableBlur,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
    ),
  );
}

/// Premium bottom sheet widget with snap points
class PremiumBottomSheet extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController scrollController)
      builder;
  final SheetSnapPoint initialSnapPoint;
  final bool enableBlur;
  final bool showDragHandle;
  final Color? backgroundColor;
  final double? borderRadius;

  const PremiumBottomSheet({
    super.key,
    required this.builder,
    this.initialSnapPoint = SheetSnapPoint.partial,
    this.enableBlur = true,
    this.showDragHandle = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<PremiumBottomSheet> createState() => _PremiumBottomSheetState();
}

class _PremiumBottomSheetState extends State<PremiumBottomSheet> {
  late DraggableScrollableController _controller;
  late ScrollController _scrollController;

  double get _collapsedSize => 0.3;
  double get _partialSize => 0.5;
  double get _expandedSize => 0.9;

  double get _initialSize {
    switch (widget.initialSnapPoint) {
      case SheetSnapPoint.collapsed:
        return _collapsedSize;
      case SheetSnapPoint.partial:
        return _partialSize;
      case SheetSnapPoint.expanded:
        return _expandedSize;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = widget.borderRadius ?? 20.0;
    final effectiveBgColor = widget.backgroundColor ??
        (isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite);

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: _initialSize,
      minChildSize: _collapsedSize,
      maxChildSize: _expandedSize,
      snap: true,
      snapSizes: [_collapsedSize, _partialSize, _expandedSize],
      builder: (context, scrollController) {
        Widget content = Container(
          decoration: BoxDecoration(
            color: widget.enableBlur
                ? effectiveBgColor.withValues(alpha: 0.9)
                : effectiveBgColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(effectiveRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (widget.showDragHandle) _buildDragHandle(isDark),
              Expanded(
                child: widget.builder(context, scrollController),
              ),
            ],
          ),
        );

        if (widget.enableBlur) {
          content = ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(effectiveRadius),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return GestureDetector(
      onTap: () {
        // Toggle between partial and expanded
        final currentSize = _controller.size;
        if (currentSize < _partialSize + 0.1) {
          _controller.animateTo(
            _expandedSize,
            duration: AppTheme.normalAnimation,
            curve: AppTheme.defaultCurve,
          );
        } else {
          _controller.animateTo(
            _partialSize,
            duration: AppTheme.normalAnimation,
            curve: AppTheme.defaultCurve,
          );
        }
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkDivider
                  : AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple bottom sheet without snap points
class SimpleBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showDragHandle;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const SimpleBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.showCloseButton = false,
    this.onClose,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBgColor = backgroundColor ??
        (isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkDivider : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (title != null || showCloseButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  if (showCloseButton)
                    IconButton(
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      icon: Icon(
                        AppIcons.close,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: Padding(
              padding: padding ??
                  EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPadding),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to show a simple bottom sheet
Future<T?> showSimpleBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  bool showDragHandle = true,
  bool showCloseButton = false,
  bool isDismissible = true,
  bool enableDrag = true,
  EdgeInsetsGeometry? padding,
  bool enableHaptics = true,
}) {
  if (enableHaptics) {
    HapticFeedback.mediumImpact();
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => SimpleBottomSheet(
      title: title,
      showDragHandle: showDragHandle,
      showCloseButton: showCloseButton,
      padding: padding,
      child: child,
    ),
  );
}
