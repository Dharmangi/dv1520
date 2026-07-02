import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        headers: {'x-api-key': apiKey},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  static const String _baseUrlPrefKey = 'api_base_url';

  static const String defaultBaseUrl = 'https://dv1520.onrender.com/api';
  static const String apiKey = 'dv1520-9f3a7c1e4b2d6f8a0c5e9b3d7f1a4c8e';

  late final Dio _dio;

  Dio get dio => _dio;

  Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlPrefKey);
    if (saved != null && saved.isNotEmpty) {
      _dio.options.baseUrl = saved;
    }
  }

  String get currentBaseUrl => _dio.options.baseUrl;

  Future<void> setBaseUrl(String url) async {
    _dio.options.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlPrefKey, url);
  }
}
