import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _keyLastIzinStatus = 'last_izin_status';
  static const String _keyLastIzinId = 'last_izin_id';
  static const String _keyLastAgendaNotif = 'last_agenda_notif_ids';

  // Inisialisasi plugin
  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // Minta permission notifikasi (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Tampilkan notifikasi
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ortuconnect_channel',
      'OrtuConnect',
      channelDescription: 'Notifikasi OrtuConnect',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details);
  }

  // Cek perubahan status izin dan tampilkan notif jika berubah
  Future<void> checkIzinStatusChange(String username) async {
    if (username.isEmpty) return;

    try {
      final url = Uri.parse(
          'https://ortuconnect.pbltifnganjuk.com/api/perizinan.php?username=$username');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      final res = jsonDecode(response.body) as Map<String, dynamic>;

      if (res['success'] != true) return;

      final List<dynamic> data = res['data'] as List<dynamic>;
      if (data.isEmpty) return;

      final latestIzin = data.first as Map<String, dynamic>;
      final currentId = latestIzin['id']?.toString() ?? '';
      final currentStatus = latestIzin['status']?.toString() ?? '';
      final jenis = latestIzin['jenis_izin']?.toString() ?? '';

      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_keyLastIzinId) ?? '';
      final lastStatus = prefs.getString(_keyLastIzinStatus) ?? '';

      if (currentId == lastId && currentStatus != lastStatus && lastStatus.isNotEmpty) {
        String title = 'Status Izin Diperbarui';
        String body = '';

        if (currentStatus.toLowerCase().contains('setuju')) {
          title = '✅ Izin Disetujui';
          body = 'Pengajuan izin $jenis kamu telah disetujui.';
        } else if (currentStatus.toLowerCase().contains('tolak')) {
          title = '❌ Izin Ditolak';
          body = 'Pengajuan izin $jenis kamu ditolak.';
        } else {
          body = 'Status izin $jenis berubah menjadi $currentStatus.';
        }

        await showNotification(id: 1, title: title, body: body);
      }

      await prefs.setString(_keyLastIzinId, currentId);
      await prefs.setString(_keyLastIzinStatus, currentStatus);
    } catch (e) {
      // Silent fail
    }
  }

  // Cek agenda mendatang dan tampilkan notif H-1 sampai H-3
  Future<void> checkAgendaMendatang() async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
          'https://ortuconnect.pbltifnganjuk.com/api/admin/agenda.php?month=${now.month}&year=${now.year}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      final res = jsonDecode(response.body) as Map<String, dynamic>;

      if (res['status'] != 'success') return;

      final List<dynamic> data = res['data'] ?? [];
      if (data.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      // Simpan ID agenda yang sudah dinotif agar tidak double notif
      final notifiedIds = prefs.getStringList(_keyLastAgendaNotif) ?? [];

      for (final item in data) {
        final namaKegiatan = item['nama_kegiatan']?.toString() ?? 'Kegiatan';
        final tanggalStr = item['tanggal']?.toString() ?? '';
        final agendaId = item['id']?.toString() ?? tanggalStr;

        if (tanggalStr.isEmpty) continue;

        DateTime? agendaDate;
        try {
          agendaDate = DateTime.parse(tanggalStr);
        } catch (_) {
          continue;
        }

        final diff = agendaDate.difference(DateTime(now.year, now.month, now.day)).inDays;

        // Notif hanya untuk H-1, H-2, H-3
        if (diff >= 1 && diff <= 3) {
          final notifKey = '${agendaId}_H$diff';

          // Cek apakah sudah pernah dinotif
          if (!notifiedIds.contains(notifKey)) {
            String title = '';
            String body = '';

            if (diff == 1) {
              title = '📅 Besok Ada Kegiatan!';
              body = '$namaKegiatan akan berlangsung besok.';
            } else {
              title = '📅 Kegiatan $diff Hari Lagi';
              body = '$namaKegiatan akan berlangsung dalam $diff hari.';
            }

            await showNotification(
              id: agendaId.hashCode + diff,
              title: title,
              body: body,
            );

            notifiedIds.add(notifKey);
          }
        }
      }

      await prefs.setStringList(_keyLastAgendaNotif, notifiedIds);
    } catch (e) {
      // Silent fail
    }
  }

  // Panggil semua pengecekan sekaligus
  Future<void> checkAll(String username) async {
    await checkIzinStatusChange(username);
    await checkAgendaMendatang();
  }
}
