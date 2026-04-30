import 'package:flutter/material.dart';
import '../login/login_screen.dart';
import '../main/main_screen.dart';
import '../../core/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controller untuk logo
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _logoScale;

  // Controller untuk subtitle
  late AnimationController _textController;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  // Controller untuk loading indicator
  late AnimationController _loadingController;
  late Animation<double> _loadingFade;

  @override
  void initState() {
    super.initState();

    // --- Logo animation ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // --- Subtitle animation (delay 600ms) ---
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // --- Loading indicator (delay 1000ms) ---
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeIn),
    );

    // Jalankan animasi berurutan
    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _textController.forward();
      });
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _loadingController.forward();
    });

    // Navigasi setelah semua animasi selesai
    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  Future<void> _navigate() async {
    final bool loggedIn = await SessionManager().isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            loggedIn ? const MainScreen() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF007ABF),
              Color(0xFF45287F),
              Color(0xFF68327E),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Logo dengan animasi slide up + fade + scale
            FadeTransition(
              opacity: _logoFade,
              child: SlideTransition(
                position: _logoSlide,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/images/logo_ortuconnect.png',
                    width: 180,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Subtitle dengan animasi slide up + fade (delayed)
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Text(
                  'Pantau Putra-Putri Anda',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 15,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Loading indicator kecil di bawah
            FadeTransition(
              opacity: _loadingFade,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
