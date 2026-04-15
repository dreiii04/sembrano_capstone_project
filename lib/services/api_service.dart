import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Base URL - Change this to your backend URL
  // For local development:
  // - Android emulator: use 10.0.2.2
  // - iOS simulator: use localhost
  // - Physical device: use your computer's IP address (e.g., 192.168.1.x)
  // For production: use your deployed backend URL
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    // Default to Android emulator
    return 'http://10.0.2.2:5000/api';
  }

  // Token management
  static String? _token;

  // Initialize and load token from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  // Save token to storage
  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear token from storage
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Get token
  static String? get token => _token;

  // Get headers with authorization
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ==================== AUTH ====================

  /// Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Register user
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== REQUESTS ====================

  /// Get all requests
  static Future<List<Map<String, dynamic>>> getRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Get request by ID
  static Future<Map<String, dynamic>> getRequestById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/requests/$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Create new request
  static Future<Map<String, dynamic>> createRequest({
    required String documentType,
    required String subDocumentType,
    required String purpose,
    required String otherPurpose,
    required int quantity,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests'),
      headers: _headers,
      body: jsonEncode({
        'documentType': documentType,
        'subDocumentType': subDocumentType,
        'purpose': purpose,
        'otherPurpose': otherPurpose,
        'quantity': quantity,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Update request status
  static Future<Map<String, dynamic>> updateRequestStatus({
    required String id,
    required String status,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/requests/$id'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== TRANSACTIONS ====================

  /// Get all transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Create transaction
  static Future<Map<String, dynamic>> createTransaction({
    required String requestId,
    required String amount,
    required String paymentMethod,
    required String paymentProof,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers,
      body: jsonEncode({
        'requestId': requestId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentProof': paymentProof,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== ACTIVITY LOGS ====================

  /// Get activity logs
  static Future<List<Map<String, dynamic>>> getActivityLogs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/activity-logs'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== HELPERS ====================

  static String _getErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? data['error'] ?? 'An error occurred';
    } catch (e) {
      return 'Server error: ${response.statusCode}';
    }
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => _token != null;
}
