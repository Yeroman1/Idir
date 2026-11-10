import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/cooperation/domain/models/cooperation_models.dart';

void main() {
  group('Cross-Idir Cooperation Domain Models Tests', () {
    test('CooperationAgreement serialization and status parsing', () {
      final now = DateTime(2026, 11, 4, 18, 0);
      final agreement = CooperationAgreement(
        id: 'agree-1',
        idirAId: 'idir-a',
        idirBId: 'idir-b',
        idirAName: 'Bole Medhanealem Idir',
        idirBName: 'Yeka Michael Idir',
        purpose: 'Joint neighborhood emergency response',
        description: 'Cooperate on major community incidents and assistance',
        status: CooperationStatus.active,
        proposedDuration: 90,
        startDate: now,
        createdAt: now,
        participants: [
          CooperationParticipant(
            id: 'p1',
            agreementId: 'agree-1',
            idirId: 'idir-a',
            idirName: 'Bole Medhanealem Idir',
            status: CooperationStatus.active,
            authorizedByUserName: 'Chairperson Abebe',
            authorizedAt: now,
          ),
          CooperationParticipant(
            id: 'p2',
            agreementId: 'agree-1',
            idirId: 'idir-b',
            idirName: 'Yeka Michael Idir',
            status: CooperationStatus.active,
            authorizedByUserName: 'Chairperson Kebede',
            authorizedAt: now,
          ),
        ],
      );

      final map = agreement.toMap();
      expect(map['id'], equals('agree-1'));
      expect(map['status'], equals('ACTIVE'));
      expect(map['purpose'], equals('Joint neighborhood emergency response'));
      expect((map['participants'] as List).length, equals(2));

      final reconstructed = CooperationAgreement.fromMap(map);
      expect(reconstructed.id, equals(agreement.id));
      expect(reconstructed.idirAName, equals('Bole Medhanealem Idir'));
      expect(reconstructed.status, equals(CooperationStatus.active));
      expect(reconstructed.participants.length, equals(2));
      expect(reconstructed.participants.first.authorizedByUserName, equals('Chairperson Abebe'));
    });

    test('JointInitiative serialization and task parsing', () {
      final now = DateTime(2026, 11, 4, 18, 0);
      final initiative = JointInitiative(
        id: 'init-1',
        agreementId: 'agree-1',
        title: 'Community Flood Defense Drainage',
        description: 'Clear and widen drainage trenches between kebeles',
        objectives: 'Prevent seasonal road flooding',
        category: InitiativeCategory.emergencyAssistance,
        status: InitiativeStatus.active,
        ownerIdirId: 'idir-a',
        ownerIdirName: 'Bole Medhanealem Idir',
        createdAt: now,
        updates: [
          InitiativeUpdate(
            id: 'up-1',
            content: 'Phase 1 trench digging completed',
            postedByName: 'Coordinator Dawit',
            createdAt: now,
          ),
        ],
        tasks: const [
          InitiativeTask(
            id: 'task-1',
            title: 'Procure sandbags and gravel',
            responsibleIdirId: 'idir-b',
            responsibleIdirName: 'Yeka Michael Idir',
            isCompleted: false,
          ),
        ],
      );

      final map = initiative.toMap();
      expect(map['category'], equals('EMERGENCY_ASSISTANCE'));
      expect(map['status'], equals('ACTIVE'));
      expect((map['updates'] as List).length, equals(1));
      expect((map['tasks'] as List).length, equals(1));

      final reconstructed = JointInitiative.fromMap(map);
      expect(reconstructed.title, equals(initiative.title));
      expect(reconstructed.category, equals(InitiativeCategory.emergencyAssistance));
      expect(reconstructed.tasks.first.responsibleIdirName, equals('Yeka Michael Idir'));
    });

    test('CrossIdirEmergency and EmergencyResponse models', () {
      final now = DateTime(2026, 11, 4, 18, 0);
      final emergency = CrossIdirEmergency(
        id: 'emg-1',
        agreementId: 'agree-1',
        requestingIdirName: 'Bole Medhanealem Idir',
        title: 'Residential Fire in Kebele 08',
        description: 'Ten households displaced by fire',
        emergencyType: 'FIRE',
        urgency: EmergencyUrgency.critical,
        status: EmergencyStatus.acknowledged,
        outcomeSummary: 'Shelter provided and relief distributed',
        createdAt: now,
        responses: [
          EmergencyResponse(
            id: 'resp-1',
            respondingIdirName: 'Yeka Michael Idir',
            message: 'Sending emergency blankets and kitchen utensils',
            commitmentNote: '50 emergency packs',
            respondedByName: 'Secretary Almaz',
            createdAt: now,
          ),
        ],
      );

      final map = emergency.toMap();
      expect(map['urgency'], equals('CRITICAL'));
      expect(map['status'], equals('ACKNOWLEDGED'));
      expect(map['outcomeSummary'], equals('Shelter provided and relief distributed'));
      expect((map['responses'] as List).length, equals(1));

      final reconstructed = CrossIdirEmergency.fromMap(map);
      expect(reconstructed.urgency, equals(EmergencyUrgency.critical));
      expect(reconstructed.status, equals(EmergencyStatus.acknowledged));
      expect(reconstructed.responses.first.respondedByName, equals('Secretary Almaz'));
    });

    test('JointFinancialCommitment model enforces confirmation separation', () {
      final now = DateTime(2026, 11, 4, 18, 0);
      final commitment = JointFinancialCommitment(
        id: 'comm-1',
        contributingIdirName: 'Bole Medhanealem Idir',
        amountCommitted: 25000.00,
        amountConfirmed: 0.00,
        currency: 'ETB',
        purpose: 'Emergency medical aid fund',
        status: CommitmentStatus.authorized,
        authorizedByName: 'Treasurer Solomon',
        authorizedAt: now,
        createdAt: now,
      );

      final map = commitment.toMap();
      expect(map['amountCommitted'], equals(25000.00));
      expect(map['amountConfirmed'], equals(0.00));
      expect(map['status'], equals('AUTHORIZED'));

      final reconstructed = JointFinancialCommitment.fromMap(map);
      expect(reconstructed.amountCommitted, equals(25000.00));
      expect(reconstructed.amountConfirmed, equals(0.00));
      expect(reconstructed.status, equals(CommitmentStatus.authorized));
      expect(reconstructed.authorizedByName, equals('Treasurer Solomon'));
    });

    test('Enum extension string parsers handle unknown and case-insensitive values gracefully', () {
      expect(CooperationStatusX.fromString('active'), equals(CooperationStatus.active));
      expect(CooperationStatusX.fromString('completed'), equals(CooperationStatus.completed));
      expect(CooperationStatusX.fromString('UNKNOWN_VAL'), equals(CooperationStatus.pending));

      expect(InitiativeCategoryX.fromString('EMERGENCY_ASSISTANCE'), equals(InitiativeCategory.emergencyAssistance));
      expect(InitiativeCategoryX.fromString('COMMUNITY_SUPPORT'), equals(InitiativeCategory.communitySupport));
      expect(InitiativeCategoryX.fromString('UNKNOWN'), equals(InitiativeCategory.other));

      expect(EmergencyUrgencyX.fromString('CRITICAL'), equals(EmergencyUrgency.critical));
      expect(EmergencyUrgencyX.fromString('low'), equals(EmergencyUrgency.low));

      expect(CommitmentStatusX.fromString('CONFIRMED'), equals(CommitmentStatus.confirmed));
      expect(CommitmentStatusX.fromString('pending'), equals(CommitmentStatus.pending));
    });
  });
}
