import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// OrtuConnect – Dark Premium Glassmorphism Theme
/// ──────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // ── Core palette ──────────────────────────────────────────────────────
  static const Color bgDark       = Color(0xFF0A0A0F);
  static const Color bgDarkPurple = Color(0xFF1A1025);
  static const Color bgDeep       = Color(0xFF0F0520);

  static const Color primary      = Color(0xFF8B5CF6);
  static const Color indigo       = Color(0xFF6366F1);
  static const Color accent       = Color(0xFFD946EF);

  static const Color surface      = Color(0x14FFFFFF);
  static const Color surfaceBright= Color(0x1FFFFFFF);
  static const Color cardBorder   = Color(0x26FFFFFF);

  static const Color textPrimary  = Color(0xFFFFFFFF);
  static const Color textSecondary= Color(0xB3FFFFFF);
  static const Color textMuted    = Color(0x66FFFFFF);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDark, bgDarkPurple, bgDeep],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, indigo],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  // ── Text Styles (Poppins) ─────────────────────────────────────────────
  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary,
  );
  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
  );
  static TextStyle heading3 = GoogleFonts.poppins(
    fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
  );
  static TextStyle bodyLarge = GoogleFonts.poppins(
    fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary,
  );
  static TextStyle body = GoogleFonts.poppins(
    fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary,
  );
  static TextStyle bodySmall = GoogleFonts.poppins(
    fontSize: 12, fontWeight: FontWeight.w400, color: textMuted,
  );
  static TextStyle label = GoogleFonts.poppins(
    fontSize: 11, fontWeight: FontWeight.w600, color: textMuted, letterSpacing: 0.8,
  );
  static TextStyle button = GoogleFonts.poppins(
    fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary,
  );

  // ── ThemeData ─────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgDarkPurple,
        error: error,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgDarkPurple,
        contentTextStyle: body.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
/// Glassmorphism Card Widget
/// ──────────────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final double borderOpacity;
  final List<BoxShadow>? glowShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blur = 20,
    this.backgroundColor,
    this.borderOpacity = 0.12,
    this.glowShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
            ),
            boxShadow: glowShadow,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────────────────
/// Dark Background with decorative orbs
/// ──────────────────────────────────────────────────────────────────────────
class DarkBackground extends StatelessWidget {
  final Widget child;

  const DarkBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Stack(
        children: [
          _orb(size, -0.1, -0.12, 0.6, AppTheme.primary.withValues(alpha: 0.08)),
          _orb(size, 0.7, 0.08, 0.5, AppTheme.accent.withValues(alpha: 0.06)),
          _orb(size, -0.15, 0.65, 0.55, AppTheme.indigo.withValues(alpha: 0.07)),
          _orb(size, 0.75, 0.72, 0.4, AppTheme.primary.withValues(alpha: 0.05)),
          child,
        ],
      ),
    );
  }

  Widget _orb(Size size, double left, double top, double scale, Color color) {
    return Positioned(
      left: size.width * left,
      top: size.height * top,
      child: Container(
        width: size.width * scale,
        height: size.width * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

/// Gradient accent button used across the app
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double height;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isLoading ? null : AppTheme.accentGradient,
        color: isLoading ? Colors.white.withValues(alpha: 0.1) : null,
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : child,
      ),
    );
  }
}
