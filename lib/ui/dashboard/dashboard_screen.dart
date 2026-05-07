import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../login/login_screen.dart';
import '../../core/api_service.dart';
import '../../core/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;

  String _namaSiswa = '';
  String _kelas = '';
  String _fotoUrl = '';
  String _genderIcon = 'cowo';
  String _agendaTitle = 'Tidak ada agenda/pengumuman';
  String _agendaDate = '';
  String _kehadiranStatus = 'Data kehadiran tidak tersedia';
  String _izinStatus = 'Belum ada izin terbaru';
  String _idSiswa = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboard();
      if (_idSiswa.isNotEmpty) {
        NotificationService().checkAll(_idSiswa);
        NotificationService().checkAbsensiHariIni(_idSiswa, _namaSiswa);
        NotificationService().checkRekapMingguan(_idSiswa, _namaSiswa);
      }
    }
  }

  Future<void> _loadDashboard() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // Ambil id_siswa dari session
      final prefs = await SharedPreferences.getInstance();
      _idSiswa = prefs.getString('id_siswa') ?? '';
      _genderIcon = prefs.getString('profile_gender_icon') ?? 'cowo';

      final res = await ApiService().getDashboard(_idSiswa);

      if (res['success'] != true) {
        _setError(res['message']?.toString() ?? 'Gagal mengambil data');
        return;
      }

      final data = res['data'] as Map<String, dynamic>;

      // Profil
      if (data['profil'] is Map) {
        final p = data['profil'] as Map<String, dynamic>;
        _namaSiswa = p['nama_siswa']?.toString() ?? '';
        _kelas     = p['kelas']?.toString() ?? '';
        _fotoUrl   = ApiService.photoUrl(p['foto']?.toString());
        _idSiswa   = p['id_siswa']?.toString() ?? _idSiswa;
      }

      // Agenda mendatang
      _parseAgenda(data['agenda_mendatang']);

      // Kehadiran minggu ini
      if (data['kehadiran_minggu_ini'] is Map) {
        final k = data['kehadiran_minggu_ini'] as Map<String, dynamic>;
        final hadir = k['jumlah_hadir'] ?? k['hadir'] ?? '0';
        final total = k['total_hari'] ?? '5';
        _kehadiranStatus = 'Hadir: $hadir/$total hari';
      }

      // Izin terbaru
      _parseIzin(data['izin_terbaru']);

      // Notifikasi
      if (_idSiswa.isNotEmpty && _namaSiswa.isNotEmpty) {
        NotificationService().checkAbsensiHariIni(_idSiswa, _namaSiswa);
        NotificationService().checkRekapMingguan(_idSiswa, _namaSiswa);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _logout();
      } else {
        _setError(e.message);
      }
    } catch (e) {
      _setError('Gagal memuat dashboard. Tarik ke bawah untuk refresh.');
    }
  }

  void _parseAgenda(dynamic raw) {
    _agendaTitle = 'Tidak ada agenda/pengumuman';
    _agendaDate  = '';
    if (raw == null) return;

    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = raw.values.toList();
    } else {
      return;
    }
    if (list.isEmpty) return;

    final now = DateTime.now();
    Map<String, dynamic>? upcoming;
    Duration? closest;

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final dateStr = item['tanggal']?.toString() ?? '';
      if (dateStr.isEmpty) continue;
      final dt = _parseDate(dateStr);
      if (dt == null) continue;
      if (!dt.isBefore(DateTime(now.year, now.month, now.day))) {
        final diff = dt.difference(now);
        if (closest == null || diff < closest) {
          closest = diff;
          upcoming = item;
        }
      }
    }

    if (upcoming != null) {
      _agendaTitle = upcoming['nama_kegiatan']?.toString() ?? 'Kegiatan';
      _agendaDate  = _formatTanggal(upcoming['tanggal']?.toString() ?? '');
    }
  }

  void _parseIzin(dynamic raw) {
    _izinStatus = 'Belum ada izin terbaru';
    if (raw == null) return;

    Map<String, dynamic>? izin;
    if (raw is Map<String, dynamic>) {
      izin = raw;
    } else if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      izin = raw.first as Map<String, dynamic>;
    }

    if (izin != null) {
      final status = izin['status']?.toString() ?? 'Menunggu';
      final jenis  = izin['jenis_izin']?.toString() ?? '';
      final tgl    = izin['tanggal_pengajuan']?.toString() ?? '';
      final sb = StringBuffer(status.isEmpty ? 'Menunggu' : status);
      if (jenis.isNotEmpty) sb.write(' ($jenis)');
      if (tgl.isNotEmpty && !tgl.contains('0000')) {
        sb.write('\n${_formatTanggal(tgl.split(' ')[0])}');
      }
      _izinStatus = sb.toString();
    }
  }

  DateTime? _parseDate(String s) {
    for (final f in ['yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd', 'dd-MM-yyyy']) {
      try { return DateFormat(f).parse(s); } catch (_) {}
    }
    return null;
  }

  String _formatTanggal(String s) {
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(DateFormat('yyyy-MM-dd').parse(s.trim()));
    } catch (_) { return s; }
  }

  void _setError(String msg) {
    if (mounted) setState(() { _isLoading = false; _errorMessage = msg; });
  }

  Future<void> _logout() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
                onRefresh: _loadDashboard,
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
              TextButton(
                onPressed: _loadDashboard,
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
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
    final String genderAsset = _genderIcon == 'cewe'
        ? 'assets/images/icon_cewe.png'
        : 'assets/images/icon_cowo.png';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E2E2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
            backgroundImage: _fotoUrl.isNotEmpty
                ? NetworkImage(_fotoUrl) as ImageProvider
                : AssetImage(genderAsset),
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
          Text(_agendaTitle,
              style: const TextStyle(color: Color(0xFF68327E), fontSize: 15, fontWeight: FontWeight.bold)),
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
      child: Text(_kehadiranStatus,
          style: const TextStyle(color: Color(0xFF68327E), fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusIzinCard() {
    return _cardWrapper(
      assetIcon: 'assets/images/ic_perizinan.png',
      label: 'Status Izin Terbaru',
      child: Text(_izinStatus,
          style: const TextStyle(color: Color(0xFF68327E), fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _cardWrapper({required Widget child, required String assetIcon, required String label}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E2E2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
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
                Text(label,
                    style: const TextStyle(
                        color: Colors.black45, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.4)),
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
