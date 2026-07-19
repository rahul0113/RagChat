import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  String? _apiKey;
  String? _baseUrl;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get apiKey => _apiKey;
  String? get baseUrl => _baseUrl;

  Future<void> init() async {
    // No-op for now (auth skipped)
    notifyListeners();
  }

  Future<void> login(String baseUrl, String apiKey) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    _apiKey = null;
    _baseUrl = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
