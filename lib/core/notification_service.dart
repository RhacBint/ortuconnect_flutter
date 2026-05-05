import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Handler untuk notifikasi saat app di background/terminated (harus top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const String _keyLastIzinStatus = 'last_izin_status';
  static const String _keyLastIzinId = 'last_izin_id';
  static const String _keyLastAgendaNotif = 'last_agenda_notif_ids';
  static const String _keyFcmToken = 'fcm_token';
  static const String _keyLastAbsensiNotif = 'last_absensi_notif_date';
  static const String _keyLastRekapNotif = 'last_rekap_notif_week';

  // Inisialisasi plugin
  Future<void> init() async {
    // Setup flutter_local_notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);

    // Buat notification channel eksplisit (wajib untuk Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ortuconnect_channel',
      'OrtuConnect',
      description: 'Notifikasi OrtuConnect',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Minta permission notifikasi (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Setup Firebase Messaging
    await _setupFCM();
  }

  Future<void> _setupFCM() async {
    // Minta permission FCM (iOS & Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // Daftarkan background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Ambil dan simpan FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFcmToken, token);
    }

    // Refresh token otomatis
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed: $newToken');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFcmToken, newToken);
    });

    // Notifikasi saat app di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.notification?.title}');
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          id: message.hashCode,
          title: notification.title ?? '',
          body: notification.body ?? '',
        );
      }
    });

    // Notifikasi di-tap saat app di background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification tapped: ${message.notification?.title}');
    });
  }

  // Ambil FCM token yang tersimpan
  Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFcmToken);
  }

  // Tampilkan notifikasi lokal
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
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
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
        if (diff >= 1 && diff <= 3) {
          final notifKey = '${agendaId}_H$diff';
          if (!notifiedIds.contains(notifKey)) {
            final title = diff == 1 ? '📅 Besok Ada Kegiatan!' : '📅 Kegiatan $diff Hari Lagi';
            final body = diff == 1
                ? '$namaKegiatan akan berlangsung besok.'
                : '$namaKegiatan akan berlangsung dalam $diff hari.';
            await showNotification(id: agendaId.hashCode + diff, title: title, body: body);
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

  // Cek absensi hari ini dan notifikasi jika Alpha/Sakit
  Future<void> checkAbsensiHariIni(String idSiswa, String namaSiswa) async {
    if (idSiswa.isEmpty) return;
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Cek apakah sudah pernah notif hari ini
      final prefs = await SharedPreferences.getInstance();
      final lastNotifDate = prefs.getString(_keyLastAbsensiNotif) ?? '';
      if (lastNotifDate == todayStr) return; // sudah notif hari ini

      final bulanStr = now.month.toString().padLeft(2, '0');
      final url = Uri.parse(
          'https://ortuconnect.pbltifnganjuk.com/api/admin/absensi.php?id_siswa=$idSiswa&bulan=${now.year}-$bulanStr');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      final res = jsonDecode(response.body) as Map<String, dynamic>;

      if (res['status'] != 'success') return;

      final List<dynamic> riwayat = res['riwayat'] ?? [];
      if (riwayat.isEmpty) return;

      // Cari absensi hari ini
      for (final item in riwayat) {
        if (item is! Map<String, dynamic>) continue;
        final tanggal = item['tanggal']?.toString() ?? '';
        if (tanggal != todayStr) continue;

        final status = item['status']?.toString().toUpperCase() ?? '';

        String title = '';
        String body = '';

        if (status == 'ALPHA' || status == 'ALPA') {
          title = '⚠️ Ketidakhadiran Siswa';
          body = '$namaSiswa tidak hadir di sekolah hari ini (Alpha).';
        } else if (status == 'SAKIT') {
          title = '🤒 Siswa Sakit';
          body = '$namaSiswa tidak hadir hari ini karena sakit.';
        } else if (status == 'IZIN') {
          title = '📋 Siswa Izin';
          body = '$namaSiswa tidak hadir hari ini karena izin.';
        } else if (status == 'HADIR') {
          // Tidak perlu notifikasi kalau hadir
          await prefs.setString(_keyLastAbsensiNotif, todayStr);
          return;
        }

        if (title.isNotEmpty) {
          await showNotification(
            id: 200,
            title: title,
            body: body,
          );
          await prefs.setString(_keyLastAbsensiNotif, todayStr);
        }
        break;
      }
    } catch (e) {
      // Silent fail
    }
  }

  // Rekap mingguan — muncul setiap Jumat saat app dibuka
  Future<void> checkRekapMingguan(String idSiswa, String namaSiswa) async {
    if (idSiswa.isEmpty) return;
    try {
      final now = DateTime.now();

      // Hanya jalankan di hari Jumat (weekday == 5)
      if (now.weekday != DateTime.friday) return;

      // Hitung nomor minggu tahun ini sebagai key unik
      final weekKey = '${now.year}-W${_weekNumber(now)}';

      final prefs = await SharedPreferences.getInstance();
      final lastWeek = prefs.getString(_keyLastRekapNotif) ?? '';
      if (lastWeek == weekKey) return; // sudah notif minggu ini

      // Ambil data absensi bulan ini
      final bulanStr = now.month.toString().padLeft(2, '0');
      final url = Uri.parse(
          'https://ortuconnect.pbltifnganjuk.com/api/admin/absensi.php?id_siswa=$idSiswa&bulan=${now.year}-$bulanStr');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      final res = jsonDecode(response.body) as Map<String, dynamic>;

      if (res['status'] != 'success') return;

      final List<dynamic> riwayat = res['riwayat'] ?? [];
      if (riwayat.isEmpty) return;

      // Hitung kehadiran minggu ini (Senin s/d Jumat)
      final senin = now.subtract(Duration(days: now.weekday - 1));
      final jumat = senin.add(const Duration(days: 4));

      int hadir = 0, alpha = 0, sakit = 0, izin = 0, totalHari = 0;

      for (final item in riwayat) {
        if (item is! Map<String, dynamic>) continue;
        final tanggalStr = item['tanggal']?.toString() ?? '';
        if (tanggalStr.isEmpty) continue;

        DateTime? tgl;
        try {
          tgl = DateTime.parse(tanggalStr);
        } catch (_) {
          continue;
        }

        // Hanya hitung hari dalam minggu ini
        final tglOnly = DateTime(tgl.year, tgl.month, tgl.day);
        final seninOnly = DateTime(senin.year, senin.month, senin.day);
        final jumatOnly = DateTime(jumat.year, jumat.month, jumat.day);

        if (tglOnly.isBefore(seninOnly) || tglOnly.isAfter(jumatOnly)) continue;

        totalHari++;
        final status = item['status']?.toString().toUpperCase() ?? '';
        if (status == 'HADIR') {
          hadir++;
        } else if (status == 'ALPHA' || status == 'ALPA') {
          alpha++;
        } else if (status == 'SAKIT') {
          sakit++;
        } else if (status == 'IZIN') {
          izin++;
        }
      }

      if (totalHari == 0) return;

      // Susun pesan rekap
      final StringBuffer body = StringBuffer();
      body.write('Hadir: $hadir hari');
      if (alpha > 0) body.write(' | Alpha: $alpha');
      if (sakit > 0) body.write(' | Sakit: $sakit');
      if (izin > 0) body.write(' | Izin: $izin');

      String title;
      if (hadir == totalHari) {
        title = '🌟 Rekap Minggu Ini — $namaSiswa';
        body.write('\nKehadiran sempurna minggu ini!');
      } else if (alpha > 0) {
        title = '📊 Rekap Minggu Ini — $namaSiswa';
        body.write('\nAda ketidakhadiran tanpa keterangan.');
      } else {
        title = '📊 Rekap Minggu Ini — $namaSiswa';
      }

      await showNotification(id: 300, title: title, body: body.toString());
      await prefs.setString(_keyLastRekapNotif, weekKey);
    } catch (e) {
      // Silent fail
    }
  }

  // Helper: hitung nomor minggu dalam tahun
  int _weekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final diff = date.difference(startOfYear).inDays;
    return ((diff + startOfYear.weekday - 1) / 7).ceil();
  }
}
