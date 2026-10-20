import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../providers/sync_status_provider.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.isOffline = false,
    this.data,
  });

  final String message;
  final int? statusCode;
  final bool isOffline;
  final dynamic data;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    required Ref ref,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    String? baseUrl,
  })  : _ref = ref,
        _client = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _configuredBaseUrl = baseUrl;

  final Ref _ref;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final String? _configuredBaseUrl;

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  bool _isRefreshing = false;

  String? _workingAndroidBaseUrl;

  /// Dynamically computes the backend base URL depending on platform
  String get baseUrl {
    final custom = _configuredBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }

    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) {
      return AppConstants.defaultApiBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _workingAndroidBaseUrl ?? AppConstants.androidDeviceApiBaseUrl;
    }

    return AppConstants.defaultApiBaseUrl;
  }

  /// Read token from secure storage or SharedPreferences fallback
  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    try {
      _cachedAccessToken =
          await _secureStorage.read(key: AppConstants.secureKeyAuthToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _cachedAccessToken = prefs.getString(AppConstants.secureKeyAuthToken);
    }
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    try {
      _cachedRefreshToken =
          await _secureStorage.read(key: AppConstants.secureKeyRefreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _cachedRefreshToken =
          prefs.getString(AppConstants.secureKeyRefreshToken);
    }
    return _cachedRefreshToken;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;

    try {
      await _secureStorage.write(
        key: AppConstants.secureKeyAuthToken,
        value: accessToken,
      );
      await _secureStorage.write(
        key: AppConstants.secureKeyRefreshToken,
        value: refreshToken,
      );
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.secureKeyAuthToken, accessToken);
      await prefs.setString(AppConstants.secureKeyRefreshToken, refreshToken);
    }
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;

    try {
      await _secureStorage.delete(key: AppConstants.secureKeyAuthToken);
      await _secureStorage.delete(key: AppConstants.secureKeyRefreshToken);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.secureKeyAuthToken);
    await prefs.remove(AppConstants.secureKeyRefreshToken);
  }

  /// Core HTTP GET
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _sendWithRetry(
      () => _buildUri(path, queryParams),
      (uri, headers) => _client.get(uri, headers: headers),
      requiresAuth: requiresAuth,
    );
  }

  /// Core HTTP POST
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _sendWithRetry(
      () => _buildUri(path, queryParams),
      (uri, headers) => _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      requiresAuth: requiresAuth,
    );
  }

  /// Core HTTP PUT
  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _sendWithRetry(
      () => _buildUri(path, queryParams),
      (uri, headers) => _client.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      requiresAuth: requiresAuth,
    );
  }

  /// Core HTTP DELETE
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _sendWithRetry(
      () => _buildUri(path, queryParams),
      (uri, headers) => _client.delete(uri, headers: headers),
      requiresAuth: requiresAuth,
    );
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParams) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$baseUrl$cleanPath';
    final parsed = Uri.parse(fullUrl);

    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return parsed.replace(queryParameters: stringParams);
    }
    return parsed;
  }

  Future<dynamic> _sendWithRetry(
    Uri Function() uriBuilder,
    Future<http.Response> Function(Uri uri, Map<String, String> headers)
        requestFn, {
    bool requiresAuth = true,
    bool isRetry = false,
  }) async {
    // Check if offline mode is simulated via the SyncNotifier switch
    final syncState = _ref.read(syncProvider);
    if (syncState.isOfflineSimulated) {
      throw ApiException(
        message: 'Offline mode is active (simulated field mode)',
        isOffline: true,
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    try {
      final uri = uriBuilder();
      http.Response response;
      try {
        response = await requestFn(uri, headers).timeout(
          const Duration(seconds: 30),
        );
        if (defaultTargetPlatform == TargetPlatform.android &&
            _workingAndroidBaseUrl == null) {
          _workingAndroidBaseUrl = uri.host == '127.0.0.1'
              ? AppConstants.androidDeviceApiBaseUrl
              : AppConstants.androidEmulatorApiBaseUrl;
        }
      } on SocketException catch (_) {
        if (defaultTargetPlatform == TargetPlatform.android &&
            _workingAndroidBaseUrl == null &&
            _configuredBaseUrl == null &&
            uri.host == '127.0.0.1') {
          // If reverse proxy on 127.0.0.1 is unreachable, attempt emulator 10.0.2.2
          final altUri = uri.replace(host: '10.0.2.2');
          response = await requestFn(altUri, headers).timeout(
            const Duration(seconds: 30),
          );
          _workingAndroidBaseUrl = AppConstants.androidEmulatorApiBaseUrl;
        } else {
          rethrow;
        }
      }

      // Report connection success
      _ref.read(syncProvider.notifier).reportNetworkSuccess();

      // Handle 401 and try token refresh once
      if (response.statusCode == 401 && requiresAuth && !isRetry) {
        final refreshed = await _attemptTokenRefresh();
        if (refreshed) {
          return _sendWithRetry(
            uriBuilder,
            requestFn,
            requiresAuth: requiresAuth,
            isRetry: true,
          );
        }
      }

      return _handleResponse(response);
    } on SocketException catch (e) {
      _ref.read(syncProvider.notifier).reportNetworkError('No internet connection');
      throw ApiException(
        message: 'Unable to connect to server: ${e.message}',
        isOffline: true,
      );
    } on http.ClientException catch (e) {
      _ref.read(syncProvider.notifier).reportNetworkError('Connection error');
      throw ApiException(
        message: 'Network client error: ${e.message}',
        isOffline: true,
      );
    } on TimeoutException catch (_) {
      _ref.read(syncProvider.notifier).reportNetworkError('Connection timeout');
      throw ApiException(
        message: 'Connection timed out',
        isOffline: true,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      _ref.read(syncProvider.notifier).reportNetworkError('Connection failure');
      throw ApiException(
        message: 'Network communication failure: $e',
        isOffline: true,
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    String errorMessage = 'Request failed with status ${response.statusCode}';
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] != null) {
        errorMessage = decoded['message'].toString();
      } else if (decoded['error'] != null) {
        errorMessage = decoded['error'].toString();
      }
    }

    throw ApiException(
      message: errorMessage,
      statusCode: response.statusCode,
      data: decoded,
    );
  }

  Future<bool> _attemptTokenRefresh() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final rToken = await getRefreshToken();
      if (rToken == null || rToken.isEmpty) {
        await clearTokens();
        return false;
      }

      final uri = _buildUri('/auth/refresh', null);
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rToken}),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final newAccess = data?['accessToken'] as String?;
        final newRefresh = data?['refreshToken'] as String?;

        if (newAccess != null && newRefresh != null) {
          await saveTokens(accessToken: newAccess, refreshToken: newRefresh);
          return true;
        }
      }

      await clearTokens();
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref: ref);
});
