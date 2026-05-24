import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';
import '../login/login_screen.dart';

/// Halaman PerizinanScreen [StatefulWidget]
/// 
/// Fungsi: Menyediakan formulir pengajuan izin ketidakhadiran murid (Sakit/Izin) 
/// bagi orang tua, serta menyajikan riwayat pengajuan izin beserta status approvalnya.
/// Alur: Memanggil State [_PerizinanScreenState] untuk mengelola form input dan 
/// memproses data pengajuan izin ke server.
class PerizinanScreen extends StatefulWidget {
  const PerizinanScreen({super.key});

  @override
  State<PerizinanScreen> createState() => _PerizinanScreenState();
}

/// State [_PerizinanScreenState] dengan [WidgetsBindingObserver]
/// 
/// Fungsi: Mengontrol input form (DatePicker, Dropdown, TextArea), memvalidasi tanggal pengajuan,
/// mengirim data pengajuan ke API, memfilter riwayat izin berdasarkan bulan, dan merender status persetujuan.
/// Alur: Menggunakan observer siklus hidup aplikasi untuk merefresh otomatis daftar riwayat ketika kembali aktif.


class _PerizinanScreenState extends State<PerizinanScreen>
    with WidgetsBindingObserver {
  // Controller untuk menangkap teks input tanggal & keterangan pengajuan
  final TextEditingController _tglMulaiController = TextEditingController();
  final TextEditingController _tglSelesaiController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  // Jenis izin default terpilih dan daftar pilihan jenis izin
  String _selectedJenis = 'Sakit';
  final List<String> _jenisIzin = ['Sakit', 'Izin'];

  // Bulan filter default terpilih untuk memilah daftar riwayat
  String _selectedMonthFilter = 'Semua Bulan';
  
  // Larik penampung kategori filter bulan
  final List<String> _bulanFilter = [
    'Semua Bulan',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Status loading data riwayat izin
  bool _isLoading = true;
  
  // Status loading saat tombol 'Kirim' ditekan agar mencegah double-tap
  bool _isSubmitting = false;
  
  // Penampung pesan kesalahan
  String? _errorMessage;
  
  // List riwayat perizinan dari server
  List<dynamic> _riwayatIzin = [];

  /// Fungsi: Inisialisasi awal State perizinan
  /// Alur:
  /// 1. Mendaftarkan observer siklus hidup aplikasi.
  /// 2. Memanggil [_loadRiwayatIzin()] untuk mengambil riwayat dari database server.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRiwayatIzin();
  }

  /// Fungsi: Pembersihan resource controller & state
  /// Alur: Melepas observer siklus hidup dan mendispose seluruh TextEditingController demi mencegah memori bocor.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tglMulaiController.dispose();
    _tglSelesaiController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  /// Fungsi: Callback ketika siklus hidup aplikasi berubah
  /// Alur: Jika aplikasi kembali aktif di foreground, otomatis memanggil ulang data riwayat izin.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadRiwayatIzin();
  }

  /// Fungsi: Mengambil daftar riwayat perizinan murid yang pernah diajukan dari API Server.
  /// Alur:
  /// 1. Mengaktifkan loading (`_isLoading = true`).
  /// 2. Melakukan request HTTP GET melalui `ApiService().getPerizinan()`.
  /// 3. Jika berhasil: Menyimpan data list ke `_riwayatIzin` dan mematikan loading.
  /// 4. Jika gagal karena unauthorized: Mengarahkan paksa pengguna ke layar Login.
  /// 5. Jika gagal karena hal lain: Menyajikan pesan kegagalan ke layar.
  Future<void> _loadRiwayatIzin() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final res = await ApiService().getPerizinan();
      if (res['success'] == true) {
        _riwayatIzin = (res['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        _riwayatIzin = [];
        _setError(res['message']?.toString() ?? 'Tidak ada riwayat perizinan');
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _redirectLogin();
      } else {
        _setError(e.message);
      }
    } catch (e) {
      _setError('Gagal memuat riwayat izin');
    }
  }

  /// Fungsi: Mengirimkan form pengajuan izin baru ke API Server.
  /// Alur:
  /// 1. Validasi lokal: Tanggal mulai tidak boleh kosong.
  /// 2. Validasi lokal: Tanggal selesai tidak boleh mendahului tanggal mulai.
  /// 3. Mengaktifkan status kirim (`_isSubmitting = true`).
  /// 4. Melakukan request HTTP POST via `ApiService().submitPerizinan()`.
  /// 5. Jika berhasil:
  ///    - Menampilkan SnackBar pemberitahuan sukses.
  ///    - Mengosongkan/clear seluruh form input teks.
  ///    - Memanggil kembali [_loadRiwayatIzin()] untuk memperbarui tabel riwayat di bawah form.
  /// 6. Jika gagal: Menangkap error dan menampilkan SnackBar merah bertuliskan pesan kegagalan.
  /// 7. Terakhir: Menonaktifkan status kirim (`_isSubmitting = false`).
  Future<void> _submitIzin() async {
    final tglMulai = _tglMulaiController.text;
    final tglSelesai = _tglSelesaiController.text;
    final keterangan = _keteranganController.text;
    if (tglMulai.isEmpty) {
      _showSnackBar('Tanggal mulai harus diisi', isError: true);
      return;
    }
    if (tglSelesai.isNotEmpty &&
        DateTime.parse(tglSelesai).isBefore(DateTime.parse(tglMulai))) {
      _showSnackBar(
        'Tanggal selesai tidak boleh sebelum tanggal mulai',
        isError: true,
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().submitPerizinan(
        tanggalMulai: tglMulai,
        tanggalSelesai: tglSelesai.isEmpty ? tglMulai : tglSelesai,
        jenisIzin: _selectedJenis,
        keterangan: keterangan,
      );
      if (mounted) {
        if (res['success'] == true) {
          _showSnackBar(res['message']?.toString() ?? 'Izin berhasil dikirim');
          _tglMulaiController.clear();
          _tglSelesaiController.clear();
          _keteranganController.clear();
          _loadRiwayatIzin();
        } else {
          _showSnackBar(
            res['message']?.toString() ?? 'Gagal mengirim izin',
            isError: true,
          );
        }
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan koneksi', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Fungsi: Mengubah state saat terjadi kegagalan muat data.
  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  /// Fungsi: Helper untuk menayangkan SnackBar melayang kustom yang elegan.
  /// Parameter: [String msg] (isi pesan), [bool isError] (jika ya, beri warna merah).
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTheme.body.copyWith(color: Colors.white)),
        backgroundColor: isError ? AppTheme.error : AppTheme.bgDarkPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Fungsi: Mengarahkan paksa pengguna ke LoginScreen jika token kedaluwarsa.
  void _redirectLogin() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  /// Fungsi: Menampilkan dialog kalender bawaan untuk memilih tanggal.
  /// Parameter: [TextEditingController controller] (Controller target untuk diisi hasil pilihan tanggal).
  /// Alur: Membuka `showDatePicker` bertema gelap, lalu memformat tanggal yang dipilih menjadi 'yyyy-MM-dd' untuk database.
  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      locale: const Locale('id', 'ID'),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppTheme.bgDarkPurple,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  /// Fungsi: Metode render UI utama layar perizinan.
  /// Alur:
  /// 1. Halaman dibungkus dalam `DarkBackground` premium.
  /// 2. Bagian Atas: Header bertuliskan "Perizinan Murid".
  /// 3. Bagian Body (`SingleChildScrollView` + `RefreshIndicator`):
  ///    - Form Input Baru ([_buildFormCard()]): Panel kaca transparan berisi pilihan tanggal, jenis izin, dan tombol kirim.
  ///    - Header Riwayat ([_buildHistoryHeader()]): Judul riwayat berdampingan dengan Dropdown penyaring bulan.
  ///    - Daftar Riwayat ([_buildRiwayatList()]): Susunan kartu perizinan siswa.
  @override
  Widget build(BuildContext context) {
    return DarkBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Perizinan Murid', style: AppTheme.heading1),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRiwayatIzin,
                color: AppTheme.accent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: 24),
                      _buildHistoryHeader(),
                      const SizedBox(height: 12),
                      _buildRiwayatList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fungsi: Membangun kartu form input pengajuan izin baru bergaya kaca premium.
  /// Alur: Menyusun input tanggal mulai/selesai berdampingan, dropdown jenis izin, kolom deskripsi alasan, dan tombol kirim bergradien.
  Widget _buildFormCard() {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      glowShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajukan Izin Baru',
            style: AppTheme.heading3.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField('Tgl Mulai *', _tglMulaiController),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField('Tgl Selesai', _tglSelesaiController),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown(),
          const SizedBox(height: 16),
          _buildTextArea(),
          const SizedBox(height: 20),
          GradientButton(
            onPressed: _submitIzin,
            isLoading: _isSubmitting,
            child: Text('Kirim Pengajuan', style: AppTheme.button),
          ),
        ],
      ),
    );
  }

  /// Fungsi: Membuat input field aspal (Tap-detector) khusus tanggal yang membuka kalender ketika disentuh.
  Widget _buildDateField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _selectDate(controller),
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            readOnly: true,
            style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: AppTheme.bodySmall,
              prefixIcon: Icon(
                Icons.calendar_today,
                size: 18,
                color: AppTheme.primary.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fungsi: Membangun pilihan dropdown bergaya gelap premium untuk jenis izin.
  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedJenis,
        dropdownColor: AppTheme.bgDarkPurple,
        style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: 'Jenis Izin',
          labelStyle: AppTheme.bodySmall,
          border: InputBorder.none,
        ),
        items: _jenisIzin
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (val) => setState(() => _selectedJenis = val!),
      ),
    );
  }

  /// Fungsi: Membangun kolom area teks masukan berbaris banyak (max 3 baris) untuk keterangan alasan izin.
  Widget _buildTextArea() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _keteranganController,
        maxLines: 3,
        style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: 'Keterangan / Alasan',
          alignLabelWithHint: true,
          labelStyle: AppTheme.bodySmall,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  /// Fungsi: Rangkaian tajuk bagian riwayat yang berisi dropdown filter penyaring bulan.
  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Riwayat Izin', style: AppTheme.heading3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMonthFilter,
              dropdownColor: AppTheme.bgDarkPurple,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
              items: _bulanFilter
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedMonthFilter = val!),
            ),
          ),
        ),
      ],
    );
  }

  /// Fungsi: Memproses list riwayat izin dan memfilternya secara asinkron berdasarkan dropdown bulan aktif.
  /// Alur:
  /// 1. Jika masih loading, tampilkan putaran progres.
  /// 2. Memfilter `_riwayatIzin` berdasarkan kesamaan bulan dari string 'tanggal_mulai' dengan filter terpilih.
  /// 3. Jika hasil filter kosong, tampilkan pesan informatif "Tidak ada data".
  /// 4. Jika ada, susun riwayat menggunakan ListView builder yang memanggil [_buildIzinCard()] untuk setiap item.
  Widget _buildRiwayatList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final filtered = _riwayatIzin.where((item) {
      if (_selectedMonthFilter == 'Semua Bulan') return true;
      final tgl = item['tanggal_mulai']?.toString() ?? '';
      if (tgl.isEmpty) return false;
      try {
        return DateFormat(
              'MMMM',
              'id_ID',
            ).format(DateTime.parse(tgl)).toLowerCase() ==
            _selectedMonthFilter.toLowerCase();
      } catch (_) {
        return false;
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            _errorMessage ?? 'Tidak ada data izin.',
            style: AppTheme.body,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _buildIzinCard(filtered[i]),
    );
  }

  /// Fungsi: Membuat kartu riwayat izin tunggal dengan panel ekspansi detail (ExpansionTile) di dalam `GlassCard`.
  /// Parameter: [Map<String, dynamic> item] (Data peta entitas pengajuan izin).
  /// Alur:
  /// 1. Mengidentifikasi status (Menunggu, Disetujui, Ditolak).
  /// 2. Menentukan warna status (Setuju -> Hijau success, Tunggu -> Kuning warning, Tolak -> Merah error).
  /// 3. Merender judul berupa rentang tanggal dan subtitle jenis izin.
  /// 4. Menyediakan kontainer *badge* status di sebelah kanan.
  /// 5. Ketika kartu di-tap (diekspansi), akan slide-down menyajikan rincian teks alasan dari orang tua, serta alasan penolakan guru jika pengajuan tersebut ditolak.
  Widget _buildIzinCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'Menunggu').toString();
    final tglMulai = item['tanggal_mulai']?.toString() ?? '-';
    final tglSelesai = item['tanggal_selesai']?.toString() ?? '-';
    final tglRange = '$tglMulai s/d $tglSelesai';
    final jenis = item['jenis_izin']?.toString() ?? '-';
    final ket = item['keterangan']?.toString() ?? 'Tidak ada keterangan';
    final alasan = item['alasan_penolakan']?.toString() ?? '';

    Color statusColor = AppTheme.textMuted;
    final sl = status.toLowerCase();
    if (sl.contains('setuju') || sl.contains('disetujui')) {
      statusColor = AppTheme.success;
    }
    if (sl.contains('tunggu') || sl.contains('menunggu')) {
      statusColor = AppTheme.warning;
    }
    if (sl.contains('tolak') || sl.contains('ditolak')) {
      statusColor = AppTheme.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              tglRange,
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(jenis, style: AppTheme.bodySmall),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                status,
                style: AppTheme.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                    Text('Keterangan Anda:', style: AppTheme.label),
                    const SizedBox(height: 4),
                    Text(ket, style: AppTheme.body),
                    if (sl.contains('tolak') && alasan.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Alasan Ditolak:',
                        style: AppTheme.label.copyWith(color: AppTheme.error),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alasan,
                        style: AppTheme.body.copyWith(color: AppTheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
