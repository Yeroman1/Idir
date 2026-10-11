import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';

void main() {
  group('UserRole permissions matrix verification', () {
    test('Chairperson permissions', () {
      const role = UserRole.chairperson;
      expect(role.canManageMembers, isTrue);
      expect(role.canRecordContribution, isFalse);
      expect(role.canSubmitClaim, isTrue);
      expect(role.canApproveOrRejectClaim, isTrue);
      expect(role.canRecordPayout, isFalse);
      expect(role.canPostAnnouncement, isTrue);
      expect(role.canViewAllFinances, isTrue);
      expect(role.canViewAuditLog, isTrue);
      expect(role.canViewOwnBalance, isTrue);
      expect(role.canChangeSettings, isTrue);
    });

    test('Treasurer permissions', () {
      const role = UserRole.treasurer;
      expect(role.canManageMembers, isTrue);
      expect(role.canRecordContribution, isTrue);
      expect(role.canSubmitClaim, isTrue);
      expect(role.canApproveOrRejectClaim, isTrue);
      expect(role.canRecordPayout, isTrue);
      expect(role.canPostAnnouncement, isTrue);
      expect(role.canViewAllFinances, isTrue);
      expect(role.canViewAuditLog, isFalse);
      expect(role.canViewOwnBalance, isTrue);
      expect(role.canChangeSettings, isFalse);
    });

    test('Auditor permissions', () {
      const role = UserRole.auditor;
      expect(role.canManageMembers, isFalse);
      expect(role.canRecordContribution, isFalse);
      expect(role.canSubmitClaim, isFalse);
      expect(role.canApproveOrRejectClaim, isFalse);
      expect(role.canRecordPayout, isFalse);
      expect(role.canPostAnnouncement, isFalse);
      expect(role.canViewAllFinances, isTrue);
      expect(role.canViewAuditLog, isTrue);
      expect(role.canViewOwnBalance, isTrue);
      expect(role.canChangeSettings, isFalse);
    });

    test('Member permissions', () {
      const role = UserRole.member;
      expect(role.canManageMembers, isFalse);
      expect(role.canRecordContribution, isFalse);
      expect(role.canSubmitClaim, isTrue);
      expect(role.canApproveOrRejectClaim, isFalse);
      expect(role.canRecordPayout, isFalse);
      expect(role.canPostAnnouncement, isFalse);
      expect(role.canViewAllFinances, isFalse);
      expect(role.canViewAuditLog, isFalse);
      expect(role.canViewOwnBalance, isTrue);
      expect(role.canChangeSettings, isFalse);
    });

    test('AppUser serialization and deserialization', () {
      final now = DateTime.now();
      final user = AppUser(
        uid: 'u123',
        name: 'Abebe Bikila',
        phone: '+251911223344',
        role: UserRole.treasurer,
        memberId: 'M-001',
        isActive: true,
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['name'], 'Abebe Bikila');
      expect(map['role'], 'treasurer');
      expect(map['memberId'], 'M-001');

      final fromMap = AppUser.fromMap('u123', const {
        'name': 'Abebe Bikila',
        'phone': '+251911223344',
        'role': 'treasurer',
        'memberId': 'M-001',
        'isActive': true,
        'createdAt': null,
      });

      expect(fromMap.role, UserRole.treasurer);
      expect(fromMap.name, 'Abebe Bikila');
      expect(fromMap.memberId, 'M-001');
    });
  });
}
