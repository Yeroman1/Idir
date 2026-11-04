import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/cooperation_models.dart';
import 'cooperation_repository.dart';

class RestCooperationRepository implements CooperationRepository {
  RestCooperationRepository(this._api);

  final ApiClient _api;

  String _base(String idirId) => '/api/v1/idirs/$idirId/cooperation';

  List<T> _parseList<T>(dynamic res, T Function(Map<String, dynamic>) fromMap) {
    if (res is List) return res.map((e) => fromMap(e as Map<String, dynamic>)).toList();
    if (res is Map<String, dynamic>) {
      final items = res['items'] ?? res['data'] ?? res['agreements'] ??
          res['initiatives'] ?? res['announcements'] ?? res['emergencies'] ?? res['commitments'];
      if (items is List) return items.map((e) => fromMap(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<List<CooperationAgreement>> listCooperations(String idirId) async {
    final res = await _api.get('${_base(idirId)}/');
    return _parseList(res, CooperationAgreement.fromMap);
  }

  @override
  Future<CooperationAgreement> getCooperation(String idirId, String agreementId) async {
    final res = await _api.get('${_base(idirId)}/$agreementId');
    return CooperationAgreement.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<CooperationAgreement> proposeCooperation(
    String idirId, {
    required String targetIdirId,
    required String purpose,
    required String description,
    int? proposedDuration,
  }) async {
    final body = <String, dynamic>{
      'targetIdirId': targetIdirId,
      'purpose': purpose,
      'description': description,
      if (proposedDuration != null) 'proposedDuration': proposedDuration,
    };
    final res = await _api.post('${_base(idirId)}/', body: body);
    return CooperationAgreement.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<void> respondToCooperation(
    String idirId,
    String agreementId, {
    required String action,
    String? rejectionReason,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
    await _api.post('${_base(idirId)}/$agreementId/respond', body: body);
  }

  @override
  Future<void> endCooperation(String idirId, String agreementId, String reason) async {
    await _api.post('${_base(idirId)}/$agreementId/end', body: {'reason': reason});
  }

  @override
  Future<List<JointInitiative>> listInitiatives(String idirId, String agreementId) async {
    final res = await _api.get('${_base(idirId)}/$agreementId/initiatives');
    return _parseList(res, JointInitiative.fromMap);
  }

  @override
  Future<JointInitiative> getInitiative(String idirId, String agreementId, String initiativeId) async {
    final res = await _api.get('${_base(idirId)}/$agreementId/initiatives/$initiativeId');
    return JointInitiative.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<JointInitiative> createInitiative(
    String idirId,
    String agreementId, {
    required String title,
    required String description,
    required String objectives,
    required String category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'objectives': objectives,
      'category': category,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };
    final res = await _api.post('${_base(idirId)}/$agreementId/initiatives', body: body);
    return JointInitiative.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<JointInitiative> updateInitiative(
    String idirId,
    String agreementId,
    String initiativeId,
    Map<String, dynamic> fields,
  ) async {
    final res = await _api.patch('${_base(idirId)}/$agreementId/initiatives/$initiativeId', body: fields);
    return JointInitiative.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<void> addInitiativeUpdate(
    String idirId,
    String agreementId,
    String initiativeId, {
    required String content,
  }) async {
    await _api.post('${_base(idirId)}/$agreementId/initiatives/$initiativeId/updates', body: {'content': content});
  }

  @override
  Future<void> addInitiativeTask(
    String idirId,
    String agreementId,
    String initiativeId, {
    required String title,
    String? description,
    required String responsibleIdirId,
    DateTime? dueDate,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      'responsibleIdirId': responsibleIdirId,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
    };
    await _api.post('${_base(idirId)}/$agreementId/initiatives/$initiativeId/tasks', body: body);
  }

  @override
  Future<List<CrossIdirAnnouncement>> listAnnouncements(String idirId, String agreementId) async {
    final res = await _api.get('${_base(idirId)}/$agreementId/announcements');
    return _parseList(res, CrossIdirAnnouncement.fromMap);
  }

  @override
  Future<CrossIdirAnnouncement> createAnnouncement(
    String idirId,
    String agreementId, {
    required String title,
    required String body,
    required String category,
  }) async {
    final res = await _api.post('${_base(idirId)}/$agreementId/announcements', body: {
      'title': title,
      'body': body,
      'category': category,
    });
    return CrossIdirAnnouncement.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<void> updateAnnouncement(String idirId, String agreementId, String announcementId, Map<String, dynamic> fields) async {
    await _api.patch('${_base(idirId)}/$agreementId/announcements/$announcementId', body: fields);
  }

  @override
  Future<void> withdrawAnnouncement(String idirId, String agreementId, String announcementId) async {
    await _api.post('${_base(idirId)}/$agreementId/announcements/$announcementId/withdraw');
  }

  @override
  Future<List<CrossIdirEmergency>> listEmergencies(String idirId, String agreementId) async {
    final res = await _api.get('${_base(idirId)}/$agreementId/emergencies');
    return _parseList(res, CrossIdirEmergency.fromMap);
  }

  @override
  Future<CrossIdirEmergency> createEmergency(
    String idirId,
    String agreementId, {
    required String title,
    required String description,
    required String emergencyType,
    required String urgency,
  }) async {
    final res = await _api.post('${_base(idirId)}/$agreementId/emergencies', body: {
      'title': title,
      'description': description,
      'emergencyType': emergencyType,
      'urgency': urgency,
    });
    return CrossIdirEmergency.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<void> respondToEmergency(
    String idirId,
    String agreementId,
    String emergencyId, {
    required String message,
    String? commitmentNote,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      if (commitmentNote != null) 'commitmentNote': commitmentNote,
    };
    await _api.post('${_base(idirId)}/$agreementId/emergencies/$emergencyId/respond', body: body);
  }

  @override
  Future<void> closeEmergency(String idirId, String agreementId, String emergencyId, String outcomeSummary) async {
    await _api.post('${_base(idirId)}/$agreementId/emergencies/$emergencyId/close', body: {'outcomeSummary': outcomeSummary});
  }

  @override
  Future<List<JointFinancialCommitment>> listCommitments(String idirId, String agreementId) async {
    final res = await _api.get('${_base(idirId)}/$agreementId/commitments');
    return _parseList(res, JointFinancialCommitment.fromMap);
  }

  @override
  Future<JointFinancialCommitment> createCommitment(
    String idirId,
    String agreementId, {
    required double amountCommitted,
    required String purpose,
    String? initiativeId,
  }) async {
    final body = <String, dynamic>{
      'amountCommitted': amountCommitted,
      'purpose': purpose,
      if (initiativeId != null) 'initiativeId': initiativeId,
    };
    final res = await _api.post('${_base(idirId)}/$agreementId/commitments', body: body);
    return JointFinancialCommitment.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<void> authorizeCommitment(String idirId, String agreementId, String commitmentId) async {
    await _api.post('${_base(idirId)}/$agreementId/commitments/$commitmentId/authorize');
  }

  @override
  Future<void> confirmCommitment(
    String idirId,
    String agreementId,
    String commitmentId, {
    required double amountConfirmed,
    String? reconciliationNote,
  }) async {
    final body = <String, dynamic>{
      'amountConfirmed': amountConfirmed,
      if (reconciliationNote != null) 'reconciliationNote': reconciliationNote,
    };
    await _api.post('${_base(idirId)}/$agreementId/commitments/$commitmentId/confirm', body: body);
  }
}

final cooperationRepositoryProvider = Provider<CooperationRepository>((ref) {
  return RestCooperationRepository(ref.watch(apiClientProvider));
});
