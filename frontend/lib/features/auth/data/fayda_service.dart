import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fayda verified citizen demographic and KYC identity model.
class FaydaCitizenProfile {
  const FaydaCitizenProfile({
    required this.fin,
    required this.fullName,
    required this.amharicName,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.address,
    required this.verifiedAt,
    this.photoUrl,
    this.status = 'VERIFIED',
  });

  factory FaydaCitizenProfile.fromMap(Map<String, dynamic> map) {
    return FaydaCitizenProfile(
      fin: map['fin'] as String? ?? map['faydaId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? map['name'] as String? ?? 'Ethiopian Citizen',
      amharicName: map['amharicName'] as String? ?? map['fullNameAmharic'] as String? ?? '',
      phone: map['phone'] as String? ?? map['mobile'] as String? ?? '+251 90 000 0000',
      gender: map['gender'] as String? ?? 'MALE',
      dateOfBirth: map['dateOfBirth'] as String? ?? map['dob'] as String? ?? '1990-01-01',
      address: map['address'] as String? ?? 'Addis Ababa, Ethiopia',
      verifiedAt: DateTime.tryParse(map['verifiedAt'] as String? ?? '') ?? DateTime.now(),
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String? ?? 'VERIFIED',
    );
  }

  final String fin; // 12-digit Fayda Identification Number
  final String fullName; // e.g., 'Abebe Tadesse Kebede'
  final String amharicName; // e.g., 'አበበ ታደሰ ከበደ'
  final String phone; // e.g., '+251 91 123 4567'
  final String gender; // 'MALE' | 'FEMALE'
  final String dateOfBirth; // 'YYYY-MM-DD'
  final String address; // Woreda / City
  final DateTime verifiedAt;
  final String? photoUrl;
  final String status;

  Map<String, dynamic> toMap() => {
        'fin': fin,
        'fullName': fullName,
        'amharicName': amharicName,
        'phone': phone,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
        'address': address,
        'verifiedAt': verifiedAt.toIso8601String(),
        'photoUrl': photoUrl,
        'status': status,
      };
}

/// Result returned from requesting a Fayda OTP.
class FaydaOtpResponse {
  const FaydaOtpResponse({
    required this.txnId,
    required this.maskedPhone,
    required this.expiresInSeconds,
    required this.isSuccess,
    this.mockOtpCode,
    this.message = 'OTP sent successfully to registered Fayda phone number.',
  });

  final String txnId;
  final String maskedPhone;
  final int expiresInSeconds;
  final bool isSuccess;
  final String? mockOtpCode; // Only populated in Sandbox/Mock mode for developer convenience
  final String message;
}

/// Service handling API communication with the Ethiopian National ID (Fayda) platform.
class FaydaService {
  FaydaService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _prefBaseUrl = 'fayda_api_base_url';
  static const _prefApiKey = 'fayda_api_key';
  static const _prefIsSandbox = 'fayda_is_sandbox';

  static const String defaultLiveBaseUrl = 'https://api.fayda.et/v1/auth';
  static const String defaultSandboxBaseUrl = 'https://sandbox.fayda.et/v1/auth';

  // Demo citizen identities mapped to realistic Fayda FINs
  static final Map<String, FaydaCitizenProfile> mockRegistry = {
    '100020003001': FaydaCitizenProfile(
      fin: '100020003001',
      fullName: 'Abebe Tadesse Kebede',
      amharicName: 'አበበ ታደሰ ከበደ',
      phone: '+251911111111',
      gender: 'MALE',
      dateOfBirth: '1982-04-12',
      address: 'Addis Ababa, Bole Sub-City, Woreda 03',
      verifiedAt: DateTime.now(),
    ),
    '100020003002': FaydaCitizenProfile(
      fin: '100020003002',
      fullName: 'Chaltu Bekele Gemeda',
      amharicName: 'ጫልቱ በቀለ ገመዳ',
      phone: '+251911222222',
      gender: 'FEMALE',
      dateOfBirth: '1986-09-24',
      address: 'Addis Ababa, Yeka Sub-City, Woreda 08',
      verifiedAt: DateTime.now(),
    ),
    '100020003003': FaydaCitizenProfile(
      fin: '100020003003',
      fullName: 'Dawit Adugna Hailu',
      amharicName: 'ዳዊት አዱኛ ኃይሉ',
      phone: '+251911333333',
      gender: 'MALE',
      dateOfBirth: '1979-11-03',
      address: 'Addis Ababa, Kirkos Sub-City, Woreda 02',
      verifiedAt: DateTime.now(),
    ),
    '100020003004': FaydaCitizenProfile(
      fin: '100020003004',
      fullName: 'Fatima Mohammed Ali',
      amharicName: 'ፋጢማ መሀመድ ዐሊ',
      phone: '+251911444444',
      gender: 'FEMALE',
      dateOfBirth: '1992-06-18',
      address: 'Addis Ababa, Arada Sub-City, Woreda 05',
      verifiedAt: DateTime.now(),
    ),
  };

  /// Clean input to get raw 12-digit FIN.
  static String normalizeFin(String input) {
    return input.replaceAll(RegExp(r'\s+|-'), '').trim();
  }

  /// Format 12-digit FIN into `XXXX XXXX XXXX` for readability.
  static String formatFin(String input) {
    final clean = normalizeFin(input);
    if (clean.length <= 4) return clean;
    if (clean.length <= 8) return '${clean.substring(0, 4)} ${clean.substring(4)}';
    if (clean.length <= 12) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8)}';
    }
    return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 12)}';
  }

  /// Get current configuration.
  Future<({String baseUrl, String? apiKey, bool isSandbox})> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final isSandbox = prefs.getBool(_prefIsSandbox) ?? true;
    final baseUrl = prefs.getString(_prefBaseUrl) ??
        (isSandbox ? defaultSandboxBaseUrl : defaultLiveBaseUrl);
    final apiKey = prefs.getString(_prefApiKey);
    return (baseUrl: baseUrl, apiKey: apiKey, isSandbox: isSandbox);
  }

  /// Update API configuration.
  Future<void> saveConfig({
    required String baseUrl,
    String? apiKey,
    required bool isSandbox,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrl, baseUrl);
    if (apiKey != null && apiKey.isNotEmpty) {
      await prefs.setString(_prefApiKey, apiKey);
    } else {
      await prefs.remove(_prefApiKey);
    }
    await prefs.setBool(_prefIsSandbox, isSandbox);
  }

  /// 1. Request OTP for the provided Fayda National ID (FIN).
  Future<FaydaOtpResponse> requestOtp(String faydaInput) async {
    final fin = normalizeFin(faydaInput);
    if (fin.length != 12 || !RegExp(r'^\d{12}$').hasMatch(fin)) {
      throw Exception('Fayda ID must be exactly 12 digits (e.g. 1000 2000 3001).');
    }

    final config = await getConfig();

    // If sandbox mode is active, execute test verification
    if (config.isSandbox) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final profile = mockRegistry[fin];
      final masked = profile != null
          ? _maskPhone(profile.phone)
          : '+251 9• ••• ••${fin.substring(10)}';
      final txnId = 'TXN-FAYDA-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

      return FaydaOtpResponse(
        txnId: txnId,
        maskedPhone: masked,
        expiresInSeconds: 120,
        isSuccess: true,
        mockOtpCode: '123456',
        message: 'Fayda OTP dispatched to $masked (Sandbox Code: 123456)',
      );
    }

    // Live API mode
    try {
      final uri = Uri.parse('${config.baseUrl}/otp/request');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (config.apiKey != null && config.apiKey!.isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey}',
      };

      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'faydaId': fin,
              'channel': 'SMS',
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FaydaOtpResponse(
          txnId: data['txnId'] as String? ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
          maskedPhone: data['maskedPhone'] as String? ?? '+251 9• ••• ••••',
          expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 120,
          isSuccess: true,
          message: data['message'] as String? ?? 'OTP sent to Fayda registered phone.',
        );
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final err = body['message'] ?? body['error'] ?? 'HTTP ${response.statusCode}';
        throw Exception('Fayda API request failed: $err');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to reach Fayda Auth API: $e');
    }
  }

  /// 2. Verify OTP and obtain verified Ethiopian National ID citizen demographic profile.
  Future<FaydaCitizenProfile> verifyOtp({
    required String faydaInput,
    required String otp,
    required String txnId,
  }) async {
    final fin = normalizeFin(faydaInput);
    final cleanOtp = otp.trim();

    if (cleanOtp.length < 4 || cleanOtp.length > 8) {
      throw Exception('Please enter a valid OTP code.');
    }

    final config = await getConfig();

    // Sandbox / Mock Mode
    if (config.isSandbox) {
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // In sandbox mode, '123456' or any 6-digit code is accepted for rapid testing
      if (cleanOtp != '123456' && cleanOtp != '000000' && cleanOtp.length != 6) {
        throw Exception('Invalid OTP. In sandbox test mode, use 123456.');
      }

      if (mockRegistry.containsKey(fin)) {
        return mockRegistry[fin]!;
      }

      // Generate a dynamic verified Ethiopian citizen identity for any valid 12-digit FIN
      return FaydaCitizenProfile(
        fin: fin,
        fullName: 'Alemayehu Hailemariam',
        amharicName: 'አለማየሁ ኃይለማሪያም',
        phone: '+251 91 555 ${fin.substring(8)}',
        gender: 'MALE',
        dateOfBirth: '1991-03-22',
        address: 'Addis Ababa, Nifas Silk-Lafto, Woreda 04',
        verifiedAt: DateTime.now(),
      );
    }

    // Live API mode
    try {
      final uri = Uri.parse('${config.baseUrl}/otp/verify');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (config.apiKey != null && config.apiKey!.isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey}',
      };

      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'faydaId': fin,
              'otp': cleanOtp,
              'txnId': txnId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final citizenData = (data['citizen'] as Map<String, dynamic>?) ?? data;
        return FaydaCitizenProfile.fromMap(citizenData);
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final err = body['message'] ?? body['error'] ?? 'HTTP ${response.statusCode}';
        throw Exception('Fayda OTP verification failed: $err');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Fayda verification service error: $e');
    }
  }

  static String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    final prefix = phone.substring(0, 7);
    final suffix = phone.substring(phone.length - 3);
    return '$prefix ••• •$suffix';
  }
}

final faydaServiceProvider = Provider<FaydaService>((ref) {
  return FaydaService();
});
