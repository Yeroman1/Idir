import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/auth_error_messages.dart';

/// Authentication service checking live Supabase Email and Password.
class AuthService {
  AuthService({String? baseUrl, http.Client? client})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static String? _resolvedWorkingBaseUrl;

  static List<String> get _candidateBaseUrls {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return [envUrl];

    if (_resolvedWorkingBaseUrl != null) {
      return [_resolvedWorkingBaseUrl!];
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return [
        'http://127.0.0.1:5000/api/v1/auth/email', // physical device with adb reverse
        'http://10.42.0.39:5000/api/v1/auth/email', // physical device over Wi-Fi
        'http://10.0.2.2:5000/api/v1/auth/email',  // android emulator
        'http://localhost:5000/api/v1/auth/email',
      ];
    }
    return [
      'http://localhost:5000/api/v1/auth/email',
      'http://127.0.0.1:5000/api/v1/auth/email',
      'http://10.42.0.39:5000/api/v1/auth/email',
    ];
  }

  /// Automatically resolves localhost for Android Emulator (10.0.2.2) vs Desktop/iOS/Web (localhost)
  static String get _defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:5000/api/v1/auth/email';
    }
    return 'http://localhost:5000/api/v1/auth/email';
  }

  Future<Map<String, dynamic>> _postToCandidateBaseUrls(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final urls = _candidateBaseUrls;
    Exception? lastError;

    for (final base in urls) {
      try {
        final url = Uri.parse('$base$endpoint');
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode >= 400) {
          throw Exception(_extractErrorMessage(data, 'Request failed'));
        }

        _resolvedWorkingBaseUrl = base;
        return (data['data'] as Map<String, dynamic>?) ?? data;
      } on SocketException catch (e) {
        lastError = Exception('Failed to connect to backend server: ${e.message}');
      } on http.ClientException catch (e) {
        lastError = Exception('Network client error: ${e.message}');
      } on TimeoutException {
        lastError = Exception('Connection timed out');
      } catch (e) {
        rethrow;
      }
    }

    throw lastError ?? Exception('Failed to connect to backend server');
  }

  // Session state in memory
  static String? accessToken;
  static String? refreshToken;
  static Map<String, dynamic>? currentUser;
  static String? passwordResetToken;

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

  /// Step 4: Login with verified Email and Password checking live Supabase.
  Future<Map<String, dynamic>> emailLogin(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Ensure Supabase client is initialized
    SupabaseClient supabase;
    try {
      supabase = Supabase.instance.client;
    } catch (_) {
      if (SupabaseConfig.isConfigured) {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
        supabase = Supabase.instance.client;
      } else {
        throw Exception(
          'Supabase is not configured. Please verify SUPABASE_URL and SUPABASE_ANON_KEY.',
        );
      }
    }

    // 2. Perform live authentication against Supabase GoTrue Auth
    AuthResponse? authResponse;
    try {
      authResponse = await supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
    } catch (e) {
      // If Supabase GoTrue fails or user registered directly in database, try backend database auth
      try {
        final backendRes = await _postToCandidateBaseUrls(
          '/login',
          {'email': cleanEmail, 'password': password},
        );
        final tokens = backendRes['tokens'] as Map<String, dynamic>?;
        final u = backendRes['user'] as Map<String, dynamic>?;
        if (tokens != null && u != null) {
          accessToken = tokens['accessToken'] as String?;
          refreshToken = tokens['refreshToken'] as String?;
          currentUser = u;
          return {
            'tokens': tokens,
            'user': u,
          };
        }
      } catch (_) {
        // If backend also fails, proceed to throw primary error
      }

      if (e is AuthException) {
        throw Exception(humanReadableAuthError(e));
      }
      _handleNetworkError(e);
    }

    final user = authResponse?.user;
    final session = authResponse?.session;

    if (user == null) {
      throw Exception('Authentication failed: no user returned from Supabase.');
    }

    accessToken = session?.accessToken;
    refreshToken = session?.refreshToken;

    // 3. Extract user metadata or enrich with Supabase database profile
    String fullName = user.userMetadata?['fullName'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.userMetadata?['full_name'] as String? ??
        '';
    if (fullName.isEmpty) {
      final localPart = cleanEmail.split('@').first;
      fullName = localPart
          .split(RegExp(r'[._-]'))
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ');
      if (fullName.trim().isEmpty) fullName = 'Idir Member';
    }

    String phone = user.userMetadata?['phoneNumber'] as String? ??
        user.userMetadata?['phone'] as String? ??
        user.phone ??
        '';

    String role = (user.userMetadata?['role'] as String? ?? 'MEMBER').toUpperCase();
    List<dynamic> memberships = [];

    // Attempt to enrich with live Supabase database record (if User table exists)
    try {
      final profile = await supabase
          .from('User')
          .select('id, fullName, phoneNumber, role, status, memberships:Membership(*, idir:Idir(*))')
          .or('id.eq.${user.id},email.eq.$cleanEmail')
          .maybeSingle();

      if (profile != null) {
        if (profile['fullName'] != null && (profile['fullName'] as String).isNotEmpty) {
          fullName = profile['fullName'] as String;
        }
        if (profile['phoneNumber'] != null && (profile['phoneNumber'] as String).isNotEmpty) {
          phone = profile['phoneNumber'] as String;
        }
        if (profile['role'] != null) {
          role = (profile['role'] as String).toUpperCase();
        }
        if (profile['memberships'] is List) {
          memberships = profile['memberships'] as List;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Supabase DB profile query notice: $e');
    }

    final userData = <String, dynamic>{
      'id': user.id,
      'uid': user.id,
      'email': user.email ?? cleanEmail,
      'fullName': fullName,
      'name': fullName,
      'phoneNumber': phone,
      'phone': phone,
      'status': 'ACTIVE',
      'isActive': true,
      'role': role,
      'createdAt': user.createdAt,
      'memberships': memberships,
    };

    currentUser = userData;

    return {
      'tokens': {
        'accessToken': session?.accessToken ?? 'sb-access-token',
        'refreshToken': session?.refreshToken ?? 'sb-refresh-token',
      },
      'user': userData,
    };
  }

  /// Checks whether an email address belongs to an actual registered user.
  Future<bool> isEmailRegistered(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final supabase = _getSupabaseClient();
    try {
      final res = await supabase.rpc(
        'check_user_email_registered',
        params: {'check_email': cleanEmail},
      );
      return res == true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection refused') ||
          msg.contains('failed host lookup') ||
          msg.contains('clientexception')) {
        _handleNetworkError(e);
      }
      rethrow;
    }
  }

  /// Sends a 6-digit password recovery OTP to the user's email via the backend.
  /// Checks first if the email is an actual registered user before sending.
  Future<Map<String, dynamic>> sendPasswordResetOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check first if the email is an actual registered user
    final registered = await isEmailRegistered(cleanEmail);
    if (!registered) {
      throw Exception(
        'This email is not registered. Please check the email or sign up first.',
      );
    }

    // 2. Dispatch OTP recovery email via backend
    try {
      final res = await _postToCandidateBaseUrls(
        '/forgot-password/send-otp',
        {'email': cleanEmail},
      );
      return res;
    } catch (backendError) {
      final errStr = backendError.toString();
      if (!errStr.contains('Network connection error') &&
          !errStr.contains('SocketException') &&
          !errStr.contains('Failed to connect') &&
          !errStr.contains('Connection timed out')) {
        rethrow;
      }

      // If backend was unreachable, fallback to Supabase
      final supabase = _getSupabaseClient();
      try {
        await supabase.auth.resetPasswordForEmail(cleanEmail);
        return {'success': true, 'message': 'Verification code sent to $cleanEmail'};
      } on AuthException catch (e) {
        throw Exception(humanReadableAuthError(e));
      } catch (e) {
        _handleNetworkError(e);
      }
    }
  }

  /// Validates the 6-digit recovery OTP for password reset.
  Future<String> verifyPasswordResetOtp(String email, String otp) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final res = await _postToCandidateBaseUrls(
        '/forgot-password/verify-otp',
        {'email': cleanEmail, 'otp': otp.trim()},
      );
      final token = res['resetToken'] as String? ?? '';
      passwordResetToken = token;
      return token;
    } catch (backendError) {
      final errStr = backendError.toString();
      if (!errStr.contains('Network connection error') &&
          !errStr.contains('SocketException') &&
          !errStr.contains('Failed to connect') &&
          !errStr.contains('Connection timed out')) {
        rethrow;
      }

      final supabase = _getSupabaseClient();
      try {
        await supabase.auth.verifyOTP(
          email: cleanEmail,
          token: otp.trim(),
          type: OtpType.recovery,
        );
        return 'supabase_recovery_verified';
      } on AuthException catch (e) {
        throw Exception(humanReadableAuthError(e));
      } catch (e) {
        _handleNetworkError(e);
      }
    }
  }

  /// Updates the user's password with confirmation upon successful OTP verification.
  Future<void> resetPassword({
    required String newPassword,
    String? email,
  }) async {
    final cleanEmail = (email ?? '').trim().toLowerCase();

    // 1. Update in backend if resetToken is present
    if (passwordResetToken != null &&
        passwordResetToken!.isNotEmpty &&
        passwordResetToken != 'supabase_recovery_verified') {
      try {
        await _postToCandidateBaseUrls(
          '/forgot-password/reset-password',
          {
            'email': cleanEmail,
            'resetToken': passwordResetToken,
            'password': newPassword,
            'confirmPassword': newPassword,
          },
        );
      } catch (e) {
        final errStr = e.toString();
        if (!errStr.contains('Network connection error') &&
            !errStr.contains('SocketException') &&
            !errStr.contains('Failed to connect') &&
            !errStr.contains('Connection timed out')) {
          rethrow;
        }
      }
    }

    // 2. Also update in Supabase if session exists
    try {
      final supabase = _getSupabaseClient();
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      await supabase.auth.signOut();
    } catch (_) {
      // Ignored if user has no direct Supabase recovery session
    }

    passwordResetToken = null;
  }

  SupabaseClient _getSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      if (SupabaseConfig.isConfigured) {
        Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
        return Supabase.instance.client;
      }
      throw Exception(
        'Supabase is not configured. Please verify SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
  }

  Never _handleNetworkError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
      throw Exception('Network connection error: please verify your internet connection.');
    }
    throw Exception(e.toString().replaceFirst('Exception: ', ''));
  }

  /// Clear active session
  void signOut() {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
    try {
      Supabase.instance.client.auth.signOut();
    } catch (_) {}
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
