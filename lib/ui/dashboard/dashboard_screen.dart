import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../login/login_screen.dart';
import '../../core/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
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
  String _izinJenis = '';
  String _izinTanggal = '';
  int _jumlahHadir = 0;
  int _totalHari = 0;
  double _kehadiranPersen = 0.0;
  List<String> _mingguIniStatus = ['-', '-', '-', '-', '-'];

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
    if (state == AppLifecycleState.resumed) _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _idSiswa = prefs.getString('id_siswa') ?? '';
      _genderIcon = prefs.getString('profile_gender_icon') ?? 'cowo';
      final res = await ApiService().getDashboard(_idSiswa);
      if (res['success'] != true) {
        _setError(res['message']?.toString() ?? 'Gagal mengambil data');
        return;
      }
      final data = res['data'] as Map<String, dynamic>;
      if (data['profil'] is Map) {
        final p = data['profil'] as Map<String, dynamic>;
        _namaSiswa = p['nama_siswa']?.toString() ?? '';
        _kelas = p['kelas']?.toString() ?? '';
        _fotoUrl = ApiService.photoUrl(p['foto']?.toString());
        _idSiswa = p['id_siswa']?.toString() ?? _idSiswa;
      }
      _parseAgenda(data['agenda_mendatang']);
      if (data['kehadiran_minggu_ini'] is Map) {
        final k = data['kehadiran_minggu_ini'] as Map<String, dynamic>;
        _jumlahHadir = int.tryParse(k['jumlah_hadir']?.toString() ?? '0') ?? 0;
        _totalHari = int.tryParse(k['total_hari']?.toString() ?? '0') ?? 0;
        _kehadiranPersen = _totalHari > 0 ? (_jumlahHadir / _totalHari) : 0.0;
        _kehadiranStatus = 'Hadir: $_jumlahHadir/$_totalHari hari';

        // Parse detail absensi pekan ini (Senin - Jumat)
        _mingguIniStatus = ['-', '-', '-', '-', '-'];
        if (k['detail'] is List) {
          final detailList = k['detail'] as List;
          for (final item in detailList) {
            if (item is Map<String, dynamic>) {
              final tglStr = item['tanggal']?.toString() ?? '';
              final status = item['status']?.toString() ?? '';
              if (tglStr.isNotEmpty) {
                final dt = _parseDate(tglStr);
                if (dt != null) {
                  final dayIndex = dt.weekday - 1;
                  if (dayIndex >= 0 && dayIndex < 5) {
                    _mingguIniStatus[dayIndex] = status;
                  }
                }
              }
            }
          }
        }
      }
      _parseIzin(data['izin_terbaru']);
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
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
    _agendaDate = '';
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
      _agendaDate = _formatTanggal(upcoming['tanggal']?.toString() ?? '');
    }
  }

  void _parseIzin(dynamic raw) {
    _izinStatus = 'Belum ada izin terbaru';
    _izinJenis = '';
    _izinTanggal = '';
    if (raw == null) return;
    Map<String, dynamic>? izin;
    if (raw is Map<String, dynamic>) {
      izin = raw;
    } else if (raw is List &&
        raw.isNotEmpty &&
        raw.first is Map<String, dynamic>) {
      izin = raw.first as Map<String, dynamic>;
    }
    if (izin != null) {
      _izinStatus = izin['status']?.toString() ?? 'Menunggu';
      if (_izinStatus.isEmpty) _izinStatus = 'Menunggu';
      _izinJenis = izin['jenis_izin']?.toString() ?? '';
      final tgl = izin['tanggal_pengajuan']?.toString() ?? '';
      if (tgl.isNotEmpty && !tgl.contains('0000')) {
        _izinTanggal = _formatTanggal(tgl.split(' ')[0]);
      }
    }
  }

  String get _kehadiranDeskripsi {
    if (_mingguIniStatus.every((s) => s == '-')) {
      return 'Belum ada data kehadiran pekan ini';
    }
    final sakit = _mingguIniStatus.where((s) => s == 'Sakit').length;
    final izin = _mingguIniStatus.where((s) => s == 'Izin').length;
    final alfa = _mingguIniStatus.where((s) => s == 'Alfa').length;
    
    final List<String> parts = [];
    if (sakit > 0) parts.add('$sakit hari Sakit');
    if (izin > 0) parts.add('$izin hari Izin');
    if (alfa > 0) parts.add('$alfa hari Alfa');
    
    if (parts.isEmpty) {
      return 'Kehadiran pekan ini sempurna!';
    }
    return 'Pekan ini: ${parts.join(', ')}';
  }

  DateTime? _parseDate(String s) {
    for (final f in ['yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd', 'dd-MM-yyyy']) {
      try {
        return DateFormat(f).parse(s);
      } catch (_) {}
    }
    return null;
  }

  String _formatTanggal(String s) {
    try {
      return DateFormat(
        'dd MMMM yyyy',
        'id_ID',
      ).format(DateFormat('yyyy-MM-dd').parse(s.trim()));
    } catch (_) {
      return s;
    }
  }

  void _setError(String msg) {
    if (mounted)
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
  }

  Future<void> _logout() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DarkBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Text('Beranda', style: AppTheme.heading1),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDashboard,
                color: AppTheme.accent,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      )
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
              const Icon(
                Icons.info_outline,
                color: AppTheme.textMuted,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: AppTheme.body,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: _loadDashboard,
                child: Text(
                  'Coba Lagi',
                  style: AppTheme.bodyLarge.copyWith(color: AppTheme.primary),
                ),
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
          // Navigasi ke Profil (Index 5)
          InkWell(
            onTap: () => widget.onNavigate(5),
            borderRadius: BorderRadius.circular(24),
            child: _buildProfileCard(),
          ),
          const SizedBox(height: 14),
          // Navigasi ke Kalender (Index 3)
          InkWell(
            onTap: () => widget.onNavigate(3),
            borderRadius: BorderRadius.circular(24),
            child: _buildAgendaCard(),
          ),
          const SizedBox(height: 14),
          // Navigasi ke Absensi (Index 1)
          InkWell(
            onTap: () => widget.onNavigate(1),
            borderRadius: BorderRadius.circular(24),
            child: _buildKehadiranCard(),
          ),
          const SizedBox(height: 14),
          // Navigasi ke Perizinan (Index 2)
          InkWell(
            onTap: () => widget.onNavigate(2),
            borderRadius: BorderRadius.circular(24),
            child: _buildStatusIzinCard(),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final genderAsset = _genderIcon == 'cewe'
        ? 'assets/images/icon_cewe.png'
        : 'assets/images/icon_cowo.png';
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      glowShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundImage: _fotoUrl.isNotEmpty
                  ? NetworkImage(_fotoUrl) as ImageProvider
                  : AssetImage(genderAsset),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROFIL MURID',
                  style: AppTheme.label.copyWith(
                    fontSize: 9,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_namaSiswa, style: AppTheme.heading3),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _kelas.isNotEmpty ? _kelas.toUpperCase() : 'KELAS',
                    style: AppTheme.label.copyWith(
                      color: AppTheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Ikon navigasi tambahan agar konsisten dengan design premium
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMuted.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCard() {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Agenda Mendatang',
                  style: AppTheme.heading3.copyWith(fontSize: 18),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Nested Info Card - Konsisten dengan Status Izin
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JUDUL KEGIATAN',
                        style: AppTheme.label.copyWith(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _agendaTitle,
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'WAKTU',
                      style: AppTheme.label.copyWith(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _agendaDate.isNotEmpty ? _agendaDate : '-',
                      style: AppTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKehadiranCard() {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ABSENSI PEKAN INI',
                    style: AppTheme.label.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _kehadiranStatus,
                    style: AppTheme.heading2.copyWith(
                      color: AppTheme.indigo,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              // Circular Progress
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: _kehadiranPersen,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      color: AppTheme.indigo,
                    ),
                    Center(
                      child: Text(
                        "${(_kehadiranPersen * 100).toStringAsFixed(0)}%",
                        style: AppTheme.label.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bar Visual Absensi - Dinamis Senin-Jumat dari detail absensi DB
          Row(
            children: List.generate(5, (index) {
              final status = _mingguIniStatus[index];
              Color barColor;
              if (status == 'Hadir') {
                barColor = AppTheme.success;
              } else if (status == 'Sakit' || status == 'Izin') {
                barColor = AppTheme.warning;
              } else if (status == 'Alfa') {
                barColor = AppTheme.error;
              } else {
                barColor = Colors.white.withValues(alpha: 0.05); // belum absen / libur
              }
              return Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            '"$_kehadiranDeskripsi"',
            style: AppTheme.bodySmall.copyWith(
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIzinCard() {
    String statusOnly = 'Menunggu';
    Color statusColor = AppTheme.warning;
    if (_izinStatus.toLowerCase().contains('setuju')) {
      statusOnly = 'Disetujui';
      statusColor = AppTheme.success;
    } else if (_izinStatus.toLowerCase().contains('tolak')) {
      statusOnly = 'Ditolak';
      statusColor = AppTheme.error;
    }

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Izin',
                      style: AppTheme.heading3.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Terakhir',
                      style: AppTheme.heading3.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              if (_izinStatus != 'Belum ada izin terbaru')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusOnly,
                    style: AppTheme.label.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Nested Info Card - Menggunakan Jenis Izin asli dari database
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JENIS PERIZINAN',
                      style: AppTheme.label.copyWith(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _izinJenis.isNotEmpty ? _izinJenis : '-',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TANGGAL',
                      style: AppTheme.label.copyWith(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _izinTanggal.isNotEmpty ? _izinTanggal : '-',
                      style: AppTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
