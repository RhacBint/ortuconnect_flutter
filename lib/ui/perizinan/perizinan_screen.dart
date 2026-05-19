import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';
import '../login/login_screen.dart';

class PerizinanScreen extends StatefulWidget {
  const PerizinanScreen({super.key});
  @override
  State<PerizinanScreen> createState() => _PerizinanScreenState();
}

class _PerizinanScreenState extends State<PerizinanScreen> with WidgetsBindingObserver {
  final TextEditingController _tglMulaiController = TextEditingController();
  final TextEditingController _tglSelesaiController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  String _selectedJenis = 'Sakit';
  final List<String> _jenisIzin = ['Sakit', 'Izin'];

  String _selectedMonthFilter = 'Semua Bulan';
  final List<String> _bulanFilter = [
    'Semua Bulan', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<dynamic> _riwayatIzin = [];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _loadRiwayatIzin(); }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tglMulaiController.dispose(); _tglSelesaiController.dispose(); _keteranganController.dispose();
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
    } catch (e) { _setError('Gagal memuat riwayat izin'); }
  }

  Future<void> _submitIzin() async {
    final tglMulai = _tglMulaiController.text;
    final tglSelesai = _tglSelesaiController.text;
    final keterangan = _keteranganController.text;
    if (tglMulai.isEmpty) { _showSnackBar('Tanggal mulai harus diisi', isError: true); return; }
    if (tglSelesai.isNotEmpty && DateTime.parse(tglSelesai).isBefore(DateTime.parse(tglMulai))) {
      _showSnackBar('Tanggal selesai tidak boleh sebelum tanggal mulai', isError: true); return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().submitPerizinan(
        tanggalMulai: tglMulai, tanggalSelesai: tglSelesai.isEmpty ? tglMulai : tglSelesai,
        jenisIzin: _selectedJenis, keterangan: keterangan,
      );
      if (mounted) {
        if (res['success'] == true) {
          _showSnackBar(res['message']?.toString() ?? 'Izin berhasil dikirim');
          _tglMulaiController.clear(); _tglSelesaiController.clear(); _keteranganController.clear();
          _loadRiwayatIzin();
        } else { _showSnackBar(res['message']?.toString() ?? 'Gagal mengirim izin', isError: true); }
      }
    } on ApiException catch (e) { _showSnackBar(e.message, isError: true); }
    catch (e) { _showSnackBar('Terjadi kesalahan koneksi', isError: true); }
    finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  void _setError(String msg) { if (mounted) setState(() { _isLoading = false; _errorMessage = msg; }); }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppTheme.body.copyWith(color: Colors.white)),
      backgroundColor: isError ? AppTheme.error : AppTheme.bgDarkPurple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _redirectLogin() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime(2101),
      locale: const Locale('id', 'ID'),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.primary, surface: AppTheme.bgDarkPurple),
        ), child: child!),
    );
    if (picked != null) controller.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  @override
  Widget build(BuildContext context) {
    return DarkBackground(
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Perizinan Siswa', style: AppTheme.heading1)),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRiwayatIzin, color: AppTheme.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  _buildFormCard(), const SizedBox(height: 24),
                  _buildHistoryHeader(), const SizedBox(height: 12),
                  _buildRiwayatList(), const SizedBox(height: 100),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFormCard() {
    return GlassCard(
      borderRadius: 20, padding: const EdgeInsets.all(20),
      glowShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Ajukan Izin Baru', style: AppTheme.heading3.copyWith(color: AppTheme.primary)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildDateField('Tgl Mulai *', _tglMulaiController)),
          const SizedBox(width: 12),
          Expanded(child: _buildDateField('Tgl Selesai', _tglSelesaiController)),
        ]),
        const SizedBox(height: 16),
        _buildDropdown(),
        const SizedBox(height: 16),
        _buildTextArea(),
        const SizedBox(height: 20),
        GradientButton(
          onPressed: _submitIzin, isLoading: _isSubmitting,
          child: Text('Kirim Pengajuan', style: AppTheme.button),
        ),
      ]),
    );
  }

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
            controller: controller, readOnly: true,
            style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: label, labelStyle: AppTheme.bodySmall,
              prefixIcon: Icon(Icons.calendar_today, size: 18, color: AppTheme.primary.withValues(alpha: 0.7)),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedJenis, dropdownColor: AppTheme.bgDarkPurple,
        style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(labelText: 'Jenis Izin', labelStyle: AppTheme.bodySmall, border: InputBorder.none),
        items: _jenisIzin.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) => setState(() => _selectedJenis = val!),
      ),
    );
  }

  Widget _buildTextArea() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _keteranganController, maxLines: 3,
        style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: 'Keterangan / Alasan', alignLabelWithHint: true,
          labelStyle: AppTheme.bodySmall, border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
            value: _selectedMonthFilter, dropdownColor: AppTheme.bgDarkPurple,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600),
            items: _bulanFilter.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _selectedMonthFilter = val!),
          ),
        ),
      ),
    ]);
  }

  Widget _buildRiwayatList() {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20),
      child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    final filtered = _riwayatIzin.where((item) {
      if (_selectedMonthFilter == 'Semua Bulan') return true;
      final tgl = item['tanggal_mulai']?.toString() ?? '';
      if (tgl.isEmpty) return false;
      try { return DateFormat('MMMM', 'id_ID').format(DateTime.parse(tgl)).toLowerCase() ==
          _selectedMonthFilter.toLowerCase(); } catch (_) { return false; }
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(40),
        child: Text(_errorMessage ?? 'Tidak ada data izin.', style: AppTheme.body)));
    }

    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length, itemBuilder: (ctx, i) => _buildIzinCard(filtered[i]),
    );
  }

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
    if (sl.contains('setuju') || sl.contains('disetujui')) statusColor = AppTheme.success;
    if (sl.contains('tunggu') || sl.contains('menunggu')) statusColor = AppTheme.warning;
    if (sl.contains('tolak') || sl.contains('ditolak')) statusColor = AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16, padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(tglRange, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(jenis, style: AppTheme.bodySmall),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(status, style: AppTheme.bodySmall.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
            ),
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  Text('Keterangan Anda:', style: AppTheme.label),
                  const SizedBox(height: 4),
                  Text(ket, style: AppTheme.body),
                  if (sl.contains('tolak') && alasan.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Alasan Ditolak:', style: AppTheme.label.copyWith(color: AppTheme.error)),
                    const SizedBox(height: 4),
                    Text(alasan, style: AppTheme.body.copyWith(color: AppTheme.error)),
                  ],
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
