import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';
import '../login/login_screen.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});
  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _listAbsensi = [];
  String _idSiswa = '';
  late int _selectedYear;
  late int _selectedMonth;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadAbsensi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAbsensi();
  }

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

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  Map<String, int> _getStats() {
    int hadir = 0, izin = 0, sakit = 0, alpha = 0;
    for (final item in _listAbsensi) {
      final s = item['status']?.toString().toUpperCase() ?? '';
      if (s == 'HADIR') {
        hadir++;
      } else if (s == 'IZIN')
        izin++;
      else if (s == 'SAKIT')
        sakit++;
      else if (s == 'ALPHA' || s == 'ALPA')
        alpha++;
    }
    return {'hadir': hadir, 'izin': izin, 'sakit': sakit, 'alpha': alpha};
  }

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
