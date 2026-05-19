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
  
  final notification = message.notification;
  if (notification != null) {
    // Simpan ke riwayat notifikasi lokal (Database)
    await NotificationDatabase().insert(NotificationItem(
      title: notification.title ?? 'Pesan Baru',
      body: notification.body ?? '',
      type: message.data['type']?.toString() ?? 'fcm',
      timestamp: DateTime.now(),
    ));
    debugPrint('FCM background message saved to database');
  }
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
      
      // Kirim token ke server jika user sudah login (berguna untuk sinkronisasi ulang saat startup)
      final authToken = prefs.getString('auth_token') ?? '';
      if (authToken.isNotEmpty) {
        await _sendTokenToServer(token);
      }
    }

    // Subscribe ke topic all_users untuk menerima broadcast agenda sekolah
    try {
      await _fcm.subscribeToTopic('all_users');
      debugPrint('FCM: Subscribed to all_users topic');
    } catch (e) {
      debugPrint('FCM: Failed to subscribe to topic: $e');
    }

    // Refresh token otomatis — langsung kirim ke server
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM Token refreshed: $newToken');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFcmToken, newToken);
      // Kirim token baru ke server jika user sudah login
      final authToken = prefs.getString('auth_token') ?? '';
      if (authToken.isNotEmpty) {
        await _sendTokenToServer(newToken);
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
          data: message.data,
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
    String? token = prefs.getString(_keyFcmToken);
    
    // Jika kosong di shared preferences, coba ambil langsung dari Firebase
    if (token == null || token.isEmpty) {
      try {
        token = await _fcm.getToken();
        if (token != null) {
          await prefs.setString(_keyFcmToken, token);
        }
      } catch (e) {
        debugPrint('Error getting FCM token directly: $e');
      }
    }
    return token;
  }

  // Kirim FCM token ke server
  Future<void> _sendTokenToServer(String token) async {
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
    Map<String, dynamic>? data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ortuconnect_channel',
      'OrtuConnect',
      channelDescription: 'Notifikasi OrtuConnect',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);

    // Gunakan tipe dari data payload jika ada
    final String finalType = data?['type']?.toString() ?? type;

    // Simpan ke riwayat notifikasi lokal (Database)
    await NotificationDatabase().insert(NotificationItem(
      title: title,
      body: body,
      type: finalType,
      timestamp: DateTime.now(),
    ));
  }
}
