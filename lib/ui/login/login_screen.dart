import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';
import '../../core/session_manager.dart';
import '../../core/notification_service.dart';
import '../main/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _bgController;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showToast('Isi semua kolom');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService().login(username, password);

      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;

        // Cek role — hanya ortu yang boleh login di mobile
        if (data['role']?.toString() != 'ortu') {
          _showToast('Akses ditolak. Hanya orang tua yang dapat login.');
          return;
        }

        final idSiswa = data['id_siswa']?.toString() ?? '';
        final gender = data['siswa']?['gender']?.toString().toLowerCase() ?? '';

        await SessionManager().createLoginSession(
          token: data['token'].toString(),
          username: data['username'].toString(),
          userId: data['id_akun'].toString(),
          role: data['role'].toString(),
          idSiswa: idSiswa,
        );

        // Simpan gender icon untuk avatar
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'profile_gender_icon',
          gender.contains('perempuan') ? 'cewe' : 'cowo',
        );

        // Kirim FCM token ke server
        final fcmToken = await NotificationService().getFcmToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await ApiService().saveFcmToken(fcmToken);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
            transitionsBuilder: (context, anim, secondaryAnimation, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        _showToast(
          res['message']?.toString() ?? 'Username atau password salah',
        );
      }
    } on ApiException catch (e) {
      _showToast(e.message);
    } on http.ClientException {
      _showToast('Tidak ada koneksi internet');
    } catch (e) {
      debugPrint('Login error: $e');
      _showToast('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.body.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.bgDarkPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final t = _bgController.value;
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
            child: child,
          );
        },
        child: Stack(
          children: [
            _buildDecorativeOrbs(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: _buildCard(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeOrbs() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final t = _bgController.value;
        return Stack(
          children: [
            Positioned(
              top: -size.height * 0.12 + (t * 18),
              left: -size.width * 0.18,
              child: _softOrb(
                size.width * 0.72,
                AppTheme.primary.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.1 - (t * 14),
              right: -size.width * 0.2,
              child: _softOrb(
                size.width * 0.78,
                AppTheme.accent.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              top: size.height * 0.06 - (t * 12),
              right: -size.width * 0.1,
              child: _softOrb(
                size.width * 0.45,
                AppTheme.indigo.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              bottom: size.height * 0.18 + (t * 10),
              left: -size.width * 0.12,
              child: _softOrb(
                size.width * 0.42,
                AppTheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _softOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildCard() {
    return GlassCard(
      borderRadius: 28,
      blur: 30,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      borderOpacity: 0.1,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 32, bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.08),
                  AppTheme.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Image.asset(
              'assets/images/logo_ortuconnect.png',
              height: 140,
            ),
          ),
          // Form
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _usernameController,
                  hint: 'Nomor Murid',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Kata Sandi',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                ),
                const SizedBox(height: 28),
                GradientButton(
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                  child: Text('Masuk', style: AppTheme.button),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        enabled: !_isLoading,
        obscureText: isPassword && !_passwordVisible,
        style: AppTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.body.copyWith(color: AppTheme.textMuted),
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
