import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/icon_map.dart';
import '../utils/adaptive_widgets.dart';

/// A save button that morphs from text → checkmark icon → back to text
/// over ~1.5s to provide inline success feedback.
class AnimatedSaveButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final bool enabled;
  final bool outlined;

  const AnimatedSaveButton({
    super.key,
    this.label = 'Save',
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.enabled = true,
    this.outlined = false,
  });

  @override
  State<AnimatedSaveButton> createState() => AnimatedSaveButtonState();
}

class AnimatedSaveButtonState extends State<AnimatedSaveButton>
    with SingleTickerProviderStateMixin {
  _ButtonState _state = _ButtonState.idle;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.bounceCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    if (_state != _ButtonState.idle) return;

    setState(() => _state = _ButtonState.saving);

    try {
      await widget.onPressed();
      if (!mounted) return;

      HapticFeedback.lightImpact();
      setState(() => _state = _ButtonState.success);
      _controller.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      _controller.reverse().then((_) {
        if (mounted) setState(() => _state = _ButtonState.idle);
      });
    } catch (_) {
      if (mounted) setState(() => _state = _ButtonState.idle);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outlined) return _buildOutlined(context);
    return _buildFilled(context);
  }

  Widget _buildFilled(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);
    final fgColor = widget.foregroundColor ?? Colors.white;
    final successColor = AppTheme.successGreen;

    return SizedBox(
      width: widget.width,
      height: 48,
      child: AnimatedContainer(
        duration: AppTheme.normalAnimation,
        curve: AppTheme.defaultCurve,
        decoration: BoxDecoration(
          color: _state == _ButtonState.success ? successColor : bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled && _state == _ButtonState.idle
                ? _handlePress
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppTheme.normalAnimation,
                switchInCurve: AppTheme.defaultCurve,
                switchOutCurve: AppTheme.defaultCurve,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _buildContent(fgColor, large: true),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlined(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = widget.backgroundColor ??
        (isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue);
    final fgColor = widget.foregroundColor ?? borderColor;
    final successColor = AppTheme.successGreen;

    final isSuccess = _state == _ButtonState.success;
    final activeFgColor = isSuccess ? successColor : fgColor;

    return SizedBox(
      width: widget.width,
      height: 36,
      child: AnimatedContainer(
        duration: AppTheme.normalAnimation,
        curve: AppTheme.defaultCurve,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled && _state == _ButtonState.idle
                ? _handlePress
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppTheme.normalAnimation,
                  switchInCurve: AppTheme.defaultCurve,
                  switchOutCurve: AppTheme.defaultCurve,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _buildContent(activeFgColor, large: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color fgColor, {required bool large}) {
    switch (_state) {
      case _ButtonState.idle:
        return Text(
          widget.label,
          key: const ValueKey('idle'),
          style: TextStyle(
            color: fgColor,
            fontSize: large ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        );
      case _ButtonState.saving:
        final size = large ? 22.0 : 18.0;
        return AdaptiveLoadingIndicator(
          key: const ValueKey('saving'),
          size: size,
          color: fgColor,
        );
      case _ButtonState.success:
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            AppIcons.tickCircle,
            key: const ValueKey('success'),
            color: fgColor,
            size: large ? 26 : 20,
          ),
        );
    }
  }
}

enum _ButtonState { idle, saving, success }
