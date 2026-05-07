import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'notification_database.dart';
import 'api_service.dart';

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

    // Refresh token otomatis — langsung kirim ke server
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed: $newToken');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFcmToken, newToken);
      // Kirim token baru ke server
      final username = prefs.getString('username') ?? '';
      if (username.isNotEmpty) {
        await _sendTokenToServer(username, newToken);
      }
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

  // Kirim FCM token ke server
  Future<void> _sendTokenToServer(String username, String token) async {
    try {
      await ApiService().saveFcmToken(token);
      debugPrint('FCM token auto-refreshed to server');
    } catch (e) {
      debugPrint('FCM token refresh to server failed: $e');
    }
  }

  // Tampilkan notifikasi lokal dan simpan ke riwayat
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String type = 'fcm',
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

    // Simpan ke riwayat notifikasi
    await NotificationDatabase().insert(NotificationItem(
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
    ));
  }

  // Cek perubahan status izin dan tampilkan notif jika berubah
  Future<void> checkIzinStatusChange(String idSiswa) async {
    if (idSiswa.isEmpty) return;
    try {
      final res = await ApiService().getPerizinanStatus();
      if (res['success'] != true) return;

      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final currentId     = data['id_izin']?.toString() ?? '';
      final currentStatus = data['status']?.toString() ?? '';

      final prefs = await SharedPreferences.getInstance();
      final lastId     = prefs.getString(_keyLastIzinId) ?? '';
      final lastStatus = prefs.getString(_keyLastIzinStatus) ?? '';

      if (currentId == lastId && currentStatus != lastStatus && lastStatus.isNotEmpty) {
        String title = 'Status Izin Diperbarui';
        String body  = 'Status izin berubah menjadi $currentStatus.';
        if (currentStatus.toLowerCase().contains('setuju') || currentStatus.toLowerCase().contains('disetujui')) {
          title = '✅ Izin Disetujui';
          body  = 'Pengajuan izin kamu telah disetujui.';
        } else if (currentStatus.toLowerCase().contains('tolak') || currentStatus.toLowerCase().contains('ditolak')) {
          title = '❌ Izin Ditolak';
          body  = 'Pengajuan izin kamu ditolak.';
        }
        await showNotification(id: 1, title: title, body: body, type: 'izin');
      }

      await prefs.setString(_keyLastIzinId, currentId);
      await prefs.setString(_keyLastIzinStatus, currentStatus);
    } catch (e) {
      // Silent fail
    }
  }

  // Cek agenda mendatang dan tampilkan notif H-0 sampai H-3
  Future<void> checkAgendaMendatang() async {
    try {
      final res = await ApiService().getAgendaMendatang();
      if (res['success'] != true) return;

      final List<dynamic> data = (res['data'] as List<dynamic>?) ?? [];
      if (data.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final notifiedIds = prefs.getStringList(_keyLastAgendaNotif) ?? [];
      final now = DateTime.now();

      for (final item in data) {
        final namaKegiatan = item['nama_kegiatan']?.toString() ?? 'Kegiatan';
        final tanggalStr   = item['tanggal']?.toString() ?? '';
        final agendaId     = item['id_kegiatan']?.toString() ?? tanggalStr;
        if (tanggalStr.isEmpty) continue;

        DateTime? agendaDate;
        try { agendaDate = DateTime.parse(tanggalStr); } catch (_) { continue; }

        final diff = agendaDate.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (diff >= 0 && diff <= 3) {
          final notifKey = '${agendaId}_H$diff';
          if (!notifiedIds.contains(notifKey)) {
            String title;
            String body;
            if (diff == 0) {
              title = '📅 Kegiatan Hari Ini!';
              body  = '$namaKegiatan berlangsung hari ini.';
            } else if (diff == 1) {
              title = '📅 Besok Ada Kegiatan!';
              body  = '$namaKegiatan akan berlangsung besok.';
            } else {
              title = '📅 Kegiatan $diff Hari Lagi';
              body  = '$namaKegiatan akan berlangsung dalam $diff hari.';
            }
            await showNotification(id: agendaId.hashCode + diff, title: title, body: body, type: 'agenda');
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
  Future<void> checkAll(String idSiswa) async {
    await checkIzinStatusChange(idSiswa);
    await checkAgendaMendatang();
  }

  // Cek absensi hari ini dan notifikasi jika Alpha/Sakit
  Future<void> checkAbsensiHariIni(String idSiswa, String namaSiswa) async {
    if (idSiswa.isEmpty) return;
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_keyLastAbsensiNotif) == todayStr) return;

      final bulanStr = now.month.toString().padLeft(2, '0');
      final res = await ApiService().getAbsensi(idSiswa, '${now.year}-$bulanStr');
      if (res['success'] != true) return;

      final data = res['data'] as Map<String, dynamic>?;
      final List<dynamic> absensiList = (data?['absensi'] as List<dynamic>?) ?? [];

      for (final item in absensiList) {
        if (item is! Map<String, dynamic>) continue;
        if (item['tanggal']?.toString() != todayStr) continue;

        final status = item['status']?.toString().toUpperCase() ?? '';
        String title = '', body = '';

        if (status == 'ALPA' || status == 'ALPHA') {
          title = '⚠️ Ketidakhadiran Siswa';
          body  = '$namaSiswa tidak hadir di sekolah hari ini (Alpa).';
        } else if (status == 'SAKIT') {
          title = '🤒 Siswa Sakit';
          body  = '$namaSiswa tidak hadir hari ini karena sakit.';
        } else if (status == 'IZIN') {
          title = '📋 Siswa Izin';
          body  = '$namaSiswa tidak hadir hari ini karena izin.';
        } else {
          await prefs.setString(_keyLastAbsensiNotif, todayStr);
          return;
        }

        if (title.isNotEmpty) {
          await showNotification(id: 200, title: title, body: body, type: 'absensi');
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
      if (now.weekday != DateTime.friday) return;

      final weekKey = '${now.year}-W${_weekNumber(now)}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_keyLastRekapNotif) == weekKey) return;

      final bulanStr = now.month.toString().padLeft(2, '0');
      final res = await ApiService().getAbsensi(idSiswa, '${now.year}-$bulanStr');
      if (res['success'] != true) return;

      final data = res['data'] as Map<String, dynamic>?;
      // Gunakan rekap dari API jika tersedia
      final rekap = data?['rekap'] as Map<String, dynamic>?;
      if (rekap != null) {
        final hadir = int.tryParse(rekap['Hadir']?.toString() ?? '0') ?? 0;
        final alpha = int.tryParse(rekap['Alpa']?.toString() ?? '0') ?? 0;
        final sakit = int.tryParse(rekap['Sakit']?.toString() ?? '0') ?? 0;
        final izin  = int.tryParse(rekap['Izin']?.toString() ?? '0') ?? 0;
        final total = int.tryParse(rekap['total']?.toString() ?? '0') ?? 0;

        if (total == 0) return;

        final sb = StringBuffer('Hadir: $hadir hari');
        if (alpha > 0) sb.write(' | Alpa: $alpha');
        if (sakit > 0) sb.write(' | Sakit: $sakit');
        if (izin  > 0) sb.write(' | Izin: $izin');

        String title;
        if (hadir == total) {
          title = '🌟 Rekap Minggu Ini — $namaSiswa';
          sb.write('\nKehadiran sempurna minggu ini!');
        } else if (alpha > 0) {
          title = '📊 Rekap Minggu Ini — $namaSiswa';
          sb.write('\nAda ketidakhadiran tanpa keterangan.');
        } else {
          title = '📊 Rekap Minggu Ini — $namaSiswa';
        }

        await showNotification(id: 300, title: title, body: sb.toString(), type: 'rekap');
        await prefs.setString(_keyLastRekapNotif, weekKey);
      }
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
