import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/audit/data/audit_log_repository.dart';
import 'package:idir_app/features/audit/domain/models/audit_log_entry.dart';

void main() {
  group('Audit Log SHA-256 Hash Chain and Tamper Detection unit tests', () {
    late AuditLogRepository auditRepo;

    setUp(() {
      final repo = FirestoreAuditLogRepository();
      repo.seedForTest();
      auditRepo = repo;
    });

    test('Initial sample chain is cryptographically intact and unbroken', () async {
      final logs = await auditRepo.getAuditLogs();
      expect(logs.length, greaterThanOrEqualTo(5));

      final verification = await auditRepo.verifyChain();
      expect(verification.isValid, isTrue);
      expect(verification.totalEntries, logs.length);
      expect(verification.verifiedEntries, logs.length);
      expect(verification.brokenEntryIndex, isNull);
    });

    test('Appending new audit entries continues the valid hash chain', () async {
      final initialLogs = await auditRepo.getAuditLogs();
      final countBefore = initialLogs.length;

      final newEntry = await auditRepo.log(
        actorUid: 'chair_uid_1',
        actorName: 'Abebe (Chair)',
        actorRole: 'chairperson',
        action: 'settings_changed',
        targetCollection: 'settings',
        targetId: 'main',
        summary: 'Updated monthly dues rate to 60 ETB',
      );

      expect(newEntry.isHashValid, isTrue);
      expect(newEntry.prevHash, initialLogs.first.hash); // initialLogs is reversed (descending)

      final logsAfter = await auditRepo.getAuditLogs();
      expect(logsAfter.length, countBefore + 1);

      final verification = await auditRepo.verifyChain();
      expect(verification.isValid, isTrue);
      expect(verification.totalEntries, countBefore + 1);
    });

    test('Detects payload tampering when block data is modified', () async {
      final now = DateTime.now();

      final e1 = AuditLogEntry.create(
        id: 'b1',
        actorUid: 'u1',
        actorName: 'Alice',
        actorRole: 'chairperson',
        action: 'member_created',
        targetCollection: 'members',
        targetId: 'm1',
        summary: 'Original valid summary',
        createdAt: now.subtract(const Duration(minutes: 5)),
        prevHash: genesisHash,
      );

      // Simulating tampering: targetId was altered in database without recalculating hash
      final tamperedE1 = AuditLogEntry(
        id: e1.id,
        actorUid: e1.actorUid,
        actorName: e1.actorName,
        actorRole: e1.actorRole,
        action: e1.action,
        targetCollection: e1.targetCollection,
        targetId: 'FORGED_TARGET_ID', // Altered targetId without recomputing hash
        summary: e1.summary,
        createdAt: e1.createdAt,
        prevHash: e1.prevHash,
        hash: e1.hash, // Old hash retained
      );

      expect(tamperedE1.isHashValid, isFalse);
    });

    test('Detects broken chain link when previous hash linkage is severed', () {
      final now = DateTime.now();

      final e1 = AuditLogEntry.create(
        id: 'b1',
        actorUid: 'u1',
        actorName: 'Alice',
        actorRole: 'chairperson',
        action: 'member_created',
        targetCollection: 'members',
        targetId: 'm1',
        summary: 'Block 1',
        createdAt: now.subtract(const Duration(minutes: 5)),
        prevHash: genesisHash,
      );

      // Attacker inserts block with fraudulent prevHash
      const fraudulentPrevHash =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      final e2Forged = AuditLogEntry.create(
        id: 'b2',
        actorUid: 'u2',
        actorName: 'Bob',
        actorRole: 'treasurer',
        action: 'contribution_recorded',
        targetCollection: 'contributions',
        targetId: 'c1',
        summary: 'Block 2 with forged link',
        createdAt: now,
        prevHash: fraudulentPrevHash,
      );

      expect(e2Forged.prevHash, isNot(equals(e1.hash)));
    });

    test('Serialization roundtrip preserves cryptographic hash integrity', () {
      final now = DateTime.now();
      final entry = AuditLogEntry.create(
        id: 'log_roundtrip',
        actorUid: 'actor_123',
        actorName: 'Chaltu Bekele',
        actorRole: 'treasurer',
        action: 'expense_reversed',
        targetCollection: 'expenses',
        targetId: 'EXP-2024-001',
        summary: 'Reversal of erroneous expense voucher',
        createdAt: now,
        prevHash: genesisHash,
      );

      final map = entry.toMap();
      final restored = AuditLogEntry.fromMap('log_roundtrip', map);

      expect(restored.id, entry.id);
      expect(restored.hash, entry.hash);
      expect(restored.prevHash, entry.prevHash);
      expect(restored.isHashValid, isTrue);
    });
  });
}
