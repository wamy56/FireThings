import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/adaptive_widgets.dart';

/// Button variant styles
enum ButtonVariant {
  primary,
  secondary,
  outlined,
  ghost,
}

/// Button size options
enum ButtonSize {
  small,
  medium,
  large,
}

/// Premium custom button with animations, haptic feedback, and multiple variants
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isFullWidth;
  final bool useGradient;
  final bool isPill;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool enableHaptics;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.useGradient = false,
    this.isPill = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.enableHaptics = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.fastAnimation,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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

  double get _buttonHeight {
    switch (widget.size) {
      case ButtonSize.small:
        return 40.0;
      case ButtonSize.medium:
        return AppTheme.buttonHeight;
      case ButtonSize.large:
        return 60.0;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 14.0;
      case ButtonSize.medium:
        return 16.0;
      case ButtonSize.large:
        return 18.0;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case ButtonSize.small:
        return 18.0;
      case ButtonSize.medium:
        return 20.0;
      case ButtonSize.large:
        return 24.0;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 14);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 36, vertical: 18);
    }
  }

  double get _borderRadius {
    if (widget.isPill) {
      return _buttonHeight / 2;
    }
    return AppTheme.buttonRadius;
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = true);
    _animationController.forward();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use gradient for primary variant when useGradient is true
    if (widget.useGradient &&
        widget.variant == ButtonVariant.primary &&
        widget.backgroundColor == null) {
      return _buildGradientButton(context, isDark);
    }

    // Build variant-specific button
    return _buildVariantButton(context, isDark);
  }

  Widget _buildVariantButton(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    Color bgColor;
    Color fgColor;
    Color? borderColor;

    switch (widget.variant) {
      case ButtonVariant.primary:
        bgColor = widget.backgroundColor ??
            (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);
        fgColor = widget.foregroundColor ?? Colors.white;
        break;
      case ButtonVariant.secondary:
        bgColor = isDark
            ? AppTheme.darkSurfaceElevated
            : AppTheme.primaryLight;
        fgColor = widget.foregroundColor ??
            (isDark ? AppTheme.darkTextPrimary : AppTheme.primaryBlue);
        break;
      case ButtonVariant.outlined:
        bgColor = Colors.transparent;
        fgColor = widget.foregroundColor ??
            (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);
        borderColor = fgColor;
        break;
      case ButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = widget.foregroundColor ??
            (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);
        break;
    }

    final button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: AppTheme.fastAnimation,
          curve: AppTheme.defaultCurve,
          height: _buttonHeight,
          padding: _padding,
          decoration: BoxDecoration(
            color: widget.onPressed != null && !widget.isLoading
                ? (_isPressed ? bgColor.withValues(alpha: 0.8) : bgColor)
                : (widget.variant == ButtonVariant.ghost ||
                        widget.variant == ButtonVariant.outlined
                    ? Colors.transparent
                    : theme.disabledColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(_borderRadius),
            border: borderColor != null
                ? Border.all(
                    color: widget.onPressed != null && !widget.isLoading
                        ? borderColor
                        : theme.disabledColor,
                    width: 1.5,
                  )
                : null,
          ),
          child: _buildButtonContent(fgColor),
        ),
      ),
    );

    return widget.isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildGradientButton(BuildContext context, bool isDark) {
    final buttonContent = _buildButtonContent(Colors.white);

    final gradientButton = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: AppTheme.fastAnimation,
          curve: AppTheme.defaultCurve,
          height: _buttonHeight,
          padding: _padding,
          decoration: BoxDecoration(
            gradient: widget.onPressed != null && !widget.isLoading
                ? LinearGradient(
                    colors: _isPressed
                        ? [
                            AppTheme.primaryBlue.withValues(alpha: 0.8),
                            AppTheme.primaryDark.withValues(alpha: 0.8),
                          ]
                        : [AppTheme.primaryBlue, AppTheme.primaryDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: widget.onPressed == null || widget.isLoading
                ? Colors.grey.shade400
                : null,
            borderRadius: BorderRadius.circular(_borderRadius),
            boxShadow: widget.onPressed != null && !widget.isLoading
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: _isPressed ? 4 : 8,
                      offset: Offset(0, _isPressed ? 2 : 4),
                    ),
                  ]
                : null,
          ),
          child: buttonContent,
        ),
      ),
    );

    return widget.isFullWidth
        ? SizedBox(width: double.infinity, child: gradientButton)
        : gradientButton;
  }

  Widget _buildButtonContent(Color foregroundColor) {
    final disabledColor = Theme.of(context).disabledColor;
    final effectiveColor =
        widget.onPressed != null && !widget.isLoading
            ? foregroundColor
            : disabledColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          AdaptiveLoadingIndicator(
            size: _iconSize,
            color: effectiveColor,
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, color: effectiveColor, size: _iconSize),
          const SizedBox(width: 8),
        ],
        if (!widget.isLoading)
          Text(
            widget.text,
            style: TextStyle(
              color: effectiveColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
      ],
    );
  }
}

/// Custom outlined button (legacy compatibility - now uses CustomButton internally)
class CustomOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;
  final Color? foregroundColor;
  final bool isFullWidth;
  final bool isPill;
  final ButtonSize size;

  const CustomOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.borderColor,
    this.foregroundColor,
    this.isFullWidth = false,
    this.isPill = false,
    this.size = ButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      foregroundColor: foregroundColor ?? borderColor,
      isFullWidth: isFullWidth,
      isPill: isPill,
      variant: ButtonVariant.outlined,
      size: size,
    );
  }
}

/// Icon-only button with press animation
class PremiumIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final bool enableHaptics;

  const PremiumIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 44.0,
    this.enableHaptics = true,
  });

  @override
  State<PremiumIconButton> createState() => _PremiumIconButtonState();
}

class _PremiumIconButtonState extends State<PremiumIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.fastAnimation,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = widget.color ??
        (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary);

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed == null) return;
        _animationController.forward();
        if (widget.enableHaptics) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            color: widget.onPressed != null
                ? effectiveColor
                : Theme.of(context).disabledColor,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}
