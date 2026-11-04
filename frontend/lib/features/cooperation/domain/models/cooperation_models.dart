import 'package:equatable/equatable.dart';

// ── Status Enums ──────────────────────────────────────────────────────────────

enum CooperationStatus { pending, active, completed, cancelled, rejected }

extension CooperationStatusX on CooperationStatus {
  String get label => switch (this) {
        CooperationStatus.pending => 'Pending',
        CooperationStatus.active => 'Active',
        CooperationStatus.completed => 'Completed',
        CooperationStatus.cancelled => 'Cancelled',
        CooperationStatus.rejected => 'Rejected',
      };

  static CooperationStatus fromString(String s) => switch (s.toUpperCase()) {
        'ACTIVE' => CooperationStatus.active,
        'COMPLETED' => CooperationStatus.completed,
        'CANCELLED' => CooperationStatus.cancelled,
        'REJECTED' => CooperationStatus.rejected,
        _ => CooperationStatus.pending,
      };
}

enum InitiativeStatus { draft, active, completed, cancelled }

extension InitiativeStatusX on InitiativeStatus {
  String get label => switch (this) {
        InitiativeStatus.draft => 'Draft',
        InitiativeStatus.active => 'Active',
        InitiativeStatus.completed => 'Completed',
        InitiativeStatus.cancelled => 'Cancelled',
      };

  static InitiativeStatus fromString(String s) => switch (s.toUpperCase()) {
        'ACTIVE' => InitiativeStatus.active,
        'COMPLETED' => InitiativeStatus.completed,
        'CANCELLED' => InitiativeStatus.cancelled,
        _ => InitiativeStatus.draft,
      };
}

enum InitiativeCategory {
  emergencyAssistance,
  communitySupport,
  jointMeeting,
  other,
}

extension InitiativeCategoryX on InitiativeCategory {
  String get label => switch (this) {
        InitiativeCategory.emergencyAssistance => 'Emergency Assistance',
        InitiativeCategory.communitySupport => 'Community Support',
        InitiativeCategory.jointMeeting => 'Joint Meeting',
        InitiativeCategory.other => 'Other',
      };

  String get value => switch (this) {
        InitiativeCategory.emergencyAssistance => 'EMERGENCY_ASSISTANCE',
        InitiativeCategory.communitySupport => 'COMMUNITY_SUPPORT',
        InitiativeCategory.jointMeeting => 'JOINT_MEETING',
        InitiativeCategory.other => 'OTHER',
      };

  static InitiativeCategory fromString(String s) => switch (s.toUpperCase()) {
        'EMERGENCY_ASSISTANCE' => InitiativeCategory.emergencyAssistance,
        'COMMUNITY_SUPPORT' => InitiativeCategory.communitySupport,
        'JOINT_MEETING' => InitiativeCategory.jointMeeting,
        _ => InitiativeCategory.other,
      };
}

enum AnnouncementCrossCategory {
  emergency,
  jointMeeting,
  communityInitiative,
  general,
}

extension AnnouncementCrossCategoryX on AnnouncementCrossCategory {
  String get label => switch (this) {
        AnnouncementCrossCategory.emergency => 'Emergency',
        AnnouncementCrossCategory.jointMeeting => 'Joint Meeting',
        AnnouncementCrossCategory.communityInitiative => 'Community Initiative',
        AnnouncementCrossCategory.general => 'General',
      };

  String get value => switch (this) {
        AnnouncementCrossCategory.emergency => 'EMERGENCY',
        AnnouncementCrossCategory.jointMeeting => 'JOINT_MEETING',
        AnnouncementCrossCategory.communityInitiative => 'COMMUNITY_INITIATIVE',
        AnnouncementCrossCategory.general => 'GENERAL',
      };

  static AnnouncementCrossCategory fromString(String s) => switch (s.toUpperCase()) {
        'EMERGENCY' => AnnouncementCrossCategory.emergency,
        'JOINT_MEETING' => AnnouncementCrossCategory.jointMeeting,
        'COMMUNITY_INITIATIVE' => AnnouncementCrossCategory.communityInitiative,
        _ => AnnouncementCrossCategory.general,
      };
}

enum EmergencyUrgency { low, medium, high, critical }

extension EmergencyUrgencyX on EmergencyUrgency {
  String get label => switch (this) {
        EmergencyUrgency.low => 'Low',
        EmergencyUrgency.medium => 'Medium',
        EmergencyUrgency.high => 'High',
        EmergencyUrgency.critical => 'Critical',
      };

  String get value => switch (this) {
        EmergencyUrgency.low => 'LOW',
        EmergencyUrgency.medium => 'MEDIUM',
        EmergencyUrgency.high => 'HIGH',
        EmergencyUrgency.critical => 'CRITICAL',
      };

  static EmergencyUrgency fromString(String s) => switch (s.toUpperCase()) {
        'CRITICAL' => EmergencyUrgency.critical,
        'HIGH' => EmergencyUrgency.high,
        'MEDIUM' => EmergencyUrgency.medium,
        _ => EmergencyUrgency.low,
      };
}

enum EmergencyStatus { open, acknowledged, inProgress, resolved, closed }

extension EmergencyStatusX on EmergencyStatus {
  String get label => switch (this) {
        EmergencyStatus.open => 'Open',
        EmergencyStatus.acknowledged => 'Acknowledged',
        EmergencyStatus.inProgress => 'In Progress',
        EmergencyStatus.resolved => 'Resolved',
        EmergencyStatus.closed => 'Closed',
      };

  static EmergencyStatus fromString(String s) => switch (s.toUpperCase()) {
        'ACKNOWLEDGED' => EmergencyStatus.acknowledged,
        'IN_PROGRESS' => EmergencyStatus.inProgress,
        'RESOLVED' => EmergencyStatus.resolved,
        'CLOSED' => EmergencyStatus.closed,
        _ => EmergencyStatus.open,
      };
}

enum CommitmentStatus { pending, authorized, confirmed, cancelled }

extension CommitmentStatusX on CommitmentStatus {
  String get label => switch (this) {
        CommitmentStatus.pending => 'Pending',
        CommitmentStatus.authorized => 'Authorized',
        CommitmentStatus.confirmed => 'Confirmed',
        CommitmentStatus.cancelled => 'Cancelled',
      };

  static CommitmentStatus fromString(String s) => switch (s.toUpperCase()) {
        'AUTHORIZED' => CommitmentStatus.authorized,
        'CONFIRMED' => CommitmentStatus.confirmed,
        'CANCELLED' => CommitmentStatus.cancelled,
        _ => CommitmentStatus.pending,
      };
}

// ── Model Classes ─────────────────────────────────────────────────────────────

class CooperationParticipant extends Equatable {
  const CooperationParticipant({
    required this.id,
    required this.agreementId,
    required this.idirId,
    required this.idirName,
    required this.status,
    this.authorizedByUserName,
    this.authorizedAt,
    this.rejectionReason,
  });

  final String id;
  final String agreementId;
  final String idirId;
  final String idirName;
  final CooperationStatus status;
  final String? authorizedByUserName;
  final DateTime? authorizedAt;
  final String? rejectionReason;

  factory CooperationParticipant.fromMap(Map<String, dynamic> map) {
    final idirMap = map['idir'] as Map<String, dynamic>?;
    return CooperationParticipant(
      id: map['id'] as String? ?? '',
      agreementId: map['agreementId'] as String? ?? '',
      idirId: map['idirId'] as String? ?? idirMap?['id'] as String? ?? '',
      idirName: map['idirName'] as String? ?? idirMap?['name'] as String? ?? '',
      status: CooperationStatusX.fromString(map['status'] as String? ?? ''),
      authorizedByUserName: map['authorizedByUserName'] as String?,
      authorizedAt: map['authorizedAt'] != null
          ? DateTime.tryParse(map['authorizedAt'].toString())
          : null,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'agreementId': agreementId,
        'idirId': idirId,
        'idirName': idirName,
        'status': status.name.toUpperCase(),
        if (authorizedByUserName != null) 'authorizedByUserName': authorizedByUserName,
        if (authorizedAt != null) 'authorizedAt': authorizedAt!.toIso8601String(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

  @override
  List<Object?> get props => [id, agreementId, idirId, idirName, status, authorizedByUserName, authorizedAt, rejectionReason];
}

class CooperationAgreement extends Equatable {
  const CooperationAgreement({
    required this.id,
    required this.idirAId,
    required this.idirBId,
    required this.idirAName,
    required this.idirBName,
    required this.purpose,
    required this.description,
    required this.status,
    required this.createdAt,
    this.proposedDuration,
    this.startDate,
    this.endDate,
    this.endReason,
    this.participants = const [],
  });

  final String id;
  final String idirAId;
  final String idirBId;
  final String idirAName;
  final String idirBName;
  final String purpose;
  final String description;
  final CooperationStatus status;
  final int? proposedDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? endReason;
  final List<CooperationParticipant> participants;
  final DateTime createdAt;

  factory CooperationAgreement.fromMap(Map<String, dynamic> map) {
    final participantsList = (map['participants'] as List<dynamic>?)
            ?.map((e) => CooperationParticipant.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return CooperationAgreement(
      id: map['id'] as String? ?? '',
      idirAId: map['idirAId'] as String? ?? '',
      idirBId: map['idirBId'] as String? ?? '',
      idirAName: map['idirAName'] as String? ?? (map['idirA'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      idirBName: map['idirBName'] as String? ?? (map['idirB'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      purpose: map['purpose'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: CooperationStatusX.fromString(map['status'] as String? ?? ''),
      proposedDuration: map['proposedDuration'] as int?,
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate'].toString()) : null,
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate'].toString()) : null,
      endReason: map['endReason'] as String?,
      participants: participantsList,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'idirAId': idirAId,
        'idirBId': idirBId,
        'idirAName': idirAName,
        'idirBName': idirBName,
        'purpose': purpose,
        'description': description,
        'status': status.name.toUpperCase(),
        if (proposedDuration != null) 'proposedDuration': proposedDuration,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (endReason != null) 'endReason': endReason,
        'participants': participants.map((p) => p.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, idirAId, idirBId, purpose, description, status, createdAt];
}

class InitiativeUpdate extends Equatable {
  const InitiativeUpdate({
    required this.id,
    required this.content,
    required this.postedByName,
    required this.createdAt,
  });

  final String id;
  final String content;
  final String postedByName;
  final DateTime createdAt;

  factory InitiativeUpdate.fromMap(Map<String, dynamic> map) => InitiativeUpdate(
        id: map['id'] as String? ?? '',
        content: map['content'] as String? ?? '',
        postedByName: map['postedByName'] as String? ?? map['createdByName'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'postedByName': postedByName,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, content, postedByName, createdAt];
}

class InitiativeTask extends Equatable {
  const InitiativeTask({
    required this.id,
    required this.title,
    required this.responsibleIdirId,
    required this.responsibleIdirName,
    required this.isCompleted,
    this.description,
    this.dueDate,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String responsibleIdirId;
  final String responsibleIdirName;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;

  factory InitiativeTask.fromMap(Map<String, dynamic> map) => InitiativeTask(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        responsibleIdirId: map['responsibleIdirId'] as String? ?? '',
        responsibleIdirName: map['responsibleIdirName'] as String? ?? '',
        dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'].toString()) : null,
        isCompleted: map['isCompleted'] as bool? ?? false,
        completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'responsibleIdirId': responsibleIdirId,
        'responsibleIdirName': responsibleIdirName,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, title, responsibleIdirId, isCompleted];
}

class JointInitiative extends Equatable {
  const JointInitiative({
    required this.id,
    required this.agreementId,
    required this.title,
    required this.description,
    required this.objectives,
    required this.category,
    required this.status,
    required this.ownerIdirId,
    required this.ownerIdirName,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.updates = const [],
    this.tasks = const [],
  });

  final String id;
  final String agreementId;
  final String title;
  final String description;
  final String objectives;
  final InitiativeCategory category;
  final InitiativeStatus status;
  final String ownerIdirId;
  final String ownerIdirName;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<InitiativeUpdate> updates;
  final List<InitiativeTask> tasks;
  final DateTime createdAt;

  factory JointInitiative.fromMap(Map<String, dynamic> map) {
    final updatesList = (map['updates'] as List<dynamic>?)
            ?.map((e) => InitiativeUpdate.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final tasksList = (map['tasks'] as List<dynamic>?)
            ?.map((e) => InitiativeTask.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return JointInitiative(
      id: map['id'] as String? ?? '',
      agreementId: map['agreementId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      objectives: map['objectives'] as String? ?? '',
      category: InitiativeCategoryX.fromString(map['category'] as String? ?? ''),
      status: InitiativeStatusX.fromString(map['status'] as String? ?? ''),
      ownerIdirId: map['ownerIdirId'] as String? ?? '',
      ownerIdirName: map['ownerIdirName'] as String? ?? '',
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate'].toString()) : null,
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate'].toString()) : null,
      updates: updatesList,
      tasks: tasksList,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'agreementId': agreementId,
        'title': title,
        'description': description,
        'objectives': objectives,
        'category': category.value,
        'status': status.name.toUpperCase(),
        'ownerIdirId': ownerIdirId,
        'ownerIdirName': ownerIdirName,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'updates': updates.map((u) => u.toMap()).toList(),
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, agreementId, title, status, category];
}

class CrossIdirAnnouncement extends Equatable {
  const CrossIdirAnnouncement({
    required this.id,
    required this.agreementId,
    required this.publisherIdirName,
    required this.title,
    required this.body,
    required this.category,
    required this.isWithdrawn,
    required this.createdByName,
    required this.createdAt,
  });

  final String id;
  final String agreementId;
  final String publisherIdirName;
  final String title;
  final String body;
  final AnnouncementCrossCategory category;
  final bool isWithdrawn;
  final String createdByName;
  final DateTime createdAt;

  factory CrossIdirAnnouncement.fromMap(Map<String, dynamic> map) => CrossIdirAnnouncement(
        id: map['id'] as String? ?? '',
        agreementId: map['agreementId'] as String? ?? '',
        publisherIdirName: map['publisherIdirName'] as String? ?? '',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? map['content'] as String? ?? '',
        category: AnnouncementCrossCategoryX.fromString(map['category'] as String? ?? ''),
        isWithdrawn: map['isWithdrawn'] as bool? ?? false,
        createdByName: map['createdByName'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'agreementId': agreementId,
        'publisherIdirName': publisherIdirName,
        'title': title,
        'body': body,
        'category': category.value,
        'isWithdrawn': isWithdrawn,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, agreementId, title, isWithdrawn, createdAt];
}

class EmergencyResponse extends Equatable {
  const EmergencyResponse({
    required this.id,
    required this.respondingIdirName,
    required this.message,
    required this.respondedByName,
    required this.createdAt,
    this.commitmentNote,
  });

  final String id;
  final String respondingIdirName;
  final String message;
  final String? commitmentNote;
  final String respondedByName;
  final DateTime createdAt;

  factory EmergencyResponse.fromMap(Map<String, dynamic> map) => EmergencyResponse(
        id: map['id'] as String? ?? '',
        respondingIdirName: map['respondingIdirName'] as String? ?? '',
        message: map['message'] as String? ?? '',
        commitmentNote: map['commitmentNote'] as String?,
        respondedByName: map['respondedByName'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'respondingIdirName': respondingIdirName,
        'message': message,
        if (commitmentNote != null) 'commitmentNote': commitmentNote,
        'respondedByName': respondedByName,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, respondingIdirName, message, createdAt];
}

class CrossIdirEmergency extends Equatable {
  const CrossIdirEmergency({
    required this.id,
    required this.agreementId,
    required this.requestingIdirName,
    required this.title,
    required this.description,
    required this.emergencyType,
    required this.urgency,
    required this.status,
    required this.createdAt,
    this.outcomeSummary,
    this.responses = const [],
  });

  final String id;
  final String agreementId;
  final String requestingIdirName;
  final String title;
  final String description;
  final String emergencyType;
  final EmergencyUrgency urgency;
  final EmergencyStatus status;
  final String? outcomeSummary;
  final DateTime createdAt;
  final List<EmergencyResponse> responses;

  factory CrossIdirEmergency.fromMap(Map<String, dynamic> map) {
    final responsesList = (map['responses'] as List<dynamic>?)
            ?.map((e) => EmergencyResponse.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return CrossIdirEmergency(
      id: map['id'] as String? ?? '',
      agreementId: map['agreementId'] as String? ?? '',
      requestingIdirName: map['requestingIdirName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      emergencyType: map['emergencyType'] as String? ?? '',
      urgency: EmergencyUrgencyX.fromString(map['urgency'] as String? ?? ''),
      status: EmergencyStatusX.fromString(map['status'] as String? ?? ''),
      outcomeSummary: map['outcomeSummary'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      responses: responsesList,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'agreementId': agreementId,
        'requestingIdirName': requestingIdirName,
        'title': title,
        'description': description,
        'emergencyType': emergencyType,
        'urgency': urgency.value,
        'status': status.name.toUpperCase(),
        if (outcomeSummary != null) 'outcomeSummary': outcomeSummary,
        'createdAt': createdAt.toIso8601String(),
        'responses': responses.map((r) => r.toMap()).toList(),
      };

  @override
  List<Object?> get props => [id, agreementId, title, urgency, status, createdAt];
}

class JointFinancialCommitment extends Equatable {
  const JointFinancialCommitment({
    required this.id,
    required this.contributingIdirName,
    required this.amountCommitted,
    required this.amountConfirmed,
    required this.currency,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.authorizedByName,
    this.authorizedAt,
  });

  final String id;
  final String contributingIdirName;
  final double amountCommitted;
  final double amountConfirmed;
  final String currency;
  final String purpose;
  final CommitmentStatus status;
  final String? authorizedByName;
  final DateTime? authorizedAt;
  final DateTime createdAt;

  factory JointFinancialCommitment.fromMap(Map<String, dynamic> map) => JointFinancialCommitment(
        id: map['id'] as String? ?? '',
        contributingIdirName: map['contributingIdirName'] as String? ?? '',
        amountCommitted: double.tryParse(map['amountCommitted']?.toString() ?? '0') ?? 0.0,
        amountConfirmed: double.tryParse(map['amountConfirmed']?.toString() ?? '0') ?? 0.0,
        currency: map['currency'] as String? ?? 'ETB',
        purpose: map['purpose'] as String? ?? '',
        status: CommitmentStatusX.fromString(map['status'] as String? ?? ''),
        authorizedByName: map['authorizedByName'] as String?,
        authorizedAt: map['authorizedAt'] != null ? DateTime.tryParse(map['authorizedAt'].toString()) : null,
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'contributingIdirName': contributingIdirName,
        'amountCommitted': amountCommitted,
        'amountConfirmed': amountConfirmed,
        'currency': currency,
        'purpose': purpose,
        'status': status.name.toUpperCase(),
        if (authorizedByName != null) 'authorizedByName': authorizedByName,
        if (authorizedAt != null) 'authorizedAt': authorizedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, contributingIdirName, amountCommitted, purpose, status, createdAt];
}
