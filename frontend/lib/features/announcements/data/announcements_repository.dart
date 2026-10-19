import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
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
    final now = DateTime.now();

    _localCache.addAll([
      Announcement(
        id: 'ann_001',
        title: 'General Assembly & Annual Review Meeting',
        body:
            'All members are requested to attend the upcoming monthly review meeting at the community hall this Sunday at 9:00 AM. Annual balance sheet and audited records will be presented.',
        category: AnnouncementCategory.meeting,
        postedBy: 'demo_chair',
        postedByName: 'Abebe Bikila (Chairperson)',
        createdAt: now.subtract(const Duration(days: 2)),
        pinned: true,
      ),
      Announcement(
        id: 'ann_002',
        title: 'Bereavement Notice: Condolences to Member MEM-002',
        body:
            'Our deepest condolences to the family of Fatuma Mohammed on the passing of her father. The association committee has disbursed condolence assistance and tent utensils.',
        category: AnnouncementCategory.funeral,
        postedBy: 'demo_chair',
        postedByName: 'Abebe Bikila (Chairperson)',
        createdAt: now.subtract(const Duration(days: 3)),
        pinned: false,
      ),
      Announcement(
        id: 'ann_003',
        title: 'Monthly Dues Reminder for Current Cycle',
        body:
            'Members are kindly reminded to record their monthly dues with the treasurer before the 25th of this month to remain in good standing.',
        category: AnnouncementCategory.reminder,
        postedBy: 'demo_treasurer',
        postedByName: 'Chaltu Bekele (Treasurer)',
        createdAt: now.subtract(const Duration(days: 6)),
        pinned: false,
      ),
      Announcement(
        id: 'ann_004',
        title: 'Community Tent & Utensils Inspection',
        body:
            'Routine inspection and cleaning of mutual-aid tents, benches, and cooking utensils completed by the administrative committee.',
        category: AnnouncementCategory.general,
        postedBy: 'demo_treasurer',
        postedByName: 'Chaltu Bekele (Treasurer)',
        createdAt: now.subtract(const Duration(days: 12)),
        pinned: false,
      ),
    ]);
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
  return RestAnnouncementsRepository(
    apiClient: apiClient,
    cacheService: cache,
    ref: ref,
  );
});

final announcementsStreamProvider = StreamProvider<List<Announcement>>((ref) {
  final repo = ref.watch(announcementsRepositoryProvider);
  return repo.watchAnnouncements();
});
