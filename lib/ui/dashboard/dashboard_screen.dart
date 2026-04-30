import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../login/login_screen.dart';
import '../../core/session_manager.dart';
import '../../core/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  static const String _apiDashboard =
      'https://ortuconnect.pbltifnganjuk.com/api/dashboard.php?id_siswa=';
  static const String _apiProfile =
      'https://ortuconnect.pbltifnganjuk.com/api/profile.php?username=';

  bool _isLoading = true;
  String? _errorMessage;

  String _namaSiswa = '';
  String _kelas = '';
  String _genderIcon = 'cowo';
  String _agendaTitle = 'Tidak ada agenda/pengumuman';
  String _agendaDate = '';
  String _kehadiranStatus = 'Data kehadiran tidak tersedia';
  String _izinStatus = 'Belum ada izin terbaru';
  String _username = '';
  String _idSiswa = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFromSession();
      // Cek perubahan status izin dan agenda saat app dibuka kembali
      if (_username.isNotEmpty) {
        NotificationService().checkAll(_username);
      }
    }
  }

  Future<void> _loadFromSession() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? '';
    _idSiswa = prefs.getString('id_siswa') ?? '';
    _genderIcon = prefs.getString('profile_gender_icon') ?? 'cowo';

    if (_username.isEmpty) { _logout(); return; }

    if (_idSiswa.isEmpty) {
      await _loadProfileFirst();
    } else {
      await _loadDashboard();
    }
  }

  Future<void> _loadProfileFirst() async {
    try {
      final response = await http.get(Uri.parse('$_apiProfile$_username'))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final profileData = data['data'] as Map<String, dynamic>;
        _idSiswa = profileData['id_siswa']?.toString() ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_siswa', _idSiswa);
        final gender = profileData['gender']?.toString().toLowerCase() ?? '';
        _genderIcon = gender.contains('perempuan') ? 'cewe' : 'cowo';
        await prefs.setString('profile_gender_icon', _genderIcon);
        if (_idSiswa.isNotEmpty) await _loadDashboard();
        else _setError('ID Siswa tidak ditemukan di profil');
      } else {
        _setError('Profil tidak aktif atau tidak ditemukan');
        _logout();
      }
    } catch (e) {
      _setError('Koneksi terganggu. Tarik ke bawah untuk refresh.');
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await http.get(Uri.parse('$_apiDashboard$_idSiswa'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) { _setError('Server Error (${response.statusCode})'); return; }

      final res = jsonDecode(response.body) as Map<String, dynamic>;
      if (res['status'] != 'success') { _setError(res['message']?.toString() ?? 'Gagal mengambil data'); return; }

      if (res.containsKey('profil')) {
        final p = res['profil'] as Map<String, dynamic>;
        _namaSiswa = p['nama_siswa']?.toString() ?? 'Nama tidak tersedia';
        _kelas = p['kelas']?.toString() ?? 'Kelas tidak tersedia';
      }

      _parseAgenda(res);

      if (res.containsKey('kehadiran_minggu_ini')) {
        final k = res['kehadiran_minggu_ini'] as Map<String, dynamic>;
        _kehadiranStatus = 'Hadir: ${k['hadir'] ?? '0'}/${k['total_hari'] ?? '5'} hari';
      }

      _parseIzin(res);

      if (mounted) setState(() { _isLoading = false; _errorMessage = null; });
    } catch (e) {
      _setError('Gagal memuat dashboard: $e');
    }
  }

  void _parseAgenda(Map<String, dynamic> res) {
    _agendaTitle = 'Tidak ada agenda/pengumuman';
    _agendaDate = '';
    if (!res.containsKey('agenda')) return;
    final agendaList = res['agenda'] as List<dynamic>;
    if (agendaList.isEmpty) return;

    final now = DateTime.now();
    Map<String, dynamic>? upcomingAgenda;
    Duration? closestDiff;

    for (final item in agendaList) {
      final agenda = item as Map<String, dynamic>;
      final dateStr = agenda['tanggal']?.toString() ?? '';
      if (dateStr.isEmpty) continue;
      final agendaTime = _parseDate(dateStr);
      if (agendaTime == null) continue;
      if (!agendaTime.isBefore(DateTime(now.year, now.month, now.day))) {
        final diff = agendaTime.difference(now);
        if (closestDiff == null || diff < closestDiff) {
          closestDiff = diff;
          upcomingAgenda = agenda;
        }
      }
    }

    if (upcomingAgenda != null) {
      _agendaTitle = upcomingAgenda['nama_kegiatan']?.toString() ?? 'Kegiatan';
      _agendaDate = _formatTanggal(upcomingAgenda['tanggal']?.toString() ?? '');
    }
  }

  void _parseIzin(Map<String, dynamic> res) {
    _izinStatus = 'Belum ada izin terbaru';
    if (!res.containsKey('izin_terbaru') || res['izin_terbaru'] == null) return;

    final rawIzin = res['izin_terbaru'];
    Map<String, dynamic>? latestIzin;

    if (rawIzin is Map<String, dynamic>) {
      latestIzin = rawIzin;
    } else if (rawIzin is List && rawIzin.isNotEmpty) {
      latestIzin = rawIzin.first;
    }

    if (latestIzin != null) {
      final status = latestIzin['status']?.toString() ?? 'Pending';
      final jenis = latestIzin['jenis_izin']?.toString() ?? '';
      final tgl = latestIzin['tanggal_pengajuan']?.toString() ?? '';
      final sb = StringBuffer(status.isEmpty ? 'Pending' : status);
      if (jenis.isNotEmpty) sb.write(' ($jenis)');
      if (tgl.isNotEmpty && !tgl.contains('0000')) {
        sb.write('\n${_formatTanggal(tgl.split(' ')[0])}');
      }
      _izinStatus = sb.toString();
    }
  }

  DateTime? _parseDate(String dateStr) {
    final formats = ['yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd', 'dd-MM-yyyy'];
    for (var f in formats) {
      try { return DateFormat(f).parse(dateStr); } catch (_) {}
    }
    return null;
  }

  String _formatTanggal(String tanggal) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(tanggal.trim());
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (_) { return tanggal; }
  }

  void _setError(String msg) {
    if (mounted) setState(() { _isLoading = false; _errorMessage = msg; });
  }

  Future<void> _logout() async {
    await SessionManager().logoutUser();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _refreshDatabase() async {
    setState(() => _isLoading = true);
    await _loadFromSession();
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF007ABF), Color(0xFF45287F), Color(0xFF68327E)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — tanpa tombol logout
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Text(
                'Beranda',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDatabase,
                color: const Color(0xFF68327E),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              TextButton(onPressed: _refreshDatabase, child: const Text('Coba Lagi', style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 14),
          _buildAgendaCard(),
          const SizedBox(height: 14),
          _buildKehadiranCard(),
          const SizedBox(height: 14),
          _buildStatusIzinCard(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E2E2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: AssetImage(
              _genderIcon == 'cewe'
                  ? 'assets/images/icon_cewe.png'
                  : 'assets/images/icon_cowo.png',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _namaSiswa,
                  style: const TextStyle(
                    color: Color(0xFF68327E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _kelas,
                  style: const TextStyle(
                    color: Color(0xFF0F53BF),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCard() {
    return _cardWrapper(
      assetIcon: 'assets/images/ic_speaker_white.png',
      label: 'Agenda Mendatang',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _agendaTitle,
            style: const TextStyle(
              color: Color(0xFF68327E),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_agendaDate.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_agendaDate, style: const TextStyle(color: Color(0xFF0F53BF), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildKehadiranCard() {
    return _cardWrapper(
      assetIcon: 'assets/images/ic_absensi.png',
      label: 'Kehadiran Minggu Ini',
      child: Text(
        _kehadiranStatus,
        style: const TextStyle(
          color: Color(0xFF68327E),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusIzinCard() {
    return _cardWrapper(
      assetIcon: 'assets/images/ic_perizinan.png',
      label: 'Status Izin Terbaru',
      child: Text(
        _izinStatus,
        style: const TextStyle(
          color: Color(0xFF68327E),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _cardWrapper({
    required Widget child,
    required String assetIcon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E2E2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(assetIcon, width: 40, height: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
