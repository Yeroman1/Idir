import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Structured cache entry with metadata
class CacheEntry<T> {
  const CacheEntry({
    required this.data,
    required this.cachedAt,
    this.etag,
  });

  final T data;
  final DateTime cachedAt;
  final String? etag;

  bool isOlderThan(Duration duration) =>
      DateTime.now().difference(cachedAt) > duration;
}

/// Service providing local offline persistence for API data
class OfflineCacheService {
  OfflineCacheService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static const String prefix = 'idir_cache_';
  static const String metaPrefix = 'idir_cache_meta_';

  /// Save raw JSON or Map/List to persistent local cache
  Future<void> save(String key, dynamic data, {String? etag}) async {
    try {
      final p = await _instance;
      final payload = jsonEncode(data);
      await p.setString('$prefix$key', payload);
      await p.setString(
        '$metaPrefix$key',
        jsonEncode({
          'cachedAt': DateTime.now().toIso8601String(),
          if (etag != null) 'etag': etag,
        }),
      );
    } catch (e) {
      debugPrint('[OfflineCache] Failed to save cache for $key: $e');
    }
  }

  /// Retrieve decoded JSON from local cache
  Future<dynamic> read(String key) async {
    try {
      final p = await _instance;
      final str = p.getString('$prefix$key');
      if (str == null) return null;
      return jsonDecode(str);
    } catch (e) {
      debugPrint('[OfflineCache] Failed to read cache for $key: $e');
      return null;
    }
  }

  /// Retrieve timestamp of last cached data
  Future<DateTime?> getLastCachedTime(String key) async {
    try {
      final p = await _instance;
      final metaStr = p.getString('$metaPrefix$key');
      if (metaStr == null) return null;
      final meta = jsonDecode(metaStr) as Map<String, dynamic>;
      final cachedAtStr = meta['cachedAt'] as String?;
      return cachedAtStr != null ? DateTime.tryParse(cachedAtStr) : null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a cache key exists
  Future<bool> has(String key) async {
    final p = await _instance;
    return p.containsKey('$prefix$key');
  }

  /// Remove specific cache entry
  Future<void> remove(String key) async {
    final p = await _instance;
    await p.remove('$prefix$key');
    await p.remove('$metaPrefix$key');
  }

  /// Clear all cached app data
  Future<void> clearAll() async {
    final p = await _instance;
    final keys = p.getKeys().where((k) => k.startsWith(prefix) || k.startsWith(metaPrefix));
    for (final k in keys) {
      await p.remove(k);
    }
  }
}

final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});
