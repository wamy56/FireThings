import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/background_decoration.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/keyboard_dismiss_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRegisterMode = false;

  // Animation controllers
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  // Staggered animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _emailFade;
  late final Animation<Offset> _emailSlide;
  late final Animation<double> _passwordFade;
  late final Animation<Offset> _passwordSlide;
  late final Animation<double> _buttonFade;
  late final Animation<double> _buttonScale;
  late final Animation<double> _forgotFade;

  // Logo pulse animation
  late final Animation<double> _logoPulse;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _entranceController.forward();
  }

  void _initAnimations() {
    // Entrance animation controller (1200ms, plays once)
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Pulse animation controller (3000ms, repeats after entrance completes)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Start pulse animation after entrance completes
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat();
      }
    });

    // Logo: 0.00 - 0.35 (scale + fade) with easeOutBack for slight overshoot
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: AppTheme.defaultCurve),
      ),
    );

    // Subtitle: 0.29 - 0.50 (fade + slide)
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.29, 0.50, curve: AppTheme.defaultCurve),
      ),
    );
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.29, 0.50, curve: AppTheme.defaultCurve),
          ),
        );

    // Email field: 0.42 - 0.63 (fade + slide)
    _emailFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.42, 0.63, curve: AppTheme.defaultCurve),
      ),
    );
    _emailSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.42, 0.63, curve: AppTheme.defaultCurve),
          ),
        );

    // Password field: 0.50 - 0.71 (fade + slide)
    _passwordFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.50, 0.71, curve: AppTheme.defaultCurve),
      ),
    );
    _passwordSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.50, 0.71, curve: AppTheme.defaultCurve),
          ),
        );

    // Button: 0.58 - 0.79 (fade + scale)
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.58, 0.79, curve: AppTheme.defaultCurve),
      ),
    );
    _buttonScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.58, 0.79, curve: AppTheme.defaultCurve),
      ),
    );

    // Forgot password link: 0.71 - 0.92 (fade only)
    _forgotFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.71, 0.92, curve: AppTheme.defaultCurve),
      ),
    );

    // Logo pulse: oscillates 1.0 → 1.02 → 1.0
    _logoPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.02,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.02,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _formKey.currentState?.reset();
      _nameController.clear();
      _confirmPasswordController.clear();
    });
    // Replay the staggered entrance animation
    _pulseController.stop();
    _entranceController.reset();
    _entranceController.forward();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      // Navigation happens automatically via auth state stream
    } catch (e) {
      if (mounted) {
        context.showErrorToast(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      context.showWarningToast('Please enter your email address first');
      return;
    }

    try {
      await _authService.resetPassword(email);
      if (mounted) {
        context.showSuccessToast('Password reset email sent. Check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast(e.toString());
      }
    }
  }

  Future<void> _handleLogin() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Navigation happens automatically via auth state stream
    } catch (e) {
      // Show error message
      if (mounted) {
        context.showErrorToast(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey[100],
      body: KeyboardDismissWrapper(child: Stack(
        children: [
          // Subtle gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: isDark ? 0.02 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative circles
          const BackgroundDecoration(),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24.0),
                child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with scale entrance + pulse animation
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _entranceController,
                      _pulseController,
                    ]),
                    builder: (context, child) {
                      final entranceScale = _logoScale.value;
                      final pulseScale = _pulseController.isAnimating
                          ? _logoPulse.value
                          : 1.0;
                      return FadeTransition(
                        opacity: _logoFade,
                        child: Transform.scale(
                          scale: entranceScale * pulseScale,
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      'assets/images/firethings_logo_vertical_centered.png',
                      height: 170,
                      width: 170,
                    ),
                  ),

                  // App subtitle with fade + slide
                  SlideTransition(
                    position: _subtitleSlide,
                    child: FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Fire Alarm Helper App',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Name field (register mode only)
                  if (_isRegisterMode) ...[
                    SlideTransition(
                      position: _emailSlide,
                      child: FadeTransition(
                        opacity: _emailFade,
                        child: TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(AppIcons.user),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkSurfaceElevated
                                : Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email field with fade + slide
                  SlideTransition(
                    position: _isRegisterMode ? _passwordSlide : _emailSlide,
                    child: FadeTransition(
                      opacity: _isRegisterMode ? _passwordFade : _emailFade,
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(AppIcons.sms),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceElevated
                              : Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password field with fade + slide
                  SlideTransition(
                    position: _passwordSlide,
                    child: FadeTransition(
                      opacity: _passwordFade,
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: _isRegisterMode
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: _isRegisterMode
                            ? null
                            : (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(AppIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? AppIcons.eye
                                  : AppIcons.eyeSlash,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceElevated
                              : Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Confirm password field (register mode only)
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 16),
                    SlideTransition(
                      position: _passwordSlide,
                      child: FadeTransition(
                        opacity: _buttonFade,
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegister(),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(AppIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? AppIcons.eye
                                    : AppIcons.eyeSlash,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkSurfaceElevated
                                : Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Login/Register button with fade + scale
                  ScaleTransition(
                    scale: _buttonScale,
                    child: FadeTransition(
                      opacity: _buttonFade,
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isRegisterMode
                                    ? _handleRegister
                                    : _handleLogin),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const AdaptiveLoadingIndicator(
                                  size: 20,
                                  color: Colors.white,
                                )
                              : Text(
                                  _isRegisterMode ? 'Create Account' : 'Login',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Forgot password (login mode only)
                  if (!_isRegisterMode)
                    FadeTransition(
                      opacity: _forgotFade,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),

                  // Toggle between login and register
                  FadeTransition(
                    opacity: _forgotFade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegisterMode
                              ? 'Already have an account?'
                              : "Don't have an account?",
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey[600],
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _toggleMode,
                          child: Text(
                            _isRegisterMode ? 'Sign In' : 'Create Account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
        ],
      )),
    );
  }
}
