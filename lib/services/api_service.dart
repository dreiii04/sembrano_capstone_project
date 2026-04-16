import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class ApiService {
  static const bool _useMockApis =
      bool.fromEnvironment('USE_MOCK_API', defaultValue: true);

  // Optional override via --dart-define=API_BASE_URL=http://<host>:5000/api
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    // Android emulator host loopback.
    return 'http://10.0.2.2:5000/api';
  }

  static const Duration _requestTimeout = Duration(seconds: 12);
  static final Random _random = Random();

  // Token management
  static String? _token;
  static String? _currentUserEmail;

  static final Map<String, Map<String, dynamic>> _mockUsersByEmail = {
    'student.test@verifitor.test': {
      'id': 'user-test-student',
      'email': 'student.test@verifitor.test',
      'password': 'Test@1234',
      'firstName': 'Test',
      'lastName': 'Student',
      'role': 'student',
    },
  };

  static final Map<String, String> _mockSignupOtps = {};
  static final Map<String, String> _mockPasswordResetOtps = {};
  static final List<Map<String, dynamic>> _mockRequests = [];
  static final List<Map<String, dynamic>> _mockTransactions = [];
  static final List<Map<String, dynamic>> _mockActivityLogs = [];

  // Initialize and load token from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _currentUserEmail = prefs.getString('auth_email');
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
    _currentUserEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_email');
  }

  // Get token
  static String? get token => _token;
  static String? get currentUserEmail => _currentUserEmail;

  // Get headers with authorization
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on SocketException {
      throw Exception(_networkErrorMessage());
    } on TimeoutException {
      throw Exception(
        'Request timed out after ${_requestTimeout.inSeconds}s. Check if backend is running and reachable at $baseUrl.',
      );
    } on http.ClientException {
      throw Exception(_networkErrorMessage());
    }
  }

  static String _networkErrorMessage() {
    return 'Cannot connect to API at $baseUrl. '
        'Start your backend server. For Android emulator use 10.0.2.2. '
        'For a real phone use your computer LAN IP and pass it with '
        '--dart-define=API_BASE_URL=http://<LAN_IP>:5000/api.';
  }

  // ==================== AUTH ====================

  /// Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (_useMockApis) {
      return _mockLogin(email: email, password: password);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await saveToken(data['token']);
      }
      await _setCurrentUserEmail(email.trim().toLowerCase());
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
    if (_useMockApis) {
      return _mockRegister(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
      }),
    ));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await NotificationService.addNotification(
        type: 'account',
        title: 'Account Created',
        message: 'Your account has been created successfully.',
      );
      return data;
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Request OTP for email verification during signup.
  static Future<Map<String, dynamic>> requestSignupOtp({
    required String email,
  }) async {
    if (_useMockApis) {
      return _mockRequestSignupOtp(email: email);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/signup/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Verify signup OTP.
  static Future<Map<String, dynamic>> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    if (_useMockApis) {
      return _mockVerifySignupOtp(email: email, otp: otp);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/signup/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Validate email deliverability using Mailboxlayer on backend.
  static Future<bool> validateEmailWithMailboxLayer({
    required String email,
  }) async {
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 120));
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      return emailRegex.hasMatch(email.trim().toLowerCase());
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/validate-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['isValid'] is bool) return data['isValid'] as bool;

        final formatValid = data['format_valid'] == true;
        final mxFound = data['mx_found'] == true;
        final smtpCheck = data['smtp_check'] == true;
        return formatValid && mxFound && smtpCheck;
      }
      return false;
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Request password reset OTP sent to email.
  static Future<Map<String, dynamic>> requestPasswordResetOtp({
    required String email,
  }) async {
    if (_useMockApis) {
      return _mockRequestPasswordResetOtp(email: email);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Verify password reset OTP.
  static Future<Map<String, dynamic>> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    if (_useMockApis) {
      return _mockVerifyPasswordResetOtp(email: email, otp: otp);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Reset password after OTP verification.
  static Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (_useMockApis) {
      return _mockResetPasswordWithOtp(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      }),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== REQUESTS ====================

  /// Get all requests
  static Future<List<Map<String, dynamic>>> getRequests() async {
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 150));
      final copy = _mockRequests
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      copy.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
      return copy;
    }

    final response = await _safeRequest(() => http.get(
      Uri.parse('$baseUrl/requests'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Get request by ID
  static Future<Map<String, dynamic>> getRequestById(String id) async {
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 120));
      final request = _mockRequests.firstWhere(
        (item) => item['_id'] == id,
        orElse: () => {},
      );
      if (request.isEmpty) {
        throw Exception('Request not found.');
      }
      return Map<String, dynamic>.from(request);
    }

    final response = await _safeRequest(() => http.get(
      Uri.parse('$baseUrl/requests/$id'),
      headers: _headers,
    ));

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
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 180));
      if (_token == null) {
        throw Exception('Please login first.');
      }

      final request = {
        '_id': 'req-${DateTime.now().microsecondsSinceEpoch}',
        'documentType': documentType,
        'subDocumentType': subDocumentType,
        'purpose': purpose,
        'otherPurpose': otherPurpose,
        'quantity': quantity,
        'status': 'Pending Payment',
        'createdAt': DateTime.now().toIso8601String(),
      };

      _mockRequests.add(request);
      await NotificationService.addNotification(
        type: 'request-status',
        title: 'Request Submitted',
        message: 'Your request is now Pending Payment.',
      );
      _mockActivityLogs.add({
        '_id': 'log-${DateTime.now().microsecondsSinceEpoch}',
        'action': 'REQUEST_CREATED',
        'requestId': request['_id'],
        'createdAt': DateTime.now().toIso8601String(),
      });
      return Map<String, dynamic>.from(request);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/requests'),
      headers: _headers,
      body: jsonEncode({
        'documentType': documentType,
        'subDocumentType': subDocumentType,
        'purpose': purpose,
        'otherPurpose': otherPurpose,
        'quantity': quantity,
      }),
    ));

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = (data['status'] ?? 'Pending').toString();
      await NotificationService.addNotification(
        type: 'request-status',
        title: 'Request Submitted',
        message: 'Your request status is $status.',
      );
      return data;
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  /// Update request status
  static Future<Map<String, dynamic>> updateRequestStatus({
    required String id,
    required String status,
  }) async {
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 140));
      final index = _mockRequests.indexWhere((item) => item['_id'] == id);
      if (index == -1) {
        throw Exception('Request not found.');
      }

      _mockRequests[index]['status'] = status;
      await NotificationService.addNotification(
        type: 'request-status',
        title: 'Request Status Updated',
        message: 'Your request status is now $status.',
      );
      _mockActivityLogs.add({
        '_id': 'log-${DateTime.now().microsecondsSinceEpoch}',
        'action': 'REQUEST_STATUS_UPDATED',
        'requestId': id,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return Map<String, dynamic>.from(_mockRequests[index]);
    }

    final response = await _safeRequest(() => http.put(
      Uri.parse('$baseUrl/requests/$id'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final updatedStatus = (data['status'] ?? status).toString();
      await NotificationService.addNotification(
        type: 'request-status',
        title: 'Request Status Updated',
        message: 'Your request status is now $updatedStatus.',
      );
      return data;
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== TRANSACTIONS ====================

  /// Get all transactions
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 120));
      return _mockTransactions
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    final response = await _safeRequest(() => http.get(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers,
    ));

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
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 150));
      final txn = {
        '_id': 'txn-${DateTime.now().microsecondsSinceEpoch}',
        'requestId': requestId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentProof': paymentProof,
        'createdAt': DateTime.now().toIso8601String(),
      };
      _mockTransactions.add(txn);
      await NotificationService.addNotification(
        type: 'payment',
        title: 'Payment Submitted',
        message: 'Your payment receipt has been submitted for verification.',
      );
      return Map<String, dynamic>.from(txn);
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers,
      body: jsonEncode({
        'requestId': requestId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentProof': paymentProof,
      }),
    ));

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await NotificationService.addNotification(
        type: 'payment',
        title: 'Payment Submitted',
        message: 'Your payment receipt has been submitted for verification.',
      );
      return data;
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  static Future<Map<String, dynamic>?> getLatestTransactionForRequest({
    required String requestId,
  }) async {
    final transactions = await getTransactions();
    final matches = transactions
        .where((txn) => (txn['requestId'] ?? '').toString() == requestId)
        .toList();

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) {
      final aDate = DateTime.tryParse((a['createdAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['createdAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return Map<String, dynamic>.from(matches.first);
  }

  // ==================== ACTIVITY LOGS ====================

  /// Get activity logs
  static Future<List<Map<String, dynamic>>> getActivityLogs() async {
    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _mockActivityLogs
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    final response = await _safeRequest(() => http.get(
      Uri.parse('$baseUrl/activity-logs'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(_getErrorMessage(response));
    }
  }

  // ==================== PROFILE ====================

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final fallbackEmail = (_currentUserEmail ?? 'student.test@verifitor.test').toLowerCase();

    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 120));
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('profile_$fallbackEmail');
      if (saved != null) {
        return Map<String, dynamic>.from(jsonDecode(saved));
      }

      final user = _mockUsersByEmail[fallbackEmail] ?? _mockUsersByEmail.values.first;
      final profile = {
        'firstName': user['firstName'] ?? 'Test',
        'lastName': user['lastName'] ?? 'Student',
        'studentId': '2024-123346',
        'yearLevel': '2nd Year',
        'program': 'BSIT-MWA',
        'schoolEmail': fallbackEmail,
        'personalEmail': fallbackEmail,
        'imagePath': '',
      };
      await prefs.setString('profile_$fallbackEmail', jsonEncode(profile));
      return profile;
    }

    final response = await _safeRequest(() => http.get(
      Uri.parse('$baseUrl/profile/me'),
      headers: _headers,
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data);
    }

    throw Exception(_getErrorMessage(response));
  }

  static Future<Map<String, dynamic>> updateCurrentUserProfile({
    required Map<String, dynamic> profile,
  }) async {
    final fallbackEmail = (_currentUserEmail ?? 'student.test@verifitor.test').toLowerCase();

    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 140));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_$fallbackEmail', jsonEncode(profile));

      final user = _mockUsersByEmail[fallbackEmail];
      if (user != null) {
        user['firstName'] = (profile['firstName'] ?? user['firstName']).toString();
        user['lastName'] = (profile['lastName'] ?? user['lastName']).toString();
      }

      return profile;
    }

    final response = await _safeRequest(() => http.put(
      Uri.parse('$baseUrl/profile/me'),
      headers: _headers,
      body: jsonEncode(profile),
    ));

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception(_getErrorMessage(response));
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final fallbackEmail = (_currentUserEmail ?? 'student.test@verifitor.test').toLowerCase();

    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 140));
      final user = _mockUsersByEmail[fallbackEmail];
      if (user == null) {
        throw Exception('User not found.');
      }
      if (user['password'] != currentPassword) {
        throw Exception('Current password is incorrect.');
      }
      user['password'] = newPassword;
      return;
    }

    final response = await _safeRequest(() => http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    ));

    if (response.statusCode != 200) {
      throw Exception(_getErrorMessage(response));
    }
  }

  static Future<void> deleteCurrentAccount() async {
    final fallbackEmail = (_currentUserEmail ?? 'student.test@verifitor.test').toLowerCase();

    if (_useMockApis) {
      await Future.delayed(const Duration(milliseconds: 150));
      final prefs = await SharedPreferences.getInstance();
      _mockUsersByEmail.remove(fallbackEmail);
      await prefs.remove('profile_$fallbackEmail');
      await clearToken();
      return;
    }

    final response = await _safeRequest(() => http.delete(
      Uri.parse('$baseUrl/profile/me'),
      headers: _headers,
    ));

    if (response.statusCode == 200 || response.statusCode == 204) {
      await clearToken();
      return;
    }

    throw Exception(_getErrorMessage(response));
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

  static Future<Map<String, dynamic>> _mockLogin({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 180));
    final normalizedEmail = email.trim().toLowerCase();
    final user = _mockUsersByEmail[normalizedEmail];

    if (user == null || user['password'] != password) {
      throw Exception('Invalid email or password.');
    }

    final generatedToken = 'mock-token-${normalizedEmail.hashCode}';
    await saveToken(generatedToken);
    await _setCurrentUserEmail(normalizedEmail);

    return {
      'message': 'Login successful',
      'token': generatedToken,
      'user': {
        'id': user['id'],
        'email': user['email'],
        'firstName': user['firstName'],
        'lastName': user['lastName'],
        'role': user['role'],
      },
    };
  }

  static Future<void> _setCurrentUserEmail(String email) async {
    _currentUserEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_email', email);
  }

  static Future<Map<String, dynamic>> _mockRegister({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 220));
    final normalizedEmail = email.trim().toLowerCase();
    if (_mockUsersByEmail.containsKey(normalizedEmail)) {
      throw Exception('Email is already registered.');
    }

    _mockUsersByEmail[normalizedEmail] = {
      'id': 'user-${DateTime.now().microsecondsSinceEpoch}',
      'email': normalizedEmail,
      'password': password,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'role': role,
    };

    await NotificationService.addNotification(
      type: 'account',
      title: 'Account Created',
      message: 'Your account has been created successfully.',
    );

    return {
      'message': 'Registration successful',
      'email': normalizedEmail,
    };
  }

  static Future<Map<String, dynamic>> _mockRequestSignupOtp({
    required String email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final normalizedEmail = email.trim().toLowerCase();
    _mockSignupOtps[normalizedEmail] = _generateOtp();
    return {'message': 'OTP sent.'};
  }

  static Future<Map<String, dynamic>> _mockVerifySignupOtp({
    required String email,
    required String otp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final normalizedEmail = email.trim().toLowerCase();
    final expected = _mockSignupOtps[normalizedEmail];
    if (otp != '123456' && (expected == null || expected != otp)) {
      throw Exception('Invalid OTP.');
    }
    _mockSignupOtps.remove(normalizedEmail);
    return {'message': 'OTP verified.'};
  }

  static Future<Map<String, dynamic>> _mockRequestPasswordResetOtp({
    required String email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final normalizedEmail = email.trim().toLowerCase();
    if (!_mockUsersByEmail.containsKey(normalizedEmail)) {
      throw Exception('No account found for this email.');
    }

    _mockPasswordResetOtps[normalizedEmail] = _generateOtp();
    return {'message': 'OTP sent.'};
  }

  static Future<Map<String, dynamic>> _mockVerifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final normalizedEmail = email.trim().toLowerCase();
    final expected = _mockPasswordResetOtps[normalizedEmail];
    if (otp != '123456' && (expected == null || expected != otp)) {
      throw Exception('Invalid OTP.');
    }
    return {'message': 'OTP verified.'};
  }

  static Future<Map<String, dynamic>> _mockResetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final normalizedEmail = email.trim().toLowerCase();
    final user = _mockUsersByEmail[normalizedEmail];
    if (user == null) {
      throw Exception('No account found for this email.');
    }

    final expected = _mockPasswordResetOtps[normalizedEmail];
    if (otp != '123456' && (expected == null || expected != otp)) {
      throw Exception('Invalid OTP.');
    }

    user['password'] = newPassword;
    _mockPasswordResetOtps.remove(normalizedEmail);
    return {'message': 'Password reset successful.'};
  }

  static String _generateOtp() {
    return (100000 + _random.nextInt(900000)).toString();
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => _token != null;
}
