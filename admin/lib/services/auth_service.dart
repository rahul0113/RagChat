import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  String? _apiKey;
  String? _baseUrl;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get apiKey => _apiKey;
  String? get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _baseUrl = prefs.getString('base_url');
    _isAuthenticated = _apiKey != null && _apiKey!.isNotEmpty;
    notifyListeners();
  }

  Future<void> login(String baseUrl, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    _isAuthenticated = true;
    await prefs.setString('api_key', apiKey);
    await prefs.setString('base_url', baseUrl);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = null;
    _baseUrl = null;
    _isAuthenticated = false;
    await prefs.remove('api_key');
    await prefs.remove('base_url');
    notifyListeners();
  }
}
