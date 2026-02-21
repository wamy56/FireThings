import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/adaptive_widgets.dart';

/// Adaptive app bar that uses iOS-style large titles on Apple platforms
/// and Material SliverAppBar on Android
class AdaptiveAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final Color? backgroundColor;
  final bool pinned;
  final bool floating;
  final bool snap;
  final double expandedHeight;
  final bool useBlurEffect;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.backgroundColor,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.expandedHeight = 120.0,
    this.useBlurEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApple) {
      return _buildCupertinoAppBar(context);
    }
    return _buildMaterialAppBar(context);
  }

  Widget _buildCupertinoAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _CupertinoLargeTitleDelegate(
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        expandedHeight: expandedHeight,
        useBlurEffect: useBlurEffect,
        isDark: isDark,
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget _buildMaterialAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      elevation: elevation ?? 0,
      backgroundColor: backgroundColor ??
          (isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey),
      pinned: pinned,
      floating: floating,
      snap: snap,
      expandedHeight: expandedHeight,
      collapsedHeight: kToolbarHeight,
      flexibleSpace: flexibleSpace ?? FlexibleSpaceBar(
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        expandedTitleScale: 1.3,
      ),
    );
  }
}

class _CupertinoLargeTitleDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double expandedHeight;
  final bool useBlurEffect;
  final bool isDark;
  final Color? backgroundColor;

  _CupertinoLargeTitleDelegate({
    required this.title,
    this.actions,
    this.leading,
    required this.automaticallyImplyLeading,
    required this.expandedHeight,
    required this.useBlurEffect,
    required this.isDark,
    this.backgroundColor,
  });

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => kToolbarHeight + 44; // Standard iOS nav bar height

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final largeTitleOpacity = (1 - progress * 2).clamp(0.0, 1.0);
    final smallTitleOpacity = ((progress - 0.5) * 2).clamp(0.0, 1.0);

    final effectiveBgColor = backgroundColor ??
        (isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background with optional blur
        if (useBlurEffect)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10 * progress,
                sigmaY: 10 * progress,
              ),
              child: Container(
                color: effectiveBgColor.withValues(alpha: 0.8 + (0.2 * progress)),
              ),
            ),
          )
        else
          Container(color: effectiveBgColor),

        // Navigation bar content
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar with leading, small title, and actions
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    // Leading widget or back button
                    if (leading != null)
                      leading!
                    else if (automaticallyImplyLeading &&
                        Navigator.of(context).canPop())
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.back,
                          color: isDark
                              ? AppTheme.darkPrimaryBlue
                              : AppTheme.primaryBlue,
                        ),
                      )
                    else
                      const SizedBox(width: 16),

                    // Small title (appears when scrolled)
                    Expanded(
                      child: Opacity(
                        opacity: smallTitleOpacity,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    if (actions != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
                      )
                    else
                      const SizedBox(width: 16),
                  ],
                ),
              ),

              // Large title
              Expanded(
                child: Opacity(
                  opacity: largeTitleOpacity,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        bottom: 8,
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom border
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 0.5,
            color: (isDark ? AppTheme.darkDivider : AppTheme.dividerColor)
                .withValues(alpha: progress),
          ),
        ),
      ],
    );
  }
}

/// Simple adaptive navigation bar for standard screens
class AdaptiveNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final bool useBlurEffect;

  const AdaptiveNavigationBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.useBlurEffect = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApple) {
      return _buildCupertinoNavBar(context);
    }
    return _buildMaterialAppBar(context);
  }

  Widget _buildCupertinoNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBgColor = backgroundColor ??
        (isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey);

    Widget navBar = CupertinoNavigationBar(
      middle: Text(
        title,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
      ),
      trailing: actions != null
          ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
          : null,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor:
          useBlurEffect ? effectiveBgColor.withValues(alpha: 0.8) : effectiveBgColor,
      border: Border(
        bottom: BorderSide(
          color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
          width: 0.5,
        ),
      ),
    );

    if (useBlurEffect) {
      navBar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: navBar,
        ),
      );
    }

    return navBar;
  }

  Widget _buildMaterialAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ??
          (isDark ? AppTheme.darkBackground : AppTheme.backgroundGrey),
      elevation: 0,
    );
  }
}
