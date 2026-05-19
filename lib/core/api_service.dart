import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_database.dart';

/// Satu tempat untuk semua konfigurasi dan request ke Laravel API
class ApiService {
  // URL Laravel API production (Hostinger)
  static const String baseUrl = 'https://ortuconnect.pbltifnganjuk.com/api';

  static const String _keyToken    = 'auth_token';
  static const String _keyUsername = 'username';
  static const String _keyIdSiswa  = 'id_siswa';
  static const String _keyRole     = 'role';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ─── Token helpers ────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> saveSession({
    required String token,
    required String username,
    required String idSiswa,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,    token);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyIdSiswa,  idSiswa);
    await prefs.setString(_keyRole,     role);
    await prefs.setBool('isLoggedIn',   true);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await NotificationDatabase().deleteAll();
      debugPrint('Local SQLite notification history cleared successfully on clearSession');
    } catch (e) {
      debugPrint('Failed to clear local notification history: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Header builder ───────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Response handler ─────────────────────────────────────────────────────

  /// Kembalikan body sebagai Map, atau throw ApiException
  Map<String, dynamic> _handle(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Response bukan JSON (misal server down, error HTML)
      throw ApiException(
        'Server tidak merespons dengan benar (${response.statusCode})',
        response.statusCode,
      );
    }
    if (response.statusCode == 401) {
      throw ApiException(body['message']?.toString() ?? 'Sesi habis, silakan login ulang.', 401);
    }
    if (response.statusCode == 403) {
      throw ApiException(body['message']?.toString() ?? 'Akses ditolak.', 403);
    }
    if (response.statusCode >= 400) {
      throw ApiException(body['message']?.toString() ?? 'Terjadi kesalahan.', response.statusCode);
    }
    return body;
  }

  // ─── Endpoints ────────────────────────────────────────────────────────────

  /// POST /api/login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 30));
    return _handle(response);
  }

  /// POST /api/logout
  Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http.post(Uri.parse('$baseUrl/logout'), headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Logout API error (ignored): $e');
    } finally {
      await clearSession();
    }
  }

  /// GET /api/profile
  Future<Map<String, dynamic>> getProfile() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/profile'), headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// POST /api/profile
  Future<Map<String, dynamic>> updateProfile(Map<String, String> data) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/profile'),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// POST /api/upload-photo (multipart)
  Future<Map<String, dynamic>> uploadPhoto(String filePath) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-photo'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('foto', filePath));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  /// GET /api/dashboard
  Future<Map<String, dynamic>> getDashboard(String idSiswa) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/dashboard').replace(
      queryParameters: {'id_siswa': idSiswa},
    );
    final response = await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// GET /api/absensi?id_siswa=&bulan=YYYY-MM
  Future<Map<String, dynamic>> getAbsensi(String idSiswa, String bulan) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/absensi').replace(
      queryParameters: {'id_siswa': idSiswa, 'bulan': bulan},
    );
    final response = await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// GET /api/perizinan
  Future<Map<String, dynamic>> getPerizinan() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/perizinan'), headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// POST /api/perizinan
  Future<Map<String, dynamic>> submitPerizinan({
    required String tanggalMulai,
    required String tanggalSelesai,
    required String jenisIzin,
    String keterangan = '',
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/perizinan'),
      headers: headers,
      body: jsonEncode({
        'tanggal_mulai':  tanggalMulai,
        'tanggal_selesai': tanggalSelesai,
        'jenis_izin':     jenisIzin,
        'keterangan':     keterangan,
      }),
    ).timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// GET /api/perizinan/status
  Future<Map<String, dynamic>> getPerizinanStatus({String? idIzin}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/perizinan/status').replace(
      queryParameters: idIzin != null ? {'id_izin': idIzin} : null,
    );
    final response = await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));
    return _handle(response);
  }

  /// GET /api/agenda?month=&year=
  Future<Map<String, dynamic>> getAgenda(int month, int year) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/agenda').replace(
      queryParameters: {'month': '$month', 'year': '$year'},
    );
    final response = await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handle(response);
  }

  /// GET /api/agenda/mendatang
  Future<Map<String, dynamic>> getAgendaMendatang() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/agenda/mendatang'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
    return _handle(response);
  }

  /// POST /api/fcm-token
  Future<void> saveFcmToken(String fcmToken) async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('saveFcmToken error: $e');
    }
  }

  /// GET /api/notifications
  /// Mengambil semua riwayat notifikasi dari server
  Future<List<NotificationItem>> getNotifications() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: headers,
    ).timeout(const Duration(seconds: 15));
    
    final body = _handle(response);
    final List data = body['data'] ?? [];
    return data.map((json) => NotificationItem.fromJson(json)).toList();
  }

  /// PUT /api/notifications/{id}/read
  /// Menandai satu notifikasi sebagai sudah dibaca
  Future<void> markNotificationRead(int id) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
    _handle(response);
  }

  /// PUT /api/notifications/read-all
  /// Menandai semua notifikasi sebagai sudah dibaca
  Future<void> markAllNotificationsRead() async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
    _handle(response);
  }

  /// DELETE /api/notifications/{id}
  /// Menghapus notifikasi tertentu dari server
  Future<void> deleteNotification(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/notifications/$id'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
    _handle(response);
  }

  /// Foto URL lengkap dari path relatif server
  static String photoUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';

    String finalUrl = '';

    // Jika sudah full URL (berawalan http)
    if (relativePath.startsWith('http')) {
      // Pastikan menggunakan https jika baseUrl menggunakan https untuk menghindari 'Mixed Content'
      if (baseUrl.startsWith('https://') && relativePath.startsWith('http://')) {
        finalUrl = relativePath.replaceFirst('http://', 'https://');
      } else {
        finalUrl = relativePath;
      }
    } else {
      // Jika path relatif, gabungkan dengan origin dari baseUrl
      final origin = baseUrl.replaceFirst('/api', '');
      String cleanPath = relativePath.startsWith('/') ? relativePath : '/$relativePath';
      finalUrl = '$origin$cleanPath';
    }

    // Tambahkan timestamp sebagai cache buster agar foto langsung berubah saat diupdate
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return finalUrl.contains('?') ? '$finalUrl&t=$timestamp' : '$finalUrl?t=$timestamp';
  }
}

/// Exception khusus untuk error dari API
class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
