import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';

/// Model Data [AgendaItem]
/// 
/// Fungsi: Merepresentasikan objek data tunggal dari suatu agenda/kegiatan sekolah.
/// Atribut: nama kegiatan, tanggal, dan deskripsi kegiatan.
class AgendaItem {
  final String namaKegiatan;
  final String tanggal;
  final String deskripsi;
  AgendaItem({required this.namaKegiatan, required this.tanggal, required this.deskripsi});
}

/// Halaman KalenderScreen [StatefulWidget]
/// 
/// Fungsi: Menampilkan kalender kegiatan interaktif bulanan serta daftar agenda sekolah.
/// Alur: Memanggil State [_KalenderScreenState] untuk memuat agenda berdasarkan bulan & tahun kalender aktif.
class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});

  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

/// State [_KalenderScreenState] dengan [WidgetsBindingObserver]
/// 
/// Fungsi: Mengelola TableCalendar, memilah agenda mendatang/lampau,
/// memperbarui jumlah badge, dan merender kartu agenda (*GlassCard*).
/// Alur: Memantau siklus hidup aplikasi. Ketika kembali aktif (*resumed*),
/// ia otomatis melakukan *fetch* ulang untuk memastikan data agenda up-to-date.
class _KalenderScreenState extends State<KalenderScreen> with WidgetsBindingObserver {
  // Tanggal yang sedang ditampilkan di kalender
  DateTime _focusedDay = DateTime.now();
  
  // Tanggal yang dipilih oleh pengguna di grid kalender
  DateTime? _selectedDay;
  
  // Status loading untuk mengambil data agenda
  bool _isLoading = false;
  
  // Pesan error jika gagal memuat data
  String _errorMessage = '';
  
  // List agenda terfilter yang akan ditampilkan di layar
  List<AgendaItem> _agendaList = [];
  
  // Tab terpilih untuk filter daftar kegiatan ('upcoming' / 'past')
  String _selectedTab = 'upcoming';
  
  // Akumulasi jumlah kegiatan mendatang di bulan aktif
  int _upcomingCount = 0;
  
  // Akumulasi jumlah kegiatan lampau di bulan aktif
  int _pastCount = 0;
  
  // Seluruh daftar kegiatan di bulan aktif (belum terfilter)
  List<AgendaItem> _allAgendaList = [];

  /// Fungsi: Inisialisasi awal State kalender
  /// Alur:
  /// 1. Menambahkan observer siklus hidup aplikasi.
  /// 2. Mengatur tanggal default terpilih ke hari ini.
  /// 3. Memanggil [_fetchAgenda()] untuk bulan & tahun saat ini.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _focusedDay;
    _fetchAgenda(_focusedDay.month, _focusedDay.year);
  }

  /// Fungsi: Pembersihan resource State
  /// Alur: Melepas observer siklus hidup aplikasi.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fungsi: Callback ketika status siklus hidup aplikasi berubah
  /// Alur: Jika aplikasi kembali dari background, otomatis refresh agenda.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchAgenda(_focusedDay.month, _focusedDay.year);
    }
  }

  /// Fungsi: Mengambil data agenda sekolah dari server API berdasarkan bulan dan tahun terpilih.
  /// Alur:
  /// 1. Menyalakan status loading spinner (`_isLoading = true`).
  /// 2. Memanggil API `ApiService().getAgenda(month, year)`.
  /// 3. Jika respon sukses (`success == true`):
  ///    - Memetakan array JSON hasil API ke dalam list objek `AgendaItem`.
  ///    - Mengurutkan agenda berdasarkan tanggal secara ascending (dari awal bulan ke akhir bulan).
  ///    - Memanggil [_filterAgenda()] untuk memilah data berdasarkan tab yang aktif.
  /// 4. Jika respon gagal atau error koneksi: Mengosongkan data dan menyajikan pesan error.
  Future<void> _fetchAgenda(int month, int year) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final res = await ApiService().getAgenda(month, year);
      if (!mounted) return;
      if (res['success'] == true) {
        final raw = res['data'];
        List<dynamic> data = [];
        if (raw is Map) { data = (raw['agenda'] as List<dynamic>?) ?? []; }
        else if (raw is List) { data = raw; }

        List<AgendaItem> tempList = data.map((obj) => AgendaItem(
          namaKegiatan: obj['nama_kegiatan']?.toString() ?? 'Tanpa Judul',
          tanggal: obj['tanggal']?.toString() ?? '',
          deskripsi: obj['deskripsi']?.toString() ?? '',
        )).toList();

        tempList.sort((a, b) {
          try { return DateFormat('yyyy-MM-dd').parse(a.tanggal)
              .compareTo(DateFormat('yyyy-MM-dd').parse(b.tanggal)); }
          catch (_) { return 0; }
        });

        _allAgendaList = tempList;
        _filterAgenda();
      } else {
        setState(() {
          _allAgendaList = [];
          _agendaList = [];
          _upcomingCount = 0;
          _pastCount = 0;
          _errorMessage = 'Tidak ada agenda di bulan ini';
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _allAgendaList = [];
        _agendaList = [];
        _upcomingCount = 0;
        _pastCount = 0;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allAgendaList = [];
        _agendaList = [];
        _upcomingCount = 0;
        _pastCount = 0;
        _errorMessage = 'Gagal memuat agenda. Periksa koneksi.';
      });
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  /// Fungsi: Memfilter seluruh agenda sekolah menjadi agenda mendatang (upcoming) atau lampau (past).
  /// Alur:
  /// 1. Menentukan tanggal hari ini (tanpa jam/menit).
  /// 2. Menghitung jumlah agenda mendatang (`_upcomingCount`) dengan memfilter tanggal agenda >= hari ini.
  /// 3. Menghitung jumlah agenda lampau (`_pastCount`) dengan sisa total agenda.
  /// 4. Jika tab aktif 'upcoming':
  ///    - Memfilter agenda dengan tanggal >= hari ini.
  ///    - Mengurutkannya dari yang terdekat (soonest first).
  /// 5. Jika tab aktif 'past':
  ///    - Memfilter agenda dengan tanggal < hari ini.
  ///    - Mengurutkannya dari yang paling baru dilewati (newest first).
  /// 6. Mengupdate `_agendaList` di state agar UI merender kartu agenda yang sesuai.
  void _filterAgenda() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    _upcomingCount = _allAgendaList.where((item) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(item.tanggal);
        return !date.isBefore(today);
      } catch (_) {
        return false;
      }
    }).length;
    
    _pastCount = _allAgendaList.length - _upcomingCount;
    
    List<AgendaItem> filteredList = [];
    
    if (_selectedTab == 'upcoming') {
      filteredList = _allAgendaList.where((item) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(item.tanggal);
          return !date.isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();
      
      filteredList.sort((a, b) {
        try { return DateFormat('yyyy-MM-dd').parse(a.tanggal)
            .compareTo(DateFormat('yyyy-MM-dd').parse(b.tanggal)); }
        catch (_) { return 0; }
      });
      
      if (filteredList.isEmpty) {
        _errorMessage = 'Tidak ada kegiatan mendatang di bulan ini';
      } else {
        _errorMessage = '';
      }
    } else {
      filteredList = _allAgendaList.where((item) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(item.tanggal);
          return date.isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();
      
      filteredList.sort((a, b) {
        try { return DateFormat('yyyy-MM-dd').parse(b.tanggal)
            .compareTo(DateFormat('yyyy-MM-dd').parse(a.tanggal)); }
        catch (_) { return 0; }
      });
      
      if (filteredList.isEmpty) {
        _errorMessage = 'Tidak ada riwayat kegiatan di bulan ini';
      } else {
        _errorMessage = '';
      }
    }
    
    setState(() {
      _agendaList = filteredList;
    });
  }

  /// Fungsi: Memformat tanggal string ('yyyy-MM-dd') menjadi penamaan Indonesia ('dd MMMM yyyy').
  String _formatTanggal(String s) {
    try { return DateFormat("dd MMMM yyyy", "id_ID").format(DateFormat("yyyy-MM-dd").parse(s)); }
    catch (e) { return s; }
  }

  /// Fungsi: Metode render UI utama layar kalender.
  /// Alur:
  /// 1. Merender halaman berselimut `DarkBackground`.
  /// 2. Header berisi teks judul 'Kalender Kegiatan'.
  /// 3. Kartu Kalender (`TableCalendar`) di dalam `GlassCard`:
  ///    - Menampilkan kisi-kisi penanggalan bulanan secara visual.
  ///    - Ketika baris kalender digeser ke bulan lain, secara otomatis menembak API [_fetchAgenda] baru.
  /// 4. Tab Switcher Premium: Rangkaian tombol interaktif 'Mendatang' dan 'Lampau' lengkap dengan gelembung badge jumlah agenda.
  /// 5. Daftar Kegiatan (`RefreshIndicator` + `ListView`):
  ///    - Jika loading: Renders spinner putar.
  ///    - Jika data kosong: Renders ikon kalender kosong dan teks error.
  ///    - Jika ada data: Renders susunan kartu kegiatan sekolah menggunakan [_buildAgendaCard()].
  @override
  Widget build(BuildContext context) {
    return DarkBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Text('Kalender Kegiatan', style: AppTheme.heading1),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                borderRadius: 20, padding: const EdgeInsets.only(bottom: 8),
                glowShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6))],
                child: TableCalendar(
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2050, 12, 31),
                  focusedDay: _focusedDay, locale: 'id_ID',
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const { CalendarFormat.month: 'Month' },
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                  },
                  onPageChanged: (focusedDay) {
                    if (focusedDay.month != _focusedDay.month || focusedDay.year != _focusedDay.year) {
                      _focusedDay = focusedDay;
                      _fetchAgenda(focusedDay.month, focusedDay.year);
                    }
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: const BoxDecoration(color: AppTheme.indigo, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                    defaultTextStyle: AppTheme.body.copyWith(color: AppTheme.textPrimary),
                    weekendTextStyle: AppTheme.body.copyWith(color: AppTheme.textSecondary),
                    outsideTextStyle: AppTheme.body.copyWith(color: AppTheme.textMuted),
                    todayTextStyle: AppTheme.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    selectedTextStyle: AppTheme.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: AppTheme.label.copyWith(color: AppTheme.primary),
                    weekendStyle: AppTheme.label.copyWith(color: AppTheme.accent.withValues(alpha: 0.7)),
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true, formatButtonVisible: false,
                    titleTextStyle: AppTheme.heading3.copyWith(color: AppTheme.primary),
                    leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primary),
                    rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        title: 'Mendatang',
                        count: _upcomingCount,
                        isActive: _selectedTab == 'upcoming',
                        onTap: () {
                          setState(() {
                            _selectedTab = 'upcoming';
                            _filterAgenda();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        title: 'Lampau',
                        count: _pastCount,
                        isActive: _selectedTab == 'past',
                        onTap: () {
                          setState(() {
                            _selectedTab = 'past';
                            _filterAgenda();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchAgenda(_focusedDay.month, _focusedDay.year),
                color: AppTheme.accent,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : _agendaList.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: 300,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.event_busy_rounded, color: AppTheme.textMuted, size: 56),
                                    const SizedBox(height: 12),
                                    Text(_errorMessage, style: AppTheme.body, textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _agendaList.length,
                            itemBuilder: (ctx, i) => _buildAgendaCard(_agendaList[i]),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fungsi: Merender baris kartu agenda tunggal yang dihias kaca transparan (Glassmorphism).
  /// Parameter: [AgendaItem item] (Objek data agenda).
  /// Alur: Renders lingkaran penunjuk warna cyan (neon accent), disusul nama kegiatan, tanggal terformat, dan teks deskripsi detail acara jika ada.
  Widget _buildAgendaCard(AgendaItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 16, padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(width: 10, height: 10,
              decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 8)])),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.namaKegiatan, style: AppTheme.bodyLarge),
            const SizedBox(height: 3),
            Text(_formatTanggal(item.tanggal), style: AppTheme.bodySmall.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            if (item.deskripsi.isNotEmpty && item.deskripsi != 'Tidak ada keterangan') ...[
              const SizedBox(height: 6),
              Text(item.deskripsi, style: AppTheme.bodySmall),
            ],
          ])),
        ]),
      ),
    );
  }

  /// Fungsi: Membangun tombol tab khusus yang elegan lengkap dengan animasi warna.
  /// Parameter:
  /// - [String title] (Label tab seperti "Mendatang")
  /// - [int count] (Jumlah kuantitas agenda)
  /// - [bool isActive] (Apakah tab ini sedang aktif terpilih)
  /// - [VoidCallback onTap] (Fungsi aksi saat diklik)
  /// Alur: Menggunakan [AnimatedContainer] untuk transisi gradien warna accent yang mulus ketika berpindah tab.
  Widget _buildTabButton({
    required String title,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: isActive ? AppTheme.accentGradient : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTheme.body.copyWith(
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: AppTheme.label.copyWith(
                      color: isActive ? Colors.white : AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
