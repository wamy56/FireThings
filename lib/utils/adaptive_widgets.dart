import 'dart:ui';
import 'platform_io.dart' if (dart.library.html) 'platform_web.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Platform detection utilities
class PlatformUtils {
  PlatformUtils._();

  /// Returns true if running on iOS or macOS
  static bool get isApple {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  /// Returns true if running on Android
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Returns true if running on desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Returns true if running on web
  static bool get isWeb => kIsWeb;

  /// Returns true if running on mobile (iOS or Android)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }
}

/// Adaptive widget that renders differently based on platform
class AdaptiveWidget extends StatelessWidget {
  final Widget Function(BuildContext context) iosBuilder;
  final Widget Function(BuildContext context) androidBuilder;
  final Widget Function(BuildContext context)? webBuilder;
  final Widget Function(BuildContext context)? desktopBuilder;

  const AdaptiveWidget({
    super.key,
    required this.iosBuilder,
    required this.androidBuilder,
    this.webBuilder,
    this.desktopBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isWeb && webBuilder != null) {
      return webBuilder!(context);
    }
    if (PlatformUtils.isDesktop && desktopBuilder != null) {
      return desktopBuilder!(context);
    }
    if (PlatformUtils.isApple) {
      return iosBuilder(context);
    }
    return androidBuilder(context);
  }
}

/// Glassmorphism container with blur effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.color,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.7));
    final effectiveRadius = borderRadius ?? AppTheme.cardRadius;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(effectiveRadius),
              border: border ??
                  Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Adaptive refresh indicator - uses Cupertino style on iOS
class AdaptiveRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const AdaptiveRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApple) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ScrollConfiguration(
          behavior: const CupertinoScrollBehavior(),
          child: child,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Adaptive activity indicator
class AdaptiveLoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;

  const AdaptiveLoadingIndicator({
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);

    if (PlatformUtils.isApple) {
      return CupertinoActivityIndicator(
        radius: size != null ? size! / 2 : 10,
        color: effectiveColor,
      );
    }

    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
      ),
    );
  }
}

/// Adaptive switch
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = activeColor ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);

    if (PlatformUtils.isApple) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: effectiveColor,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: effectiveColor,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return effectiveColor;
        }
        return null;
      }),
    );
  }
}

/// Adaptive slider
class AdaptiveSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final Color? activeColor;

  const AdaptiveSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = activeColor ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);

    if (PlatformUtils.isApple) {
      return CupertinoSlider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        activeColor: effectiveColor,
        thumbColor: effectiveColor,
      );
    }

    return Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      activeColor: effectiveColor,
    );
  }
}

/// Helper extension for adaptive padding based on platform
extension AdaptivePaddingExtension on EdgeInsets {
  /// Returns slightly larger padding on iOS for a more spacious feel
  EdgeInsets get adaptive {
    if (PlatformUtils.isApple) {
      return this * 1.1;
    }
    return this;
  }
}

/// Helper to get the safe area padding
extension SafeAreaExtension on BuildContext {
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;
  double get bottomSafeArea => MediaQuery.of(this).padding.bottom;
  double get topSafeArea => MediaQuery.of(this).padding.top;
}

/// Adaptive date picker that uses Material dialog on Android and a
/// Cupertino-styled bottom sheet with a calendar grid on Apple platforms.
Future<DateTime?> showAdaptiveDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  if (!PlatformUtils.isApple) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  DateTime selectedDate = initialDate;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      final surfaceColor =
          isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceWhite;

      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Date',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(ctx).pop(selectedDate),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkPrimaryBlue
                                  : AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Calendar grid
                  CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    onDateChanged: (date) {
                      setModalState(() => selectedDate = date);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Adaptive page route — CupertinoPageRoute on Apple, MaterialPageRoute elsewhere.
PageRoute<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (PlatformUtils.isApple) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}
