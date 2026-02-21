import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/icon_map.dart';
import '../utils/theme.dart';

/// Custom text field with enhanced styling and animations
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? initialValue;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final bool showClearButton;
  final bool showValidationIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.inputFormatters,
    this.readOnly = false,
    this.showClearButton = false,
    this.showValidationIcon = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;
  bool _isFocused = false;
  bool _hasText = false;
  String? _validationError;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.fastAnimation,
    );
    _focusAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppTheme.defaultCurve,
      ),
    );

    // Check initial text state
    if (widget.controller != null) {
      _hasText = widget.controller!.text.isNotEmpty;
      widget.controller!.addListener(_onTextChanged);
    } else if (widget.initialValue != null) {
      _hasText = widget.initialValue!.isNotEmpty;
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    widget.controller?.removeListener(_onTextChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (_isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onTextChanged() {
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _clearText() {
    widget.controller?.clear();
    widget.onChanged?.call('');
    HapticFeedback.selectionClick();
  }

  Widget? _buildSuffixIcon() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> icons = [];

    // Clear button
    if (widget.showClearButton && _hasText && widget.enabled && !widget.readOnly) {
      icons.add(
        AnimatedOpacity(
          opacity: _hasText ? 1 : 0,
          duration: AppTheme.fastAnimation,
          child: GestureDetector(
            onTap: _clearText,
            child: Icon(
              AppIcons.close,
              size: 20,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    // Validation icon
    if (widget.showValidationIcon && _hasText && !_isFocused) {
      if (_isValid) {
        icons.add(
          AnimatedOpacity(
            opacity: 1,
            duration: AppTheme.fastAnimation,
            child: Icon(
              AppIcons.tickCircle,
              size: 20,
              color: AppTheme.successGreen,
            ),
          ),
        );
      } else if (_validationError != null) {
        icons.add(
          AnimatedOpacity(
            opacity: 1,
            duration: AppTheme.fastAnimation,
            child: Icon(
              AppIcons.danger,
              size: 20,
              color: AppTheme.errorRed,
            ),
          ),
        );
      }
    }

    // Custom suffix icon
    if (widget.suffixIcon != null) {
      icons.add(widget.suffixIcon!);
    }

    if (icons.isEmpty) return null;
    if (icons.length == 1) return icons.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons
          .map((icon) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: icon,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: (isDark
                              ? AppTheme.darkPrimaryBlue
                              : AppTheme.primaryBlue)
                          .withValues(alpha: 0.15 * _focusAnimation.value),
                      blurRadius: 8 * _focusAnimation.value,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        initialValue: widget.initialValue,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        readOnly: widget.readOnly,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon,
          suffixIcon: _buildSuffixIcon(),
          counterText: widget.maxLength != null ? null : '',
          filled: true,
          fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.dividerColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: isDark ? AppTheme.darkPrimaryBlue : AppTheme.primaryBlue,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: const BorderSide(color: AppTheme.errorRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide(
              color: (isDark ? AppTheme.darkDivider : AppTheme.dividerColor)
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
        validator: (value) {
          final error = widget.validator?.call(value);
          // Update validation state for icon display
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _validationError = error;
                _isValid = error == null && (value?.isNotEmpty ?? false);
              });
            }
          });
          return error;
        },
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        inputFormatters: widget.inputFormatters,
      ),
    );
  }
}

/// Password text field with toggle visibility
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool showValidationIcon;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const PasswordTextField({
    super.key,
    this.controller,
    this.label = 'Password',
    this.hint,
    this.validator,
    this.onChanged,
    this.showValidationIcon = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      obscureText: _obscureText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      showValidationIcon: widget.showValidationIcon,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      suffixIcon: GestureDetector(
        onTap: () {
          setState(() {
            _obscureText = !_obscureText;
          });
          HapticFeedback.selectionClick();
        },
        child: Icon(
          _obscureText ? AppIcons.eyeSlash : AppIcons.eye,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

/// Search text field with search icon and clear button
class SearchTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;

  const SearchTextField({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomTextField(
      controller: controller,
      label: '',
      hint: hint,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      showClearButton: true,
      textInputAction: TextInputAction.search,
      prefixIcon: Icon(
        AppIcons.search,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      ),
    );
  }
}
