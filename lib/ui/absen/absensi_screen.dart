import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({Key? key}) : super(key: key);

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> with WidgetsBindingObserver {
  // ---------------- API URLs ----------------
  static const String _apiProfile = 'https://ortuconnect.pbltifnganjuk.com/api/profile.php?username=';
  static const String _apiAbsensi = 'https://ortuconnect.pbltifnganjuk.com/api/admin/absensi.php';

  // ---------------- State variables ----------------
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _listAbsensi = [];

  String _username = '';
  String _idSiswa = '';
  
  late int _selectedYear;
  late int _selectedMonth; // 1-12

  final List<String> _bulanArray = [
    "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember"
  ];

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

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
      _loadAbsensi();
    }
  }

  // ---------------- Data Loading ----------------

  Future<void> _loadFromSession() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? '';
    _idSiswa = prefs.getString('id_siswa') ?? '';

    if (_username.isEmpty) return;

    if (_idSiswa.isEmpty) {
      await _loadProfileFirst();
    } else {
      await _loadAbsensi();
    }
  }

  Future<void> _loadProfileFirst() async {
    try {
      final url = Uri.parse('$_apiProfile$_username');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final profileData = data['data'] as Map<String, dynamic>;
        _idSiswa = profileData['id_siswa']?.toString() ?? '';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_siswa', _idSiswa);

        await _loadAbsensi();
      } else {
        _setError('Gagal mendapatkan profil siswa');
      }
    } catch (e) {
      _setError('Koneksi terganggu');
    }
  }

  Future<void> _loadAbsensi() async {
    if (_idSiswa.isEmpty) return;

    try {
      if (mounted) setState(() => _isLoading = true);

      // Format: YYYY-MM
      final bulanStr = _selectedMonth.toString().padLeft(2, '0');
      final url = Uri.parse('$_apiAbsensi?id_siswa=$_idSiswa&bulan=$_selectedYear-$bulanStr');
      debugPrint('Fetching Absensi: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 15));
      final res = jsonDecode(response.body) as Map<String, dynamic>;

      if (res['status'] == 'success') {
        _listAbsensi = res['riwayat'] as List<dynamic>;
        
        // Urutkan tanggal terbaru ke terlama
        _listAbsensi.sort((a, b) => b['tanggal'].compareTo(a['tanggal']));
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        _setError(res['message']?.toString() ?? 'Data tidak tersedia');
      }
    } catch (e) {
      _setError('Gagal memuat data absensi: $e');
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

  // ---------------- Helpers ----------------

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'HADIR': return const Color(0xFF4CAF50);
      case 'IZIN': return const Color(0xFF2196F3);
      case 'SAKIT': return const Color(0xFFF44336);
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
                  // Dropdown bulan di header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAbsensi,
                color: const Color(0xFF68327E),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _buildList(),
              ),
            ),
          ],
        ),
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

  Widget _buildList() {
    if (_listAbsensi.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                const Icon(Icons.event_busy_rounded, color: Colors.white54, size: 64),
                const SizedBox(height: 12),
                const Text(
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

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _listAbsensi.length,
      itemBuilder: (context, index) {
        final item = _listAbsensi[index];
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
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Dot indikator
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
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
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
      },
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
