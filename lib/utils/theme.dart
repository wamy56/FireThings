import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'responsive.dart';
import 'theme_style.dart';

class AppTheme {
  AppTheme._();

  static bool get _isSiteOps =>
      themeStyleNotifier.value == ThemeStyle.siteOps;

  // ============================================
  // Animation Constants
  // ============================================
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 250);
  static const Duration slowAnimation = Duration(milliseconds: 350);
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.easeOutBack;

  // ============================================
  // SiteOps Palette (private constants)
  // ============================================
  static const Color _soBg = Color(0xFF0B0D10);
  static const Color _soSurface = Color(0xFF14171C);
  static const Color _soSurfaceElev = Color(0xFF1B1F26);
  static const Color _soBorder = Color(0x14FFFFFF);
  static const Color _soBorderStrong = Color(0x24FFFFFF);
  static const Color _soFg1 = Color(0xFFF4F5F7);
  static const Color _soFg2 = Color(0xFF9BA3AF);
  static const Color _soFg3 = Color(0xFF5F6773);
  static const Color _soHint = Color(0xFF3E444F);
  static const Color _soAccent = Color(0xFFFFB020);
  static const Color _soAccentDim = Color(0xFF332308);
  static const Color _soOk = Color(0xFF2FD97A);
  static const Color _soAlarm = Color(0xFFFF4747);

  // ============================================
  // Light Theme Colors (dispatch by style)
  // ============================================

  static Color get primaryBlue =>
      _isSiteOps ? _soAccent : const Color(0xFF1E3A5F);
  static Color get primaryDark =>
      _isSiteOps ? const Color(0xFFCC8D1A) : const Color(0xFF152C4A);
  static Color get primaryLight =>
      _isSiteOps ? _soAccentDim : const Color(0xFFEEF2F6);
  static Color get darkBlue =>
      _isSiteOps ? _soBg : const Color(0xFF0F2744);
  static Color get lightBlue =>
      _isSiteOps ? _soFg3 : const Color(0xFF3D5A80);

  static Color get accentOrange =>
      _isSiteOps ? _soAccent : const Color(0xFFF97316);
  static Color get successGreen =>
      _isSiteOps ? _soOk : const Color(0xFF4CAF50);
  static Color get warningOrange =>
      _isSiteOps ? _soAccent : const Color(0xFFFF9800);
  static Color get errorRed =>
      _isSiteOps ? _soAlarm : const Color(0xFFD32F2F);

  static Color get darkGrey =>
      _isSiteOps ? _soSurfaceElev : const Color(0xFF374151);
  static Color get mediumGrey =>
      _isSiteOps ? _soFg3 : const Color(0xFF6B7280);
  static Color get lightGrey =>
      _isSiteOps ? _soBorderStrong : const Color(0xFFE5E7EB);
  static Color get backgroundGrey =>
      _isSiteOps ? _soBg : const Color(0xFFFAFBFC);
  static Color get surfaceWhite =>
      _isSiteOps ? _soSurface : const Color(0xFFFFFFFF);
  static Color get dividerColor =>
      _isSiteOps ? _soBorder : const Color(0xFFE8E8E8);

  static Color get textPrimary =>
      _isSiteOps ? _soFg1 : const Color(0xFF1F2937);
  static Color get textSecondary =>
      _isSiteOps ? _soFg2 : const Color(0xFF6B7280);
  static Color get textHint =>
      _isSiteOps ? _soHint : const Color(0xFF9CA3AF);

  // ============================================
  // Dark Theme Colors (dispatch by style)
  // ============================================
  static Color get darkBackground =>
      _isSiteOps ? _soBg : const Color(0xFF121212);
  static Color get darkSurface =>
      _isSiteOps ? _soSurface : const Color(0xFF1E1E1E);
  static Color get darkSurfaceElevated =>
      _isSiteOps ? _soSurfaceElev : const Color(0xFF2D2D2D);
  static Color get darkDivider =>
      _isSiteOps ? _soBorder : const Color(0xFF3D3D3D);

  static Color get darkPrimaryBlue =>
      _isSiteOps ? _soAccent : const Color(0xFF3D7AC7);
  static Color get darkAccentOrange =>
      _isSiteOps ? _soAccent : const Color(0xFFFF8C42);

  static Color get darkTextPrimary =>
      _isSiteOps ? _soFg1 : const Color(0xFFE4E4E7);
  static Color get darkTextSecondary =>
      _isSiteOps ? _soFg2 : const Color(0xFFA1A1AA);
  static Color get darkTextHint =>
      _isSiteOps ? _soHint : const Color(0xFF71717A);

  // Spacing Constants
  static const double screenPadding = 20.0;
  static const double sectionGap = 32.0;
  static const double cardPadding = 20.0;
  static const double listItemSpacing = 16.0;

  // Responsive Spacing Methods
  static double responsiveScreenPadding(ScreenSize size) {
    switch (size) {
      case ScreenSize.compact:
        return 20;
      case ScreenSize.medium:
        return 24;
      case ScreenSize.expanded:
        return 32;
      case ScreenSize.large:
        return 40;
    }
  }

  static double responsiveSectionGap(ScreenSize size) {
    switch (size) {
      case ScreenSize.compact:
        return 32;
      case ScreenSize.medium:
        return 36;
      case ScreenSize.expanded:
        return 40;
      case ScreenSize.large:
        return 48;
    }
  }

  static double responsiveCardPadding(ScreenSize size) {
    switch (size) {
      case ScreenSize.compact:
        return 20;
      case ScreenSize.medium:
        return 24;
      case ScreenSize.expanded:
        return 28;
      case ScreenSize.large:
        return 28;
    }
  }

  static double responsiveTextScale(ScreenSize size) {
    switch (size) {
      case ScreenSize.compact:
        return 1.0;
      case ScreenSize.medium:
        return 1.05;
      case ScreenSize.expanded:
        return 1.1;
      case ScreenSize.large:
        return 1.15;
    }
  }

  // Border Radius
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;

  // SiteOps uses tighter radii
  static double get effectiveCardRadius => _isSiteOps ? 10.0 : cardRadius;
  static double get effectiveButtonRadius => _isSiteOps ? 6.0 : buttonRadius;
  static double get effectiveInputRadius => _isSiteOps ? 8.0 : inputRadius;

  // Button Heights
  static const double buttonHeight = 52.0;
  static const double inputHeight = 56.0;

  static double get effectiveButtonHeight => _isSiteOps ? 44.0 : buttonHeight;

  /// Soft multi-layer shadow for cards (SiteOps: flat, no shadows)
  static List<BoxShadow> get cardShadow => _isSiteOps
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  /// Elevated shadow for floating elements
  static List<BoxShadow> get elevatedShadow => _isSiteOps
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ];

  /// Primary button gradient
  static LinearGradient get primaryGradient => _isSiteOps
      ? LinearGradient(colors: [_soAccent, _soAccent])
      : LinearGradient(
          colors: [primaryBlue, primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  /// Monospace text style for numeric data (JetBrains Mono in SiteOps, Inter otherwise)
  static TextStyle monoDigits({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    if (_isSiteOps) {
      return GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 0.5,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentOrange,
        error: errorRed,
        surface: surfaceWhite,
        surfaceContainerHighest: backgroundGrey,
      ),

      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundGrey,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: backgroundGrey,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceWhite,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textHint),
        floatingLabelStyle: GoogleFonts.inter(color: primaryBlue),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: BorderSide(color: primaryBlue, width: 1.5),
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryBlue,
        unselectedItemColor: mediumGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: primaryLight,
        selectedColor: primaryBlue.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkGrey,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.25,
          letterSpacing: -0.3,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.3,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.35,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.45,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.45,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.2,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimaryBlue,
        brightness: Brightness.dark,
        primary: darkPrimaryBlue,
        secondary: darkAccentOrange,
        error: errorRed,
        surface: darkSurface,
        onSurface: darkTextPrimary,
      ),

      primaryColor: darkPrimaryBlue,
      scaffoldBackgroundColor: darkBackground,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        titleTextStyle: GoogleFonts.inter(
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: darkPrimaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: GoogleFonts.inter(color: darkTextSecondary),
        hintStyle: GoogleFonts.inter(color: darkTextHint),
        floatingLabelStyle: GoogleFonts.inter(color: darkPrimaryBlue),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimaryBlue,
          side: BorderSide(color: darkPrimaryBlue, width: 1.5),
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimaryBlue,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceElevated,
        selectedColor: darkPrimaryBlue.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.inter(color: darkTextPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: darkTextSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceElevated,
        contentTextStyle: GoogleFonts.inter(color: darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          height: 1.25,
          letterSpacing: -0.3,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          height: 1.3,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
          height: 1.35,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.45,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.45,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: darkTextPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: darkTextPrimary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: darkTextSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
          letterSpacing: 0.2,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// SiteOps theme — dark instrument-panel aesthetic
  static ThemeData get siteOpsTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: _soAccent,
        brightness: Brightness.dark,
        primary: _soAccent,
        secondary: _soAccent,
        error: _soAlarm,
        surface: _soSurface,
        onSurface: _soFg1,
        onPrimary: const Color(0xFF121008),
      ),

      primaryColor: _soAccent,
      scaffoldBackgroundColor: _soBg,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: _soBg,
        foregroundColor: _soFg1,
        titleTextStyle: GoogleFonts.inter(
          color: _soFg1,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.4,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: _soFg2),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: _soSurface,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _soBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _soSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _soBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _soBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _soAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _soAlarm),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _soAlarm, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.inter(color: _soFg2),
        hintStyle: GoogleFonts.inter(color: _soHint),
        floatingLabelStyle: GoogleFonts.inter(color: _soAccent),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _soAccent,
          foregroundColor: const Color(0xFF121008),
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _soFg1,
          side: BorderSide(color: _soBorderStrong),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _soAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _soAccent,
        foregroundColor: const Color(0xFF121008),
        elevation: 0,
        highlightElevation: 0,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _soBg,
        selectedItemColor: _soFg1,
        unselectedItemColor: _soFg3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: _soBorder,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: _soSurfaceElev,
        selectedColor: _soAccent.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(color: _soFg1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: _soBorder),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _soSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _soBorder),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: _soFg1,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: _soFg2,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: _soSurfaceElev,
        contentTextStyle: GoogleFonts.inter(color: _soFg1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: _soBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: _soFg1,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _soFg1,
          height: 1.25,
          letterSpacing: -0.3,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _soFg1,
          height: 1.3,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _soFg1,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _soFg1,
          height: 1.35,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _soFg1,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _soFg1,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _soFg1,
          height: 1.45,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _soFg1,
          height: 1.45,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _soFg1,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _soFg1,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _soFg2,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _soFg1,
          letterSpacing: 1.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _soFg2,
          letterSpacing: 0.6,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _soFg3,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  /// Dark mode shadow (subtle glow effect)
  static List<BoxShadow> get darkCardShadow => _isSiteOps
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];

  /// Status colors helper
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'pass':
      case 'success':
        return successGreen;
      case 'pending':
      case 'warning':
        return warningOrange;
      case 'failed':
      case 'error':
        return errorRed;
      default:
        return mediumGrey;
    }
  }

  /// Template colors helper (matches new_job_screen.dart)
  static Color getTemplateColor(String templateId) {
    switch (templateId) {
      case 'battery_replacement':
        return primaryBlue;
      case 'detector_replacement':
        return accentOrange;
      case 'annual_inspection':
        return successGreen;
      case 'quarterly_test':
        return const Color(0xFF9C27B0);
      case 'panel_commissioning':
        return const Color(0xFF009688);
      case 'fault_finding':
        return errorRed;
      case 'weekly_test':
        return const Color(0xFF2196F3);
      case 'emergency_lighting_annual':
        return const Color(0xFFFFC107);
      default:
        return mediumGrey;
    }
  }
}

extension ResponsiveThemeExtension on BuildContext {
  double get rScreenPadding =>
      AppTheme.responsiveScreenPadding(screenSize);

  double get rSectionGap =>
      AppTheme.responsiveSectionGap(screenSize);

  double get rCardPadding =>
      AppTheme.responsiveCardPadding(screenSize);

  double get rTextScale =>
      AppTheme.responsiveTextScale(screenSize);
}

extension CardDecorationExtension on Widget {
  Widget withCardDecoration({
    Color? backgroundColor,
    double? borderRadius,
    List<BoxShadow>? shadow,
  }) {
    final isSiteOps = themeStyleNotifier.value == ThemeStyle.siteOps;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isSiteOps ? AppTheme._soSurface : AppTheme.surfaceWhite),
        borderRadius: BorderRadius.circular(
            borderRadius ?? (isSiteOps ? 10.0 : AppTheme.cardRadius)),
        boxShadow: shadow ?? (isSiteOps ? null : AppTheme.cardShadow),
        border: isSiteOps ? Border.all(color: AppTheme._soBorder) : null,
      ),
      child: this,
    );
  }
}
