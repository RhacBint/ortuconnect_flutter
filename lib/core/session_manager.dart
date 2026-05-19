import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'notification_database.dart';

/// Wrapper tipis di atas SharedPreferences untuk data session.
/// Semua operasi login/logout sekarang dilakukan via ApiService.
class SessionManager {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUsername   = 'username';
  static const String _keyUserId     = 'userId';
  static const String _keyUserRole   = 'userRole';
  static const String _keyToken      = 'auth_token';
  static const String _keyIdSiswa    = 'id_siswa';

  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  Future<String?> getIdSiswa() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIdSiswa);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Dipakai oleh ApiService setelah login berhasil
  Future<void> createLoginSession({
    required String token,
    required String username,
    required String userId,
    required String role,
    required String idSiswa,
  }) async {
    debugPrint('createLoginSession: $username / role=$role / id_siswa=$idSiswa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyToken,    token);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyUserId,   userId);
    await prefs.setString(_keyUserRole, role);
    await prefs.setString(_keyIdSiswa,  idSiswa);
  }

  Future<void> logoutUser() async {
    debugPrint('logoutUser called');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await NotificationDatabase().deleteAll();
      debugPrint('Local SQLite notification history cleared successfully on logoutUser');
    } catch (e) {
      debugPrint('Failed to clear local notification history: $e');
    }
  }
}
