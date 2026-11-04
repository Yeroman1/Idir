import '../domain/models/cooperation_models.dart';

abstract class CooperationRepository {
  // Cooperation Agreements
  Future<List<CooperationAgreement>> listCooperations(String idirId);
  Future<CooperationAgreement> getCooperation(String idirId, String agreementId);
  Future<CooperationAgreement> proposeCooperation(
    String idirId, {
    required String targetIdirId,
    required String purpose,
    required String description,
    int? proposedDuration,
  });
  Future<void> respondToCooperation(
    String idirId,
    String agreementId, {
    required String action,
    String? rejectionReason,
  });
  Future<void> endCooperation(String idirId, String agreementId, String reason);

  // Initiatives
  Future<List<JointInitiative>> listInitiatives(String idirId, String agreementId);
  Future<JointInitiative> getInitiative(String idirId, String agreementId, String initiativeId);
  Future<JointInitiative> createInitiative(
    String idirId,
    String agreementId, {
    required String title,
    required String description,
    required String objectives,
    required String category,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<JointInitiative> updateInitiative(
    String idirId,
    String agreementId,
    String initiativeId,
    Map<String, dynamic> fields,
  );
  Future<void> addInitiativeUpdate(
    String idirId,
    String agreementId,
    String initiativeId, {
    required String content,
  });
  Future<void> addInitiativeTask(
    String idirId,
    String agreementId,
    String initiativeId, {
    required String title,
    String? description,
    required String responsibleIdirId,
    DateTime? dueDate,
  });

  // Announcements
  Future<List<CrossIdirAnnouncement>> listAnnouncements(String idirId, String agreementId);
  Future<CrossIdirAnnouncement> createAnnouncement(
    String idirId,
    String agreementId, {
    required String title,
    required String body,
    required String category,
  });
  Future<void> updateAnnouncement(String idirId, String agreementId, String announcementId, Map<String, dynamic> fields);
  Future<void> withdrawAnnouncement(String idirId, String agreementId, String announcementId);

  // Emergencies
  Future<List<CrossIdirEmergency>> listEmergencies(String idirId, String agreementId);
  Future<CrossIdirEmergency> createEmergency(
    String idirId,
    String agreementId, {
    required String title,
    required String description,
    required String emergencyType,
    required String urgency,
  });
  Future<void> respondToEmergency(
    String idirId,
    String agreementId,
    String emergencyId, {
    required String message,
    String? commitmentNote,
  });
  Future<void> closeEmergency(String idirId, String agreementId, String emergencyId, String outcomeSummary);

  // Financial Commitments
  Future<List<JointFinancialCommitment>> listCommitments(String idirId, String agreementId);
  Future<JointFinancialCommitment> createCommitment(
    String idirId,
    String agreementId, {
    required double amountCommitted,
    required String purpose,
    String? initiativeId,
  });
  Future<void> authorizeCommitment(String idirId, String agreementId, String commitmentId);
  Future<void> confirmCommitment(
    String idirId,
    String agreementId,
    String commitmentId, {
    required double amountConfirmed,
    String? reconciliationNote,
  });
}
