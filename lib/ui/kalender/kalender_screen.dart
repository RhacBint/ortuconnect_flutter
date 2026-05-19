import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';

class AgendaItem {
  final String namaKegiatan;
  final String tanggal;
  final String deskripsi;
  AgendaItem({required this.namaKegiatan, required this.tanggal, required this.deskripsi});
}

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({super.key});
  @override
  State<KalenderScreen> createState() => _KalenderScreenState();
}

class _KalenderScreenState extends State<KalenderScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = false;
  String _errorMessage = '';
  List<AgendaItem> _agendaList = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAgenda(_focusedDay.month, _focusedDay.year);
  }

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

        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        tempList.removeWhere((item) {
          try { return DateFormat('yyyy-MM-dd').parse(item.tanggal).isBefore(today); }
          catch (_) { return false; }
        });
        tempList.sort((a, b) {
          try { return DateFormat('yyyy-MM-dd').parse(a.tanggal)
              .compareTo(DateFormat('yyyy-MM-dd').parse(b.tanggal)); }
          catch (_) { return 0; }
        });

        setState(() {
          _agendaList = tempList;
          if (_agendaList.isEmpty) _errorMessage = 'Tidak ada kegiatan mendatang di bulan ini';
        });
      } else {
        setState(() { _agendaList = []; _errorMessage = 'Tidak ada agenda di bulan ini'; });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _agendaList = []; _errorMessage = e.message; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _agendaList = []; _errorMessage = 'Gagal memuat agenda. Periksa koneksi.'; });
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  String _formatTanggal(String s) {
    try { return DateFormat("dd MMMM yyyy", "id_ID").format(DateFormat("yyyy-MM-dd").parse(s)); }
    catch (e) { return s; }
  }

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
            // Calendar
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
            const SizedBox(height: 16),
            // Agenda list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _agendaList.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.event_busy_rounded, color: AppTheme.textMuted, size: 56),
                          const SizedBox(height: 12),
                          Text(_errorMessage, style: AppTheme.body, textAlign: TextAlign.center),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _agendaList.length,
                          itemBuilder: (ctx, i) => _buildAgendaCard(_agendaList[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

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
}
