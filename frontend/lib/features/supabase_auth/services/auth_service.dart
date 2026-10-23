import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service connecting directly to your Express backend for Email OTP authentication.
/// Zero external cloud APIs, zero Resend or Supabase dashboard dependencies required.
class AuthService {
  AuthService({String? baseUrl, http.Client? client})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Automatically resolves localhost for Android Emulator (10.0.2.2) vs Desktop/iOS/Web (localhost)
  static String get _defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api/v1/auth/email';
    }
    return 'http://localhost:5000/api/v1/auth/email';
  }

  // Session state in memory
  static String? accessToken;
  static String? refreshToken;
  static Map<String, dynamic>? currentUser;

  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _specialCharRegex =
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\;/+=`~]');

  static final RegExp _nameRegex = RegExp(r"^[a-zA-Z\u1200-\u137F\s\-]{2,50}$");
  static final RegExp _ethiopianPhoneRegex = RegExp(r"^\+251[79]\d{8}$");

  /// Validates password complexity:
  /// - Minimum 12 characters
  /// - At least 1 uppercase letter
  /// - At least 1 lowercase letter
  /// - At least 1 number
  /// - At least 1 special character
  bool isPasswordStrong(String password) {
    if (password.length < 12) return false;
    if (!_uppercaseRegex.hasMatch(password)) return false;
    if (!_lowercaseRegex.hasMatch(password)) return false;
    if (!_digitRegex.hasMatch(password)) return false;
    if (!_specialCharRegex.hasMatch(password)) return false;
    return true;
  }

  bool hasMinLength(String password) => password.length >= 12;
  bool hasUppercase(String password) => _uppercaseRegex.hasMatch(password);
  bool hasLowercase(String password) => _lowercaseRegex.hasMatch(password);
  bool hasDigit(String password) => _digitRegex.hasMatch(password);
  bool hasSpecialChar(String password) => _specialCharRegex.hasMatch(password);

  bool isValidName(String name) => _nameRegex.hasMatch(name.trim());

  bool isValidEthiopianPhone(String phone) {
    final clean = phone.trim();
    return clean.length == 13 && _ethiopianPhoneRegex.hasMatch(clean);
  }

  bool isValidAddress(String address) {
    final clean = address.trim();
    return clean.length >= 3 && clean.length <= 150;
  }

  bool isValidDateOfBirth(DateTime? dob) {
    if (dob == null) return false;
    final now = DateTime.now();
    if (dob.isAfter(now)) return false;
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  /// Step 1: Send 6-digit OTP to the requested email.
  Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(data, 'Failed to send verification code'));
    }

    return (data['data'] as Map<String, dynamic>?) ?? data;
  }

  /// Step 2: Validate the 6-digit OTP code and retrieve the registration token.
  Future<String> verifyEmailOtp(String email, String otp) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(data, 'Invalid or expired verification code'));
    }

    final responseData = (data['data'] as Map<String, dynamic>?) ?? data;
    final token = responseData['registrationToken'] as String?;
    if (token == null) {
      throw Exception('Server did not return a registration token');
    }

    return token;
  }

  /// Step 3: Complete registration by creating user profile and password.
  Future<Map<String, dynamic>> completeRegistration({
    required String email,
    required String registrationToken,
    required String firstName,
    required String middleName,
    required String lastName,
    required String phoneNumber,
    required String address,
    required DateTime dateOfBirth,
    required String password,
    String? confirmPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/complete-registration'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'registrationToken': registrationToken,
        'firstName': firstName.trim(),
        'middleName': middleName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
        'dateOfBirth': dateOfBirth.toIso8601String().split('T')[0],
        'password': password,
        if (confirmPassword != null) 'confirmPassword': confirmPassword,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(data, 'Registration failed'));
    }

    final responseData = (data['data'] as Map<String, dynamic>?) ?? data;
    final tokens = responseData['tokens'] as Map<String, dynamic>?;
    if (tokens != null) {
      accessToken = tokens['accessToken'] as String?;
      refreshToken = tokens['refreshToken'] as String?;
    }
    currentUser = responseData['user'] as Map<String, dynamic>?;

    return responseData;
  }

  /// Step 4: Login with verified Email and Password.
  Future<Map<String, dynamic>> emailLogin(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(_extractErrorMessage(data, 'Invalid email or password'));
    }

    final responseData = (data['data'] as Map<String, dynamic>?) ?? data;
    final tokens = responseData['tokens'] as Map<String, dynamic>?;
    if (tokens != null) {
      accessToken = tokens['accessToken'] as String?;
      refreshToken = tokens['refreshToken'] as String?;
    }
    currentUser = responseData['user'] as Map<String, dynamic>?;

    return responseData;
  }

  /// Clear active session
  void signOut() {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
  }

  bool get isAuthenticated => accessToken != null;

  String _extractErrorMessage(Map<String, dynamic> data, String fallback) {
    if (data['message'] is String) return data['message'] as String;
    final error = data['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return fallback;
  }
}
