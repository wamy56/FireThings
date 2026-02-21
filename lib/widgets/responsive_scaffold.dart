import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../utils/theme.dart';

/// A scaffold wrapper that constrains content width on wide screens.
///
/// Centers content horizontally with [Breakpoints.maxContentWidth] so
/// layouts don't stretch infinitely on tablet/desktop.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.backgroundColor,
  });

  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A drop-in replacement for [ListView] that auto-constrains width
/// and applies responsive padding.
///
/// Screens can swap `ListView(padding: ..., children: [...])` to
/// `ResponsiveListView(children: [...])` with a one-line change.
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding,
    this.physics,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;

  /// Override the default responsive padding if needed.
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final screenSize = context.screenSize;
    final effectivePadding = padding ??
        EdgeInsets.all(AppTheme.responsiveScreenPadding(screenSize));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: effectivePadding,
          physics: physics,
          controller: controller,
          children: children,
        ),
      ),
    );
  }
}
