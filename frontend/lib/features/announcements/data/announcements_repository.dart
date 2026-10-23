import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/active_idir_provider.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../domain/models/announcement.dart';
import 'rest_announcements_repository.dart';

abstract class AnnouncementsRepository {
  Stream<List<Announcement>> watchAnnouncements();
  Future<List<Announcement>> getAnnouncements();
  Future<Announcement?> getAnnouncementById(String id);
  Future<void> postAnnouncement(Announcement announcement);
  Future<void> togglePin(String id, bool pinned);
  Future<void> deleteAnnouncement(String id);
}

class FirestoreAnnouncementsRepository implements AnnouncementsRepository {
  FirestoreAnnouncementsRepository({FirebaseFirestore? firestore})
      : _fs = firestore {
    _initLocalCache();
  }

  final FirebaseFirestore? _fs;
  final List<Announcement> _localCache = [];
  final _streamController = StreamController<List<Announcement>>.broadcast();

  void _initLocalCache() {
    // No mock demo data in production real application
  }

  List<Announcement> _sortedList(List<Announcement> list) {
    final copy = List<Announcement>.from(list);
    copy.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  @override
  Stream<List<Announcement>> watchAnnouncements() async* {
    final fs = _fs;
    if (fs != null) {
      try {
        final stream = fs
            .collection(AppConstants.colAnnouncements)
            .orderBy('createdAt', descending: true)
            .snapshots();

        await for (final snapshot in stream) {
          if (snapshot.docs.isNotEmpty) {
            final list = snapshot.docs
                .map((d) => Announcement.fromMap(d.id, d.data()))
                .toList();
            yield _sortedList(list);
            continue;
          }
          yield _sortedList(_localCache);
        }
        return;
      } catch (e) {
        debugPrint('Firestore watchAnnouncements fallback: $e');
      }
    }

    yield _sortedList(_localCache);
    yield* _streamController.stream;
  }

  @override
  Future<List<Announcement>> getAnnouncements() async {
    final fs = _fs;
    if (fs != null) {
      try {
        final snapshot = await fs
            .collection(AppConstants.colAnnouncements)
            .orderBy('createdAt', descending: true)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs
              .map((d) => Announcement.fromMap(d.id, d.data()))
              .toList();
          return _sortedList(list);
        }
      } catch (e) {
        debugPrint('Firestore getAnnouncements fallback: $e');
      }
    }
    return _sortedList(_localCache);
  }

  @override
  Future<Announcement?> getAnnouncementById(String id) async {
    final all = await getAnnouncements();
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> postAnnouncement(Announcement announcement) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colAnnouncements)
            .doc(announcement.id)
            .set(announcement.toMap());
      } catch (e) {
        debugPrint('Firestore postAnnouncement fallback: $e');
      }
    }

    _localCache.removeWhere((a) => a.id == announcement.id);
    _localCache.insert(0, announcement);
    _streamController.add(_sortedList(_localCache));
  }

  @override
  Future<void> togglePin(String id, bool pinned) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs
            .collection(AppConstants.colAnnouncements)
            .doc(id)
            .update({'pinned': pinned});
      } catch (e) {
        debugPrint('Firestore togglePin fallback: $e');
      }
    }

    final index = _localCache.indexWhere((a) => a.id == id);
    if (index != -1) {
      _localCache[index] = _localCache[index].copyWith(pinned: pinned);
      _streamController.add(_sortedList(_localCache));
    }
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    final fs = _fs;
    if (fs != null) {
      try {
        await fs.collection(AppConstants.colAnnouncements).doc(id).delete();
      } catch (e) {
        debugPrint('Firestore deleteAnnouncement fallback: $e');
      }
    }

    _localCache.removeWhere((a) => a.id == id);
    _streamController.add(_sortedList(_localCache));
  }
}

final announcementsRepositoryProvider =
    Provider<AnnouncementsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final activeIdirId =
      ref.watch(activeIdirIdProvider) ?? AppConstants.defaultIdirId;
  return RestAnnouncementsRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
    idirId: activeIdirId,
  );
});

final announcementsStreamProvider = StreamProvider<List<Announcement>>((ref) async* {
  final repo = ref.watch(announcementsRepositoryProvider);
  repo.getAnnouncements();
  yield* repo.watchAnnouncements();
});
