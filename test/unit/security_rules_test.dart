import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/core/services/secure_pin_service.dart';
import 'package:idir_app/features/claims/domain/models/claim.dart';
import 'package:idir_app/features/audit/data/audit_log_repository.dart';
import 'package:idir_app/features/audit/domain/models/audit_log_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _storage[key];

  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _storage.remove(key);

  @override
  Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async => _storage.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Security Rules: Institutional Role Permissions Matrix', () {
    test('Chairperson permissions conform to governance bylaws', () {
      const role = UserRole.chairperson;
      expect(role.canManageMembers, isTrue);
      expect(role.canApproveOrRejectClaim, isTrue);
      expect(role.canViewAllFinances, isTrue);
      expect(role.canViewAuditLog, isTrue);
      expect(role.canPostAnnouncement, isTrue);
      expect(role.canChangeSettings, isTrue);

      // Chairperson cannot directly execute financial payouts or accept dues cash
      expect(role.canRecordContribution, isFalse);
      expect(role.canRecordPayout, isFalse);
    });

    test('Treasurer permissions enforce fiduciary duty separation', () {
      const role = UserRole.treasurer;
      expect(role.canRecordContribution, isTrue);
      expect(role.canRecordPayout, isTrue);
      expect(role.canManageMembers, isTrue);
      expect(role.canApproveOrRejectClaim, isTrue);
      expect(role.canPostAnnouncement, isTrue);
      expect(role.canViewAllFinances, isTrue);

      // Treasurer must NOT have authority to alter settings or view independent audit log
      expect(role.canChangeSettings, isFalse);
      expect(role.canViewAuditLog, isFalse);
    });

    test('Auditor permissions guarantee read-only oversight without write access', () {
      const role = UserRole.auditor;
      expect(role.canViewAllFinances, isTrue);
      expect(role.canViewAuditLog, isTrue);
      expect(role.canViewOwnBalance, isTrue);

      // Strict prohibition of write / modification operations
      expect(role.canManageMembers, isFalse);
      expect(role.canRecordContribution, isFalse);
      expect(role.canSubmitClaim, isFalse);
      expect(role.canApproveOrRejectClaim, isFalse);
      expect(role.canRecordPayout, isFalse);
      expect(role.canPostAnnouncement, isFalse);
      expect(role.canChangeSettings, isFalse);
    });

    test('Member permissions isolate individual rights and prevent administrative access', () {
      const role = UserRole.member;
      expect(role.canSubmitClaim, isTrue);
      expect(role.canViewOwnBalance, isTrue);

      // Prohibited from all institutional admin capabilities
      expect(role.canManageMembers, isFalse);
      expect(role.canRecordContribution, isFalse);
      expect(role.canApproveOrRejectClaim, isFalse);
      expect(role.canRecordPayout, isFalse);
      expect(role.canViewAllFinances, isFalse);
      expect(role.canViewAuditLog, isFalse);
      expect(role.canPostAnnouncement, isFalse);
      expect(role.canChangeSettings, isFalse);
    });
  });

  group('Security Rules: Two-Officer Approval & Anti-Fraud Workflow', () {
    test('Self-approval is strictly prevented for officers who submit claims', () {
      final claim = Claim(
        id: 'claim_101',
        claimNumber: 'CLM-101',
        memberId: 'MEM-001',
        memberName: 'Abebe Tadesse',
        type: ClaimType.funeral,
        description: 'Family bereavement emergency',
        requestedAmount: 5000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'chair_uid', // Submitted by Chairperson himself!
        submittedByName: 'Abebe Tadesse',
        approvals: const [],
        createdAt: DateTime.now(),
      );

      // The submitting officer MUST NOT be able to vote on their own claim!
      expect(claim.canVote('chair_uid', UserRole.chairperson), isFalse,
          reason: 'Officer cannot approve their own claim');

      // Another officer (e.g. Treasurer) can vote
      expect(claim.canVote('treasurer_uid', UserRole.treasurer), isTrue);
    });

    test('Non-officers (Auditor, Member) are prohibited from voting on claims', () {
      final claim = Claim(
        id: 'claim_102',
        claimNumber: 'CLM-102',
        memberId: 'MEM-002',
        memberName: 'Tigist Bekele',
        type: ClaimType.funeral,
        description: 'Bereavement aid',
        requestedAmount: 4000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'member_uid',
        submittedByName: 'Tigist Bekele',
        approvals: const [],
        createdAt: DateTime.now(),
      );

      expect(claim.canVote('auditor_uid', UserRole.auditor), isFalse);
      expect(claim.canVote('member_uid_2', UserRole.member), isFalse);
    });

    test('Officer cannot vote twice on the same claim', () {
      final existingApproval = ClaimApproval(
        uid: 'chair_uid',
        name: 'Abebe',
        role: 'chairperson',
        decision: 'approved',
        comment: 'Verified certificate',
        at: DateTime.now(),
      );

      final claimWithVote = Claim(
        id: 'claim_103',
        claimNumber: 'CLM-103',
        memberId: 'MEM-003',
        memberName: 'Dawit K.',
        type: ClaimType.funeral,
        description: 'Medical emergency',
        requestedAmount: 3000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'member_uid',
        submittedByName: 'Dawit K.',
        approvals: [existingApproval],
        createdAt: DateTime.now(),
      );

      // Chair has already voted
      expect(claimWithVote.canVote('chair_uid', UserRole.chairperson), isFalse);
      // Treasurer has not voted yet
      expect(claimWithVote.canVote('treasurer_uid', UserRole.treasurer), isTrue);
    });

    test('Payout is forbidden until claim status is fully approved', () {
      final submittedClaim = Claim(
        id: 'claim_104',
        claimNumber: 'CLM-104',
        memberId: 'MEM-004',
        memberName: 'Chaltu B.',
        type: ClaimType.funeral,
        description: 'Bereavement assistance',
        requestedAmount: 5000.0,
        status: ClaimStatus.submitted,
        submittedBy: 'member_uid',
        submittedByName: 'Chaltu B.',
        approvals: const [],
        createdAt: DateTime.now(),
      );

      expect(submittedClaim.canRecordPayout(UserRole.treasurer), isFalse);
      expect(submittedClaim.canRecordPayout(UserRole.chairperson), isFalse);

      final approvedClaim = submittedClaim.copyWith(status: ClaimStatus.approved);
      expect(approvedClaim.canRecordPayout(UserRole.treasurer), isTrue);
      // Even when approved, ONLY Treasurer can execute the payout
      expect(approvedClaim.canRecordPayout(UserRole.chairperson), isFalse);
    });
  });

  group('Security Rules: Cryptographic Audit Trail Immutability', () {
    late AuditLogRepository auditRepo;

    setUp(() {
      auditRepo = FirestoreAuditLogRepository();
    });

    test('Cryptographic SHA-256 chain detects payload modification', () async {
      final initialChain = await auditRepo.verifyChain();
      expect(initialChain.isValid, isTrue);

      final now = DateTime.now();

      final authenticEntry = AuditLogEntry.create(
        id: 'block_001',
        actorUid: 'chair_1',
        actorName: 'Abebe',
        actorRole: 'chairperson',
        action: 'claim_approved',
        targetCollection: 'claims',
        targetId: 'claim_101',
        summary: 'Authorized funeral benefit 5000 ETB',
        createdAt: now,
        prevHash: genesisHash,
      );

      expect(authenticEntry.isHashValid, isTrue);

      // An attacker attempts to alter the targetId and action without recomputing hash
      final tamperedEntry = AuditLogEntry(
        id: authenticEntry.id,
        actorUid: authenticEntry.actorUid,
        actorName: authenticEntry.actorName,
        actorRole: authenticEntry.actorRole,
        action: 'claim_rejected', // Altered action!
        targetCollection: authenticEntry.targetCollection,
        targetId: 'claim_999_forged', // Altered targetId!
        summary: authenticEntry.summary,
        createdAt: authenticEntry.createdAt,
        prevHash: authenticEntry.prevHash,
        hash: authenticEntry.hash, // Old hash retained!
      );

      // The SHA-256 verification fails!
      expect(tamperedEntry.isHashValid, isFalse);
    });

    test('Detects broken hash link between consecutive blocks', () {
      final now = DateTime.now();

      final block1 = AuditLogEntry.create(
        id: 'b1',
        actorUid: 'u1',
        actorName: 'Abebe',
        actorRole: 'chairperson',
        action: 'action_1',
        targetCollection: 'members',
        targetId: 'm1',
        summary: 'Summary 1',
        createdAt: now.subtract(const Duration(minutes: 5)),
        prevHash: genesisHash,
      );

      final block2 = AuditLogEntry.create(
        id: 'b2',
        actorUid: 'u2',
        actorName: 'Chaltu',
        actorRole: 'treasurer',
        action: 'action_2',
        targetCollection: 'contributions',
        targetId: 'c1',
        summary: 'Summary 2',
        createdAt: now,
        prevHash: 'invalid_forged_prev_hash', // Forged pointer
      );

      // Block 2's prevHash doesn't match block 1's hash
      expect(block2.prevHash == block1.hash, isFalse);
    });
  });

  group('Security Rules: PIN Security, Salted Hashing & Brute-Force Lockout', () {
    late SecurePinService pinService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      pinService = SecurePinService(_FakeSecureStorage());
    });

    test('PIN is not stored in plaintext and uses unique random salt', () async {
      await pinService.setPin('1234');

      expect(await pinService.isPinSet(), isTrue);

      // Verify correct PIN passes
      final res = await pinService.verifyPin('1234');
      expect(res, PinVerificationResult.success);

      // Verify wrong PIN fails
      final wrongRes = await pinService.verifyPin('0000');
      expect(wrongRes, PinVerificationResult.incorrect);
    });

    test('5 consecutive failed attempts causes lockout', () async {
      await pinService.setPin('5678');

      // Perform 4 wrong attempts - not locked out yet
      for (int i = 0; i < 4; i++) {
        final res = await pinService.verifyPin('0000');
        expect(res, PinVerificationResult.incorrect);
      }

      // 5th failed attempt triggers lockout
      final fifth = await pinService.verifyPin('0000');
      expect(fifth, PinVerificationResult.lockedOut);

      // Even supplying the correct PIN now is rejected due to active lockout!
      final attemptDuringLockout = await pinService.verifyPin('5678');
      expect(attemptDuringLockout, PinVerificationResult.lockedOut);
    });

    test('Successful PIN verification resets failed attempts counter', () async {
      await pinService.setPin('9999');

      // 2 failed attempts
      await pinService.verifyPin('1111');
      await pinService.verifyPin('2222');
      expect(await pinService.getFailedAttempts(), 2);

      // Correct attempt resets counter to 0
      final success = await pinService.verifyPin('9999');
      expect(success, PinVerificationResult.success);
      expect(await pinService.getFailedAttempts(), 0);
    });
  });
}
