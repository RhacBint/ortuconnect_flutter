import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api_service.dart';
import '../login/login_screen.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _listAbsensi = [];
  String _idSiswa = '';

  late int _selectedYear;
  late int _selectedMonth;

  final List<String> _bulanArray = [
    "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember"
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
    if (state == AppLifecycleState.resumed) {
      _loadAbsensi();
    }
  }

  Future<void> _loadAbsensi() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // Ambil id_siswa dari session
      final prefs = await SharedPreferences.getInstance();
      _idSiswa = prefs.getString('id_siswa') ?? '';

      final bulanStr = _selectedMonth.toString().padLeft(2, '0');
      final res = await ApiService().getAbsensi(_idSiswa, '$_selectedYear-$bulanStr');

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final absensiList = data['absensi'] as List<dynamic>? ?? [];
        _listAbsensi = List.from(absensiList);
        _listAbsensi.sort((a, b) =>
            (b['tanggal'] ?? '').compareTo(a['tanggal'] ?? ''));
        if (mounted) setState(() { _isLoading = false; _errorMessage = null; });
      } else {
        _setError(res['message']?.toString() ?? 'Data tidak tersedia');
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
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
    if (mounted) setState(() { _isLoading = false; _errorMessage = msg; });
  }

  // Hitung statistik dari _listAbsensi
  Map<String, int> _getStats() {
    int hadir = 0, izin = 0, sakit = 0, alpha = 0;
    for (final item in _listAbsensi) {
      final status = item['status']?.toString().toUpperCase() ?? '';
      if (status == 'HADIR') {
        hadir++;
      } else if (status == 'IZIN') {
        izin++;
      } else if (status == 'SAKIT') {
        sakit++;
      } else if (status == 'ALPHA' || status == 'ALPA') {
        alpha++;
      }
    }
    return {'hadir': hadir, 'izin': izin, 'sakit': sakit, 'alpha': alpha};
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'HADIR': return const Color(0xFF4CAF50);
      case 'IZIN': return const Color(0xFF2196F3);
      case 'SAKIT': return const Color(0xFFFF9800);
      case 'ALPHA':
      case 'ALPA': return const Color(0xFFF44336);
      default: return Colors.grey;
    }
  }

  String _formatTanggal(String tanggal) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(tanggal.trim());
      return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
    } catch (_) { return tanggal; }
  }

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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Absensi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        isDense: true,
                        style: const TextStyle(
                          color: Color(0xFF0F53BF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        iconEnabledColor: const Color(0xFF0F53BF),
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(_bulanArray[index]),
                          );
                        }),
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

  Widget _buildContent() {
    if (_listAbsensi.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, color: Colors.white54, size: 64),
                SizedBox(height: 12),
                Text(
                  'Tidak ada data absensi\nbulan ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
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
        // Grafik Pie
        _buildChart(),
        const SizedBox(height: 14),
        // List absensi
        ..._listAbsensi.map((item) {
          final status = item['status']?.toString() ?? 'ALPHA';
          final tanggal = item['tanggal']?.toString() ?? '';
          final color = _getStatusColor(status);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatTanggal(tanggal),
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
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
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: color,
        title: '$pct%',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
      labels.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$label ($count)',
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ));
    }

    addSection('Hadir', stats['hadir']!, const Color(0xFF4CAF50));
    addSection('Izin', stats['izin']!, const Color(0xFF2196F3));
    addSection('Sakit', stats['sakit']!, const Color(0xFFFF9800));
    addSection('Alpha', stats['alpha']!, const Color(0xFFF44336));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Statistik ${_bulanArray[_selectedMonth - 1]} $_selectedYear',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF68327E),
            ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...labels.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: l,
                    )),
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
              const Icon(Icons.info_outline, color: Colors.white70, size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: _loadAbsensi,
                child: const Text('Coba Lagi',
                    style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'HADIR': return '✓ Hadir';
      case 'IZIN': return '○ Izin';
      case 'SAKIT': return '+ Sakit';
      case 'ALPHA':
      case 'ALPA': return '✕ Alpha';
      default: return status;
    }
  }
}
