import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../login/login_screen.dart';
import '../main/main_screen.dart';
import '../../core/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _logoScale;

  late AnimationController _textController;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  late AnimationController _loadingController;
  late Animation<double> _loadingFade;

  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
        );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeIn),
    );

    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _textController.forward();
      });
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _loadingController.forward();
    });

    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  Future<void> _navigate() async {
    try {
      // Menambahkan timeout 5 detik agar tidak stuck selamanya jika SharedPreferences bermasalah
      final bool loggedIn = await SessionManager().isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              loggedIn ? const MainScreen() : const LoginScreen(),
          transitionsBuilder: (context, anim, secondaryAnimation, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e) {
      debugPrint('Splash Navigation Error: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _orbController,
        builder: (context, child) {
          final t = _orbController.value;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppTheme.bgDark, const Color(0xFF120825), t)!,
                  Color.lerp(
                    AppTheme.bgDarkPurple,
                    const Color(0xFF1E0A30),
                    t,
                  )!,
                  Color.lerp(AppTheme.bgDeep, const Color(0xFF150730), t)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Floating orbs
                _floatingOrb(
                  size,
                  -0.1 + t * 0.04,
                  -0.12 + t * 0.03,
                  0.6,
                  AppTheme.primary.withValues(alpha: 0.12),
                ),
                _floatingOrb(
                  size,
                  0.7 - t * 0.03,
                  0.1 + t * 0.02,
                  0.45,
                  AppTheme.accent.withValues(alpha: 0.09),
                ),
                _floatingOrb(
                  size,
                  -0.15 + t * 0.02,
                  0.65 - t * 0.03,
                  0.5,
                  AppTheme.indigo.withValues(alpha: 0.1),
                ),
                _floatingOrb(
                  size,
                  0.75 - t * 0.04,
                  0.72 + t * 0.02,
                  0.35,
                  AppTheme.accent.withValues(alpha: 0.07),
                ),
                // Fix: Wrap Column in Positioned.fill to ensure Spacers work
                Positioned.fill(child: child!),
              ],
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Logo with Glassmorphism Container & Glow
            FadeTransition(
              opacity: _logoFade,
              child: SlideTransition(
                position: _logoSlide,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: GlassCard(
                    borderRadius: 48,
                    blur: 30,
                    padding: const EdgeInsets.all(32),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    borderOpacity: 0.1,
                    glowShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 50,
                        spreadRadius: 2,
                      ),
                    ],
                    child: Image.asset(
                      'assets/images/app_icon3.png',
                      width: 160,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // App Name & Tagline
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  children: [
                    Text(
                      'OrtuConnect',
                      style: AppTheme.heading1.copyWith(
                        fontSize: 34,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pantau Putra-Putri Anda',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Loading & Version Section
            FadeTransition(
              opacity: _loadingFade,
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'VERSION 2.0',
                    style: AppTheme.label.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 3.0,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress line decoration
                  Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingOrb(
    Size size,
    double left,
    double top,
    double scale,
    Color color,
  ) {
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
