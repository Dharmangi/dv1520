import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../network/api_client.dart';

/// Talks to the DV1520 backend's /auth/login endpoint and persists the
/// resulting session (JWT + user) on-device so the app stays logged in
/// across restarts.
class AuthService {
  AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _usernameKey = 'auth_username';
  static const _nameKey = 'auth_name';

  static Future<User?> login({
    required String username,
    required String password,
  }) async {
    try {
      final res = await ApiClient.instance.dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final token = res.data['token'] as String;
      final userJson = res.data['user'] as Map<String, dynamic>;
      final user = User.fromJson({...userJson, 'token': token});
      await _persistSession(user);
      return user;
    } on Object {
      return null;
    }
  }

  static Future<void> _persistSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, user.token ?? '');
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_usernameKey, user.username);
    if (user.name != null) await prefs.setString(_nameKey, user.name!);
  }

  static Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final id = prefs.getString(_userIdKey);
    final username = prefs.getString(_usernameKey);
    if (token == null || token.isEmpty || id == null || username == null) return null;
    return User(id: id, username: username, name: prefs.getString(_nameKey), token: token);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_nameKey);
  }
}
