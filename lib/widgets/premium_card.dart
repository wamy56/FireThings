import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/theme_style.dart';

/// A premium card widget with press animations, elevation changes,
/// and optional accent border
class PremiumCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? accentColor;
  final bool showAccentBorder;
  final double? borderRadius;
  final bool enableHaptics;
  final bool enabled;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.accentColor,
    this.showAccentBorder = false,
    this.borderRadius,
    this.enableHaptics = true,
    this.enabled = true,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.fastAnimation,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppTheme.defaultCurve,
      ),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppTheme.defaultCurve,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled || (widget.onTap == null && widget.onLongPress == null)) return;
    _animationController.forward();
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = widget.borderRadius ?? AppTheme.cardRadius;
    final effectiveBgColor = widget.backgroundColor ??
        (isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite);
    final effectiveAccentColor = widget.accentColor ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null && widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          child: AnimatedBuilder(
            animation: _elevationAnimation,
            builder: (context, child) {
              final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;
              return Container(
                margin: widget.margin,
                decoration: BoxDecoration(
                  color: effectiveBgColor,
                  borderRadius: BorderRadius.circular(effectiveRadius),
                  border: widget.showAccentBorder
                      ? Border(
                          left: BorderSide(
                            color: effectiveAccentColor,
                            width: 4,
                          ),
                        )
                      : isSiteOps
                          ? Border.all(color: const Color(0x14FFFFFF))
                          : null,
                  boxShadow: _buildShadow(isDark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(effectiveRadius),
                  child: child,
                ),
              );
            },
            child: AnimatedContainer(
              duration: AppTheme.fastAnimation,
              curve: AppTheme.defaultCurve,
              padding: widget.padding ?? EdgeInsets.all(AppTheme.cardPadding),
              decoration: BoxDecoration(
                color: _isHovered && widget.onTap != null && widget.enabled
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(effectiveRadius),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _buildShadow(bool isDark) {
    if (themeStyleNotifier.value == ThemeStyle.siteOps) return const [];
    if (isDark) {
      // Dark mode - subtle glow effect
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3 + (_elevationAnimation.value * 0.1)),
          blurRadius: 8 + (_elevationAnimation.value * 4),
          offset: Offset(0, 2 + (_elevationAnimation.value * 2)),
        ),
      ];
    }

    // Light mode - multi-layer shadow
    final baseAlpha = 0.04 + (_isHovered ? 0.02 : 0);
    final pressedOffset = _elevationAnimation.value * -2;

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: baseAlpha),
        blurRadius: 8 - (_elevationAnimation.value * 2),
        offset: Offset(0, 2 + pressedOffset),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.02 + (_isHovered ? 0.01 : 0)),
        blurRadius: 24 - (_elevationAnimation.value * 8),
        offset: Offset(0, 8 + (pressedOffset * 2)),
      ),
    ];
  }
}

/// A simpler card variant without animations - for static content
class SimpleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? accentColor;
  final bool showAccentBorder;
  final double? borderRadius;

  const SimpleCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.accentColor,
    this.showAccentBorder = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? AppTheme.cardRadius;
    final effectiveBgColor = backgroundColor ??
        (isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite);
    final effectiveAccentColor = accentColor ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);

    final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;
    return Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: showAccentBorder
            ? Border(
                left: BorderSide(
                  color: effectiveAccentColor,
                  width: 4,
                ),
              )
            : isSiteOps
                ? Border.all(color: const Color(0x14FFFFFF))
                : null,
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

/// Card variant specifically for list items with leading icon/avatar
class PremiumListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool showAccentBorder;

  const PremiumListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.accentColor,
    this.showAccentBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return PremiumCard(
      onTap: onTap,
      accentColor: accentColor,
      showAccentBorder: showAccentBorder,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
