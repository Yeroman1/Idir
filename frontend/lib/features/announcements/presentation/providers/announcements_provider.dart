import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/announcements_repository.dart';
import '../../domain/models/announcement.dart';

final announcementsCategoryFilterProvider =
    StateProvider<AnnouncementCategory?>((ref) => null);
final announcementsSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final announcementsAsync = ref.watch(announcementsStreamProvider);
  final filter = ref.watch(announcementsCategoryFilterProvider);
  final query =
      ref.watch(announcementsSearchQueryProvider).trim().toLowerCase();
  final all = announcementsAsync.value ?? [];

  return all.where((a) {
    if (filter != null && a.category != filter) {
      return false;
    }
    if (query.isNotEmpty) {
      final matchesTitle = a.title.toLowerCase().contains(query);
      final matchesBody = a.body.toLowerCase().contains(query);
      final matchesAuthor = a.postedByName.toLowerCase().contains(query);
      return matchesTitle || matchesBody || matchesAuthor;
    }
    return true;
  }).toList();
});

class AnnouncementActionNotifier extends StateNotifier<AsyncValue<void>> {
  AnnouncementActionNotifier(this._repository)
      : super(const AsyncValue.data(null));

  final AnnouncementsRepository _repository;

  Future<bool> postAnnouncement(Announcement announcement) async {
    state = const AsyncValue.loading();
    try {
      await _repository.postAnnouncement(announcement);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> togglePin(String id, bool pinned) async {
    state = const AsyncValue.loading();
    try {
      await _repository.togglePin(id, pinned);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteAnnouncement(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final announcementActionNotifierProvider = StateNotifierProvider<
    AnnouncementActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(announcementsRepositoryProvider);
  return AnnouncementActionNotifier(repo);
});
