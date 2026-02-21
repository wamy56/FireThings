import 'package:flutter/material.dart';

/// Screen size categories following Material 3 guidelines.
enum ScreenSize { compact, medium, expanded, large }

/// Breakpoint thresholds and layout constants.
class Breakpoints {
  Breakpoints._();

  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  /// Maximum content width for constraining layouts on wide screens.
  static const double maxContentWidth = 720;

  /// Returns the [ScreenSize] for a given pixel width.
  static ScreenSize screenSize(double width) {
    if (width < compact) return ScreenSize.compact;
    if (width < medium) return ScreenSize.medium;
    if (width < expanded) return ScreenSize.expanded;
    return ScreenSize.large;
  }
}

/// A builder widget that provides [ScreenSize] based on available width.
///
/// Supports a generic [builder] callback or named breakpoint builders
/// with a fallback chain: large -> expanded -> medium -> compact.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    this.builder,
    this.compact,
    this.medium,
    this.expanded,
    this.large,
  }) : assert(
         builder != null || compact != null,
         'Provide either builder or at least compact',
       );

  /// Generic builder that receives the current [ScreenSize].
  final Widget Function(BuildContext context, ScreenSize screenSize)? builder;

  /// Builder for compact screens (<600dp).
  final WidgetBuilder? compact;

  /// Builder for medium screens (600-840dp).
  final WidgetBuilder? medium;

  /// Builder for expanded screens (840-1200dp).
  final WidgetBuilder? expanded;

  /// Builder for large screens (>1200dp).
  final WidgetBuilder? large;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.screenSize(constraints.maxWidth);

        if (builder != null) {
          return builder!(context, size);
        }

        // Fallback chain: large -> expanded -> medium -> compact
        switch (size) {
          case ScreenSize.large:
            return (large ?? expanded ?? medium ?? compact)!(context);
          case ScreenSize.expanded:
            return (expanded ?? medium ?? compact)!(context);
          case ScreenSize.medium:
            return (medium ?? compact)!(context);
          case ScreenSize.compact:
            return compact!(context);
        }
      },
    );
  }
}

/// Convenience extensions on [BuildContext] for responsive queries.
extension ResponsiveExtension on BuildContext {
  /// The current [ScreenSize] based on media query width.
  ScreenSize get screenSize =>
      Breakpoints.screenSize(MediaQuery.sizeOf(this).width);

  /// True when the screen is compact (<600dp).
  bool get isCompact => screenSize == ScreenSize.compact;

  /// True when the screen is medium or larger (>=600dp).
  bool get isWide => screenSize != ScreenSize.compact;

  /// True when the device is in landscape orientation.
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// The current screen width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;
}
