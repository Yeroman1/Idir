import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/features/announcements/data/announcements_repository.dart';
import 'package:idir_app/features/announcements/domain/models/announcement.dart';

void main() {
  group('Announcement Model Tests', () {
    test('serializes toMap and fromMap correctly', () {
      final now = DateTime(2026, 10, 7, 12, 0);
      final ann = Announcement(
        id: 'ann_test_01',
        title: 'Emergency General Assembly',
        body: 'Important meeting regarding community hall repairs.',
        category: AnnouncementCategory.meeting,
        postedBy: 'user_chair_01',
        postedByName: 'Chairperson Abebe',
        createdAt: now,
        pinned: true,
      );

      final map = ann.toMap();
      expect(map['title'], equals('Emergency General Assembly'));
      expect(map['category'], equals('meeting'));
      expect(map['pinned'], isTrue);

      final reconstructed = Announcement.fromMap('ann_test_01', map);
      expect(reconstructed.id, equals(ann.id));
      expect(reconstructed.title, equals(ann.title));
      expect(reconstructed.body, equals(ann.body));
      expect(reconstructed.category, equals(AnnouncementCategory.meeting));
      expect(reconstructed.postedBy, equals(ann.postedBy));
      expect(reconstructed.postedByName, equals(ann.postedByName));
      expect(reconstructed.pinned, isTrue);
    });

    test('AnnouncementCategory extension converts from/to string', () {
      expect(AnnouncementCategory.meeting.name, equals('meeting'));
      expect(AnnouncementCategory.funeral.name, equals('funeral'));
      expect(AnnouncementCategory.reminder.name, equals('reminder'));
      expect(AnnouncementCategory.general.name, equals('general'));

      expect(AnnouncementCategoryX.fromString('meeting'),
          equals(AnnouncementCategory.meeting));
      expect(AnnouncementCategoryX.fromString('funeral'),
          equals(AnnouncementCategory.funeral));
      expect(AnnouncementCategoryX.fromString('reminder'),
          equals(AnnouncementCategory.reminder));
      expect(AnnouncementCategoryX.fromString('other'),
          equals(AnnouncementCategory.general));
    });
  });

  group('FirestoreAnnouncementsRepository Tests', () {
    late FirestoreAnnouncementsRepository repo;

    setUp(() {
      // Instantiated with null firestore to exercise local fallback cache
      repo = FirestoreAnnouncementsRepository(firestore: null);
    });

    test('loads default seed announcements with pinned item first', () async {
      final items = await repo.getAnnouncements();
      expect(items.length, greaterThanOrEqualTo(4));
      // First announcement must be pinned
      expect(items.first.pinned, isTrue);
      expect(items.first.title, contains('General Assembly'));
    });

    test('watchAnnouncements emits initial sorted list', () async {
      final items = await repo.watchAnnouncements().first;
      expect(items.length, greaterThanOrEqualTo(4));
      expect(items.first.pinned, isTrue);
    });

    test('posting new unpinned announcement puts it after pinned ones',
        () async {
      final newAnn = Announcement(
        id: 'ann_new_999',
        title: 'New Water Supply Notice',
        body: 'Water supply will be temporarily paused for maintenance.',
        category: AnnouncementCategory.general,
        postedBy: 'user_treasurer',
        postedByName: 'Treasurer Chaltu',
        createdAt: DateTime.now(),
        pinned: false,
      );

      await repo.postAnnouncement(newAnn);

      final items = await repo.getAnnouncements();
      expect(items.any((a) => a.id == 'ann_new_999'), isTrue);
      // Pinned items must still precede this newly added unpinned item
      final pinnedCount = items.where((a) => a.pinned).length;
      final newIndex = items.indexWhere((a) => a.id == 'ann_new_999');
      expect(newIndex, greaterThanOrEqualTo(pinnedCount));
    });

    test('posting new pinned announcement places it at the very top', () async {
      final urgentPinned = Announcement(
        id: 'ann_urgent_top',
        title: 'URGENT: Road Closure',
        body: 'Main road to idir office closed.',
        category: AnnouncementCategory.reminder,
        postedBy: 'user_chair',
        postedByName: 'Chairperson Abebe',
        createdAt: DateTime.now().add(const Duration(seconds: 1)),
        pinned: true,
      );

      await repo.postAnnouncement(urgentPinned);

      final items = await repo.getAnnouncements();
      expect(items.first.id, equals('ann_urgent_top'));
      expect(items.first.pinned, isTrue);
    });

    test('togglePin moves unpinned announcement to pinned and vice versa',
        () async {
      // ann_002 is originally unpinned
      final original = await repo.getAnnouncementById('ann_002');
      expect(original, isNotNull);
      expect(original!.pinned, isFalse);

      await repo.togglePin('ann_002', true);

      final updated = await repo.getAnnouncementById('ann_002');
      expect(updated!.pinned, isTrue);

      final items = await repo.getAnnouncements();
      // Since it's now pinned, it should be among the top items
      final index = items.indexWhere((a) => a.id == 'ann_002');
      final pinnedCount = items.where((a) => a.pinned).length;
      expect(index, lessThan(pinnedCount));

      // Toggle back to unpinned
      await repo.togglePin('ann_002', false);
      final unpinned = await repo.getAnnouncementById('ann_002');
      expect(unpinned!.pinned, isFalse);
    });

    test('deleteAnnouncement removes entry from cache and streams', () async {
      final initialCount = (await repo.getAnnouncements()).length;
      await repo.deleteAnnouncement('ann_003');

      final items = await repo.getAnnouncements();
      expect(items.length, equals(initialCount - 1));
      expect(items.any((a) => a.id == 'ann_003'), isFalse);
    });
  });

  group('Institutional Role Permissions for Announcements', () {
    test('only Chairperson and Treasurer can post announcements', () {
      // Chairperson
      expect(UserRole.chairperson.canPostAnnouncement, isTrue);

      // Treasurer
      expect(UserRole.treasurer.canPostAnnouncement, isTrue);

      // Auditor: read-only compliance observer
      expect(UserRole.auditor.canPostAnnouncement, isFalse);

      // Member: strictly recipient / read-only
      expect(UserRole.member.canPostAnnouncement, isFalse);
    });
  });
}
