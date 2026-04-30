import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class AgendaItem {
  final String namaKegiatan;
  final String tanggal;
  final String deskripsi;

  AgendaItem({
    required this.namaKegiatan,
    required this.tanggal,
    required this.deskripsi,
  });
}

class KalenderScreen extends StatefulWidget {
  const KalenderScreen({Key? key}) : super(key: key);

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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final url = Uri.parse(
        'https://ortuconnect.pbltifnganjuk.com/api/admin/agenda.php?month=$month&year=$year');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          List<AgendaItem> tempList = data.map((obj) {
            return AgendaItem(
              namaKegiatan: obj['nama_kegiatan']?.toString() ?? 'Tanpa Judul',
              tanggal: obj['tanggal']?.toString() ?? '',
              deskripsi: obj['deskripsi']?.toString() ?? 'Tidak ada keterangan',
            );
          }).toList();

          // 1. FILTER: Hapus tanggal yang sudah lewat (hanya tampilkan hari ini ke depan)
          DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          
          tempList.removeWhere((item) {
            try {
              DateTime agendaDate = DateFormat("yyyy-MM-dd").parse(item.tanggal);
              return agendaDate.isBefore(today);
            } catch (e) {
              return false; // Tetap pertahankan jika gagal parsing
            }
          });

          // 2. SORT: Terdekat berada di urutan atas (Ascending)
          tempList.sort((a, b) {
            try {
              DateTime dateA = DateFormat("yyyy-MM-dd").parse(a.tanggal);
              DateTime dateB = DateFormat("yyyy-MM-dd").parse(b.tanggal);
              return dateA.compareTo(dateB);
            } catch (e) {
              return 0;
            }
          });

          setState(() {
            _agendaList = tempList;
            // Jika kosong setelah filter
            if (_agendaList.isEmpty) {
              _errorMessage = 'Tidak ada kegiatan (mendatang) di bulan ini';
            }
          });
        } else {
          setState(() {
            _agendaList = [];
            _errorMessage = 'Tidak ada agenda di bulan ini';
          });
        }
      } else {
        setState(() {
          _agendaList = [];
          _errorMessage = 'Gagal memuat agenda: Server Error';
        });
      }
    } catch (e) {
      setState(() {
        _agendaList = [];
        _errorMessage = 'Gagal memuat agenda. Periksa koneksi.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTanggal(String tanggalStr) {
    try {
      DateTime parsedDate = DateFormat("yyyy-MM-dd", "id_ID").parse(tanggalStr);
      return DateFormat("dd MMMM yyyy", "id_ID").format(parsedDate);
    } catch (e) {
      return tanggalStr;
    }
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
            // Header — konsisten dengan halaman lain
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Text(
                'Kalender Kegiatan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            // Kalender
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2050, 12, 31),
                focusedDay: _focusedDay,
                locale: 'id_ID',
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  if (focusedDay.month != _focusedDay.month ||
                      focusedDay.year != _focusedDay.year) {
                    _focusedDay = focusedDay;
                    _fetchAgenda(focusedDay.month, focusedDay.year);
                  }
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Color(0xFF0F53BF),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFF68327E),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    color: Color(0xFF68327E),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Daftar Agenda
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _agendaList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_busy_rounded, color: Colors.white54, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _agendaList.length,
                          itemBuilder: (context, index) {
                            return _buildAgendaCard(_agendaList[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaCard(AgendaItem item) {
    return Container(
      width: double.infinity,
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
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot indikator
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF68327E),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaKegiatan,
                    style: const TextStyle(
                      color: Color(0xFF68327E),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTanggal(item.tanggal),
                    style: const TextStyle(
                      color: Color(0xFF0F53BF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.deskripsi.isNotEmpty && item.deskripsi != 'Tidak ada keterangan') ...[
                    const SizedBox(height: 6),
                    Text(
                      item.deskripsi,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
