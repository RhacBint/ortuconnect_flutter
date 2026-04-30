import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

class SessionManager {
  static const String _keyIsLoggedIn = "isLoggedIn";
  static const String _keyUsername = "username";
  static const String _keyUserId = "userId";
  static const String _keyUserRole = "userRole";

  // Pola Singleton agar mudah diakses di seluruh aplikasi
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal() {
    debugPrint("SessionManager created");
    _initLogging();
  }

  void _initLogging() async {
    final prefs = await SharedPreferences.getInstance();
    _logCurrentSession(prefs);
  }

  /// Simpan session login (mirip createLoginSession di Java)
  Future<void> createLoginSession(String username, String userId, String role) async {
    debugPrint("createLoginSession - username: $username, userId: $userId, role: $role");
    
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserRole, role);
    
    // Anggap selalu sukses (commit() di dart dihandle oleh package)
    debugPrint("Session save result: true");
    _logCurrentSession(prefs);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString(_keyUsername);
    debugPrint("getUsername: $username");
    return username;
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_keyUserId);
    debugPrint("getUserId: $userId");
    return userId;
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString(_keyUserRole);
    debugPrint("getUserRole: $role");
    return role;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    debugPrint("isLoggedIn: $loggedIn");
    return loggedIn;
  }

  Future<void> logoutUser() async {
    debugPrint("logoutUser called");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    debugPrint("Logout result: true"); // di flutter clear() menyelesaikan di background, anggap true
    _logCurrentSession(prefs);
  }

  /// Validasi session - cek apakah data lengkap
  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    
    bool loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    String? username = prefs.getString(_keyUsername);
    String? userId = prefs.getString(_keyUserId);

    bool isUsernameValid = username != null && username.trim().isNotEmpty;
    bool isUserIdValid = userId != null && userId.trim().isNotEmpty;

    bool isValid = loggedIn && isUsernameValid && isUserIdValid;

    debugPrint("isSessionValid check:");
    debugPrint("  - isLoggedIn: $loggedIn");
    debugPrint("  - username: '$username' (valid: $isUsernameValid)");
    debugPrint("  - userId: '$userId' (valid: $isUserIdValid)");
    debugPrint("  - RESULT: $isValid");

    return isValid;
  }

  /// Clear session jika data tidak valid atau rusak
  Future<void> clearInvalidSession() async {
    if (!(await isSessionValid())) {
      debugPrint("Invalid session detected, clearing...");
      await logoutUser();
    }
  }

  void _logCurrentSession(SharedPreferences prefs) {
    debugPrint("=== Current Session State ===");
    debugPrint("isLoggedIn: ${prefs.getBool(_keyIsLoggedIn) ?? false}");
    debugPrint("username: ${prefs.getString(_keyUsername) ?? 'null'}");
    debugPrint("userId: ${prefs.getString(_keyUserId) ?? 'null'}");
    debugPrint("role: ${prefs.getString(_keyUserRole) ?? 'null'}");
    debugPrint("============================");
  }
}
