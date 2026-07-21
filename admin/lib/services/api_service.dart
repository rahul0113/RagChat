import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/tenant_model.dart';
import 'error_handler.dart';

class ApiService extends ChangeNotifier {
  String _baseUrl = 'https://ragchat-tsqf.onrender.com/api';
  String? _apiKey;

  String get baseUrl => _baseUrl;
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure({required String baseUrl, required String apiKey}) {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    notifyListeners();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey != null) 'X-API-Key': _apiKey!,
  };

  // --- Tenants ---
  Future<List<Tenant>> getTenants() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/tenants'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((t) => Tenant.fromJson(t)).toList();
      }
      throw Exception('Failed to load tenants: ${res.statusCode}');
    } catch (e) {
      debugPrint('getTenants error: $e');
      return [];
    }
  }

  Future<TenantDetail> getTenant(String id) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/admin/tenants/$id'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return TenantDetail.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load tenant');
  }

  Future<TenantDetail> createTenant({
    required String name,
    required String slug,
    required String orgName,
    String plan = 'free',
    String themeName = 'default',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/admin/tenants'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'slug': slug,
        'org_name': orgName,
        'plan': plan,
        'theme_name': themeName,
      }),
    );
    if (res.statusCode == 200) {
      return TenantDetail.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create tenant: ${res.body}');
  }

  Future<void> updateTheme(String tenantId, Map<String, dynamic> theme) async {
    await http.put(
      Uri.parse('$_baseUrl/admin/tenants/$tenantId/theme'),
      headers: _headers,
      body: jsonEncode({'theme': theme}),
    );
  }

  Future<void> deleteTenant(String id) async {
    await http.delete(
      Uri.parse('$_baseUrl/admin/tenants/$id'),
      headers: _headers,
    );
  }

  // --- Chat ---
  Future<Map<String, dynamic>> chat(String slug, String question, {bool structured = true}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat/$slug'),
      headers: _headers,
      body: jsonEncode({'question': question, 'structured': structured}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Chat failed: ${res.body}');
  }

  // --- Documents ---
  Future<Map<String, dynamic>> uploadDocument(String tenantId, List<int> bytes, String filename) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/tenants/$tenantId/upload'),
    );
    request.headers.addAll({'X-API-Key': _apiKey ?? ''});
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Upload failed: ${res.body}');
  }

  Future<Map<String, dynamic>> getDocuments(String tenantId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/tenants/$tenantId/documents'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'total_vectors': 0};
    } catch (e) {
      return {'total_vectors': 0};
    }
  }

  // --- Analytics ---
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/analytics/summary'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'total_tenants': 0, 'total_queries': 0, 'this_week': 0, 'today': 0, 'total_documents': 0};
    } catch (e) {
      return {'total_tenants': 0, 'total_queries': 0, 'this_week': 0, 'today': 0, 'total_documents': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getTopQueries({String? tenantId, int limit = 10}) async {
    try {
      var uri = Uri.parse('$_baseUrl/admin/analytics/top-queries?limit=$limit');
      if (tenantId != null) uri = uri.replace(queryParameters: {'tenant_id': tenantId, 'limit': '$limit'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['queries'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentQueries({String? tenantId, int limit = 20}) async {
    try {
      var uri = Uri.parse('$_baseUrl/admin/analytics/recent?limit=$limit');
      if (tenantId != null) uri = uri.replace(queryParameters: {'tenant_id': tenantId, 'limit': '$limit'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['queries'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteQuery(String queryId) async {
    await http.delete(
      Uri.parse('$_baseUrl/admin/queries/$queryId'),
      headers: _headers,
    );
  }

  Future<String> exportData({String? tenantId}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/admin/analytics/export'),
        headers: _headers,
        body: jsonEncode({'tenant_id': tenantId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['csv'] ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // --- Stats ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/analytics/summary'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('getDashboardStats error: $e');
    }
    // Fallback: compute from tenants list
    final tenants = await getTenants();
    int totalQueries = 0;
    int totalDocs = 0;
    for (final t in tenants) {
      totalQueries += t.totalQueries;
      totalDocs += t.totalDocuments;
    }
    return {
      'totalTenants': tenants.length,
      'totalQueries': totalQueries,
      'totalDocuments': totalDocs,
      'tenants': tenants,
    };
  }
}
