import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/storage/offline_cache_service.dart';
import '../domain/models/announcement.dart';
import 'announcements_repository.dart';

class RestAnnouncementsRepository implements AnnouncementsRepository {
  RestAnnouncementsRepository({
    required ApiClient apiClient,
    required OfflineCacheService cacheService,
    required Ref ref,
    String idirId = AppConstants.defaultIdirId,
  })  : _api = apiClient,
        _cache = cacheService,
        _ref = ref,
        _idirId = idirId {
    _streamController = StreamController<List<Announcement>>.broadcast(
      onListen: () {
        _streamController.add(List.unmodifiable(_inMemoryItems));
      },
    );

    _ref.read(syncProvider.notifier).registerSyncCallback(getAnnouncements);
    _init();
  }

  final ApiClient _api;
  final OfflineCacheService _cache;
  final Ref _ref;
  final String _idirId;

  static const _cacheKey = 'cache_announcements';
  final List<Announcement> _inMemoryItems = [];
  late final StreamController<List<Announcement>> _streamController;

  Future<void> _init() async {
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    try {
      await getAnnouncements();
    } catch (_) {}
  }

  @override
  Stream<List<Announcement>> watchAnnouncements() => _streamController.stream;

  @override
  Future<List<Announcement>> getAnnouncements() async {
    try {
      final res = await _api.get('/idirs/$_idirId/announcements', queryParams: {'limit': 50});
      List<dynamic> rawItems = [];
      if (res is Map<String, dynamic> && res.containsKey('items')) {
        rawItems = res['items'] as List<dynamic>? ?? [];
      } else if (res is List<dynamic>) {
        rawItems = res;
      }

      final parsed = rawItems.map((e) => _fromBackendJson(e as Map<String, dynamic>)).toList();

      if (parsed.isNotEmpty) {
        _inMemoryItems.clear();
        _inMemoryItems.addAll(parsed);
        await _saveToCache(_inMemoryItems);
        _streamController.add(List.unmodifiable(_inMemoryItems));
        return List.unmodifiable(_inMemoryItems);
      }
    } on ApiException catch (e) {
      debugPrint('[RestAnnouncementsRepository] Live announcements failed (offline=${e.isOffline}): $e');
    } catch (e) {
      debugPrint('[RestAnnouncementsRepository] Error: $e');
    }

    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      _inMemoryItems.clear();
      _inMemoryItems.addAll(cached);
      _streamController.add(List.unmodifiable(_inMemoryItems));
      return List.unmodifiable(_inMemoryItems);
    }

    if (_inMemoryItems.isEmpty) {
      final seed = _generateDemoSeed();
      _inMemoryItems.addAll(seed);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }

    return List.unmodifiable(_inMemoryItems);
  }

  @override
  Future<Announcement?> getAnnouncementById(String id) async {
    final all = await getAnnouncements();
    return all.where((a) => a.id == id).firstOrNull;
  }

  @override
  Future<void> postAnnouncement(Announcement announcement) async {
    _inMemoryItems.insert(0, announcement);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    try {
      await _api.post(
        '/idirs/$_idirId/announcements',
        body: {
          'title': announcement.title,
          'content': announcement.body,
          'priority': announcement.pinned ? 'HIGH' : 'NORMAL',
        },
      );
    } catch (_) {
      _ref.read(syncProvider.notifier).enqueueItem(
            title: 'Announcement: ${announcement.title}',
            type: 'Community Announcement',
          );
    }
  }

  @override
  Future<void> togglePin(String id, bool pinned) async {
    final idx = _inMemoryItems.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _inMemoryItems[idx] = _inMemoryItems[idx].copyWith(pinned: pinned);
      await _saveToCache(_inMemoryItems);
      _streamController.add(List.unmodifiable(_inMemoryItems));
    }
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    _inMemoryItems.removeWhere((a) => a.id == id);
    await _saveToCache(_inMemoryItems);
    _streamController.add(List.unmodifiable(_inMemoryItems));

    try {
      await _api.delete('/idirs/$_idirId/announcements/$id');
    } catch (_) {}
  }

  Announcement _fromBackendJson(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? 'Notice';
    final content = json['content'] as String? ?? json['body'] as String? ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();
    final priority = json['priority'] as String?;

    return Announcement(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: title,
      body: content,
      category: AnnouncementCategory.general,
      postedBy: json['createdById'] as String? ?? 'chairperson',
      postedByName: 'Idir Committee',
      createdAt: createdAt,
      pinned: priority == 'HIGH' || json['pinned'] == true,
    );
  }

  Future<List<Announcement>> _loadFromCache() async {
    final cached = await _cache.read(_cacheKey);
    if (cached is List<dynamic>) {
      return cached.map((e) => Announcement.fromMap((e as Map<String, dynamic>)['id'] as String? ?? '', e)).toList();
    }
    return [];
  }

  Future<void> _saveToCache(List<Announcement> list) async {
    final jsonList = list.map((a) {
      final map = a.toMap();
      map['id'] = a.id;
      return map;
    }).toList();
    await _cache.save(_cacheKey, jsonList);
  }

  List<Announcement> _generateDemoSeed() {
    return [
      Announcement(
        id: 'ann_001',
        title: 'General Assembly & Annual Review Meeting',
        body:
            'All members are requested to attend the upcoming monthly review meeting at the community hall this Sunday at 9:00 AM. Annual balance sheet and audited records will be presented.',
        category: AnnouncementCategory.meeting,
        postedBy: 'demo_chair',
        postedByName: 'Abebe Tadesse (Chairperson)',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        pinned: true,
      ),
    ];
  }
}
