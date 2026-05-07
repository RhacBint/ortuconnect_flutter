import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';
import '../login/login_screen.dart';

class PerizinanScreen extends StatefulWidget {
  const PerizinanScreen({super.key});

  @override
  State<PerizinanScreen> createState() => _PerizinanScreenState();
}

class _PerizinanScreenState extends State<PerizinanScreen> with WidgetsBindingObserver {
  final TextEditingController _tglMulaiController    = TextEditingController();
  final TextEditingController _tglSelesaiController  = TextEditingController();
  final TextEditingController _keteranganController  = TextEditingController();

  String _selectedJenis = 'Sakit';
  final List<String> _jenisIzin = ['Sakit', 'Izin'];

  String _selectedMonthFilter = 'Semua Bulan';
  final List<String> _bulanFilter = [
    'Semua Bulan', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  bool _isLoading   = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<dynamic> _riwayatIzin = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRiwayatIzin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tglMulaiController.dispose();
    _tglSelesaiController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadRiwayatIzin();
  }

  Future<void> _loadRiwayatIzin() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final res = await ApiService().getPerizinan();
      if (res['success'] == true) {
        _riwayatIzin = (res['data'] as List<dynamic>?) ?? [];
        if (mounted) setState(() { _isLoading = false; _errorMessage = null; });
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

  Future<void> _submitIzin() async {
    final tglMulai   = _tglMulaiController.text;
    final tglSelesai = _tglSelesaiController.text;
    final keterangan = _keteranganController.text;

    if (tglMulai.isEmpty) {
      _showSnackBar('Tanggal mulai harus diisi', isError: true);
      return;
    }
    if (tglSelesai.isNotEmpty) {
      if (DateTime.parse(tglSelesai).isBefore(DateTime.parse(tglMulai))) {
        _showSnackBar('Tanggal selesai tidak boleh sebelum tanggal mulai', isError: true);
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().submitPerizinan(
        tanggalMulai:  tglMulai,
        tanggalSelesai: tglSelesai.isEmpty ? tglMulai : tglSelesai,
        jenisIzin:     _selectedJenis,
        keterangan:    keterangan,
      );
      if (mounted) {
        if (res['success'] == true) {
          _showSnackBar(res['message']?.toString() ?? 'Izin berhasil dikirim');
          _tglMulaiController.clear();
          _tglSelesaiController.clear();
          _keteranganController.clear();
          _loadRiwayatIzin();
        } else {
          _showSnackBar(res['message']?.toString() ?? 'Gagal mengirim izin', isError: true);
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

  void _setError(String msg) {
    if (mounted) setState(() { _isLoading = false; _errorMessage = msg; });
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF45287F),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _redirectLogin() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) controller.text = DateFormat('yyyy-MM-dd').format(picked);
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
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Perizinan Siswa',
                    style: TextStyle(color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRiwayatIzin,
                color: const Color(0xFF68327E),
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

  Widget _buildFormCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajukan Izin Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF45287F))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDateField('Tgl Mulai *', _tglMulaiController)),
                const SizedBox(width: 12),
                Expanded(child: _buildDateField('Tgl Selesai', _tglSelesaiController)),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedJenis,
              decoration: const InputDecoration(labelText: 'Jenis Izin', border: OutlineInputBorder()),
              items: _jenisIzin.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedJenis = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keteranganController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Keterangan / Alasan',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitIzin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53BBF7),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Kirim Pengajuan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectDate(controller),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today, size: 18),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Riwayat Izin',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMonthFilter,
              dropdownColor: const Color(0xFF45287F),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildRiwayatList() {
    if (_isLoading) {
      return const Center(
          child: Padding(padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.white)));
    }

    final filtered = _riwayatIzin.where((item) {
      if (_selectedMonthFilter == 'Semua Bulan') return true;
      final tgl = item['tanggal_mulai']?.toString() ?? '';
      if (tgl.isEmpty) return false;
      try {
        final date = DateTime.parse(tgl);
        return DateFormat('MMMM', 'id_ID').format(date).toLowerCase() ==
            _selectedMonthFilter.toLowerCase();
      } catch (_) { return false; }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(_errorMessage ?? 'Tidak ada data izin.',
              style: const TextStyle(color: Colors.white70)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildIzinCard(filtered[index]),
    );
  }

  Widget _buildIzinCard(Map<String, dynamic> item) {
    final status      = (item['status'] ?? 'Menunggu').toString();
    final tglMulai    = item['tanggal_mulai']?.toString() ?? '-';
    final tglSelesai  = item['tanggal_selesai']?.toString() ?? '-';
    final tglRange    = '$tglMulai s/d $tglSelesai';
    final jenis       = item['jenis_izin']?.toString() ?? '-';
    final ket         = item['keterangan']?.toString() ?? 'Tidak ada keterangan';
    final alasan      = item['alasan_penolakan']?.toString() ?? '';

    Color statusColor = Colors.grey;
    final sl = status.toLowerCase();
    if (sl.contains('setuju') || sl.contains('disetujui')) statusColor = const Color(0xFF4CAF50);
    if (sl.contains('tunggu') || sl.contains('menunggu')) statusColor = const Color(0xFFFFC107);
    if (sl.contains('tolak') || sl.contains('ditolak')) statusColor = const Color(0xFFF44336);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(tglRange,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(jenis, style: const TextStyle(color: Colors.black54)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor),
          ),
          child: Text(status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text('Keterangan Anda:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(ket),
                if (sl.contains('tolak') && alasan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Alasan Ditolak:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(alasan, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
