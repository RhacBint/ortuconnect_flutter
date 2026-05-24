import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';
import '../login/login_screen.dart';

/// Halaman AbsensiScreen [StatefulWidget]
/// 
/// Fungsi: Menampilkan riwayat absensi siswa secara detail tiap bulannya, 
/// serta menampilkan grafik visual statistik kehadiran (Hadir, Izin, Sakit, Alpha).
/// Alur: Memanggil State [_AbsensiScreenState] untuk memuat data absensi dari server
/// dan menampilkan visualisasi grafik interaktif.
class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

/// State [_AbsensiScreenState] dengan [WidgetsBindingObserver]
/// 
/// Fungsi: Mengelola filter bulan/tahun, kalkulasi statistik kehadiran,
/// rendering diagram lingkaran (Pie Chart), dan list riwayat absensi.
/// Alur: Menggunakan [WidgetsBindingObserver] untuk memantau siklus hidup aplikasi. 
/// Jika aplikasi kembali dibuka (*resumed*), data absensi otomatis diperbarui.
class _AbsensiScreenState extends State<AbsensiScreen>
    with WidgetsBindingObserver {
  // Status loading untuk riwayat absensi
  bool _isLoading = true;
  
  // Penampung pesan error jika request gagal
  String? _errorMessage;
  
  // List data absensi mentah dari server
  List<dynamic> _listAbsensi = [];
  
  // ID Siswa yang tersimpan di memori lokal
  String _idSiswa = '';
  
  // Tahun dan Bulan terpilih untuk filter data absensi
  late int _selectedYear;
  late int _selectedMonth;

  // Larik nama-nama bulan dalam bahasa Indonesia
  final List<String> _bulanArray = [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember",
  ];

  /// Fungsi: Inisialisasi awal State absensi
  /// Alur:
  /// 1. Menambahkan observer siklus hidup aplikasi ([WidgetsBindingObserver]).
  /// 2. Mengatur filter default ke bulan & tahun saat ini.
  /// 3. Memicu pemanggilan [_loadAbsensi()] untuk mengambil data absensi.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadAbsensi();
  }

  /// Fungsi: Pembersihan resource State
  /// Alur: Melepas observer siklus hidup aplikasi agar tidak terjadi memory leak.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fungsi: Memantau perubahan siklus hidup aplikasi (foreground/background)
  /// Alur: Jika aplikasi di-resume (kembali aktif di depan layar), maka panggil [_loadAbsensi()] untuk penyegaran data.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAbsensi();
  }

  /// Fungsi: Mengambil data absensi siswa dari server API berdasarkan bulan & tahun terpilih.
  /// Alur:
  /// 1. Menampilkan loading spinner (`_isLoading = true`).
  /// 2. Membaca `id_siswa` dari `SharedPreferences`.
  /// 3. Memanggil API `ApiService().getAbsensi(idSiswa, 'Tahun-Bulan')`.
  /// 4. Jika sukses:
  ///    - Mengambil array absensi dan mengurutkannya dari tanggal terbaru ke terlama.
  ///    - Mematikan status loading dan menghapus pesan error lewat `setState`.
  /// 5. Jika gagal (unauthorized/token kedaluwarsa): Mengalihkan secara paksa ke `LoginScreen`.
  /// 6. Jika gagal karena koneksi/hal lain: Menyimpan pesan kesalahan ke `_errorMessage` untuk dirender.
  Future<void> _loadAbsensi() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _idSiswa = prefs.getString('id_siswa') ?? '';
      final bulanStr = _selectedMonth.toString().padLeft(2, '0');
      final res = await ApiService().getAbsensi(
        _idSiswa,
        '$_selectedYear-$bulanStr',
      );
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        _listAbsensi = List.from(data['absensi'] as List<dynamic>? ?? []);
        _listAbsensi.sort(
          (a, b) => (b['tanggal'] ?? '').compareTo(a['tanggal'] ?? ''),
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        _setError(res['message']?.toString() ?? 'Data tidak tersedia');
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      } else {
        _setError(e.message);
      }
    } catch (e) {
      _setError('Gagal memuat data absensi');
    }
  }

  /// Fungsi: Mengubah status state apabila terjadi kegagalan muat data.
  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  /// Fungsi: Menghitung akumulasi statistik absensi (Hadir, Izin, Sakit, Alpha) dari daftar absensi aktif.
  /// Alur: Melakukan iterasi/looping pada `_listAbsensi` lalu mencocokkan status string untuk menambah counter masing-masing kategori.
  Map<String, int> _getStats() {
    int hadir = 0, izin = 0, sakit = 0, alpha = 0;
    for (final item in _listAbsensi) {
      final s = item['status']?.toString().toUpperCase() ?? '';
      if (s == 'HADIR') {
        hadir++;
      } else if (s == 'IZIN') {
        izin++;
      } else if (s == 'SAKIT') {
        sakit++;
      } else if (s == 'ALPHA' || s == 'ALPA') {
        alpha++;
      }
    }
    return {'hadir': hadir, 'izin': izin, 'sakit': sakit, 'alpha': alpha};
  }

  /// Fungsi: Mendapatkan warna representatif bertema premium untuk status absensi.
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'HADIR':
        return AppTheme.success;
      case 'IZIN':
        return AppTheme.info;
      case 'SAKIT':
        return AppTheme.warning;
      case 'ALPHA':
      case 'ALPA':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  /// Fungsi: Mengonversi format tanggal ISO ('yyyy-MM-dd') menjadi format tulisan Indonesia (contoh: '21 Mei 2026').
  String _formatTanggal(String t) {
    try {
      return DateFormat(
        'dd MMMM yyyy',
        'id_ID',
      ).format(DateFormat('yyyy-MM-dd').parse(t.trim()));
    } catch (_) {
      return t;
    }
  }

  /// Fungsi: Mendapatkan label status absensi dengan imbuhan simbol visual untuk keindahan.
  String _getStatusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'HADIR':
        return '✓ Hadir';
      case 'IZIN':
        return '○ Izin';
      case 'SAKIT':
        return '+ Sakit';
      case 'ALPHA':
      case 'ALPA':
        return '✕ Alpha';
      default:
        return s;
    }
  }

  /// Fungsi: Metode render utama halaman absensi.
  /// Alur:
  /// 1. Merender halaman dengan latar belakang premium `DarkBackground`.
  /// 2. Header berisi Judul halaman "Riwayat Absensi" dan Dropdown filter Bulan.
  /// 3. Body dibungkus `RefreshIndicator` (untuk fitur tarik-ke-bawah/pull-to-refresh).
  /// 4. Logika bersyarat:
  ///    - Jika `_isLoading` true: Tampilkan putaran loading di tengah layar.
  ///    - Jika `_errorMessage` tidak null: Tampilkan tampilan error dan tombol coba lagi.
  ///    - Jika aman: Merender konten utama ([_buildContent()]).
  @override
  Widget build(BuildContext context) {
    return DarkBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Riwayat Absensi',
                      style: AppTheme.heading1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        isDense: true,
                        dropdownColor: AppTheme.bgDarkPurple,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        iconEnabledColor: AppTheme.primary,
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_bulanArray[i]),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonth = val);
                            _loadAbsensi();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAbsensi,
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

  /// Fungsi: Membangun daftar utama riwayat absensi.
  /// Alur:
  /// 1. Jika data kosong (`_listAbsensi` kosong), tampilkan layar kosong dengan ikon sedih.
  /// 2. Jika ada data, render ListView:
  ///    - Baris Pertama: Render diagram statistik absensi ([_buildChart()]).
  ///    - Baris Berikutnya: Render berkala menggunakan widget `GlassCard` transparan yang menampilkan status absensi berwarna, tanggal terformat, dan badge status visual.
  Widget _buildContent() {
    if (_listAbsensi.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.event_busy_rounded,
                  color: AppTheme.textMuted,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tidak ada data absensi\nbulan ini',
                  textAlign: TextAlign.center,
                  style: AppTheme.body,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _buildChart(),
        const SizedBox(height: 14),
        ..._listAbsensi.map((item) {
          final status = item['status']?.toString() ?? 'ALPHA';
          final tanggal = item['tanggal']?.toString() ?? '';
          final color = _getStatusColor(status);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.toUpperCase(),
                          style: AppTheme.bodyLarge.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatTanggal(tanggal),
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: AppTheme.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Fungsi: Membuat visualisasi grafik lingkaran (Pie Chart) statistik absensi bulanan.
  /// Alur:
  /// 1. Mengambil ringkasan data dari [_getStats()].
  /// 2. Jika total hari absensi bernilai nol, sembunyikan grafik.
  /// 3. Membuat list `PieChartSectionData` untuk fl_chart berisi warna neon dan porsi persentase.
  /// 4. Merender layout berisi widget `PieChart` di sebelah kiri dan legenda rincian (Total hari, Hadir, Izin, dll) di sebelah kanan di dalam `GlassCard`.
  Widget _buildChart() {
    final stats = _getStats();
    final total = stats.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    final labels = <Widget>[];

    void addSection(String label, int count, Color color) {
      if (count == 0) return;
      final pct = (count / total * 100).toStringAsFixed(0);
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          color: color,
          title: '$pct%',
          radius: 55,
          titleStyle: AppTheme.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      labels.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label ($count)',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    addSection('Hadir', stats['hadir']!, AppTheme.success);
    addSection('Izin', stats['izin']!, AppTheme.info);
    addSection('Sakit', stats['sakit']!, AppTheme.warning);
    addSection('Alpha', stats['alpha']!, AppTheme.error);

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      glowShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        children: [
          Text(
            'Statistik ${_bulanArray[_selectedMonth - 1]} $_selectedYear',
            style: AppTheme.heading3.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: $total hari',
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...labels.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: l,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fungsi: Tampilan visual informatif jika terjadi kegagalan mengambil data (misalnya offline).
  /// Alur: Renders ikon peringatan, teks error, serta tombol 'Coba Lagi' yang jika diklik memanggil kembali [_loadAbsensi()].
  Widget _buildErrorView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.textMuted,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: AppTheme.body,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: _loadAbsensi,
                child: Text(
                  'Coba Lagi',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
