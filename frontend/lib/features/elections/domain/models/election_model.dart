import 'package:equatable/equatable.dart';

class ElectionCommitteeMemberModel extends Equatable {
  const ElectionCommitteeMemberModel({
    required this.id,
    required this.membershipId,
    this.memberNumber,
    this.fullName,
    this.phoneNumber,
    this.role = 'COMMITTEE_MEMBER',
    this.assignedAt,
  });

  factory ElectionCommitteeMemberModel.fromMap(Map<String, dynamic> map) {
    final membership = map['membership'] as Map<String, dynamic>?;
    final user = membership?['user'] as Map<String, dynamic>?;

    return ElectionCommitteeMemberModel(
      id: map['id'] as String? ?? '',
      membershipId: map['membershipId'] as String? ??
          (membership?['id'] as String? ?? ''),
      memberNumber: membership?['memberNumber'] as String? ??
          map['memberNumber'] as String?,
      fullName: user?['fullName'] as String? ??
          map['fullName'] as String?,
      phoneNumber: user?['phoneNumber'] as String? ??
          map['phoneNumber'] as String?,
      role: map['role'] as String? ?? 'COMMITTEE_MEMBER',
      assignedAt: map['assignedAt'] != null
          ? DateTime.tryParse(map['assignedAt'].toString())
          : null,
    );
  }

  final String id;
  final String membershipId;
  final String? memberNumber;
  final String? fullName;
  final String? phoneNumber;
  final String role;
  final DateTime? assignedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'membershipId': membershipId,
        if (memberNumber != null) 'memberNumber': memberNumber,
        if (fullName != null) 'fullName': fullName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'role': role,
        if (assignedAt != null) 'assignedAt': assignedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        membershipId,
        memberNumber,
        fullName,
        phoneNumber,
        role,
        assignedAt,
      ];
}

class ElectionModel extends Equatable {
  const ElectionModel({
    required this.id,
    required this.idirId,
    required this.title,
    this.description,
    required this.roles,
    required this.startDate,
    required this.endDate,
    this.nominationStartDate,
    this.nominationEndDate,
    required this.termLengthMonths,
    required this.votingMethod,
    required this.ballotType,
    required this.quorumPercentage,
    this.minMembershipTenureDays = 0,
    this.requiresGoodStanding = true,
    required this.status,
    this.disputeWindowHours = 48,
    this.handoverDate,
    this.committeeMembers = const [],
    this.createdById,
    this.createdAt,
    this.updatedAt,
  });

  factory ElectionModel.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];
    final List<String> parsedRoles = rawRoles is List
        ? rawRoles.map((e) => e.toString()).toList()
        : <String>[];

    final rawCommittee = map['committeeMembers'];
    final List<ElectionCommitteeMemberModel> parsedCommittee = rawCommittee is List
        ? rawCommittee
            .whereType<Map<String, dynamic>>()
            .map((e) => ElectionCommitteeMemberModel.fromMap(e))
            .toList()
        : <ElectionCommitteeMemberModel>[];

    return ElectionModel(
      id: map['id'] as String? ?? '',
      idirId: map['idirId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      roles: parsedRoles,
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 3)),
      nominationStartDate: map['nominationStartDate'] != null
          ? DateTime.tryParse(map['nominationStartDate'].toString())
          : null,
      nominationEndDate: map['nominationEndDate'] != null
          ? DateTime.tryParse(map['nominationEndDate'].toString())
          : null,
      termLengthMonths: (map['termLengthMonths'] as num?)?.toInt() ?? 12,
      votingMethod: map['votingMethod'] as String? ?? 'SIMPLE_MAJORITY',
      ballotType: map['ballotType'] as String? ?? 'SECRET',
      quorumPercentage: (map['quorumPercentage'] as num?)?.toDouble() ?? 50.0,
      minMembershipTenureDays:
          (map['minMembershipTenureDays'] as num?)?.toInt() ?? 0,
      requiresGoodStanding:
          map['requiresGoodStanding'] as bool? ?? true,
      status: map['status'] as String? ?? 'DRAFT',
      disputeWindowHours:
          (map['disputeWindowHours'] as num?)?.toInt() ?? 48,
      handoverDate: map['handoverDate'] != null
          ? DateTime.tryParse(map['handoverDate'].toString())
          : null,
      committeeMembers: parsedCommittee,
      createdById: map['createdById'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  final String id;
  final String idirId;
  final String title;
  final String? description;
  final List<String> roles;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? nominationStartDate;
  final DateTime? nominationEndDate;
  final int termLengthMonths;
  final String votingMethod; // 'SIMPLE_MAJORITY' or 'RUNOFF'
  final String ballotType; // 'SECRET' or 'OPEN'
  final double quorumPercentage;
  final int minMembershipTenureDays;
  final bool requiresGoodStanding;
  final String status;
  final int disputeWindowHours;
  final DateTime? handoverDate;
  final List<ElectionCommitteeMemberModel> committeeMembers;
  final String? createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isNominating => status.toUpperCase() == 'NOMINATING';
  bool get isVoting => status.toUpperCase() == 'VOTING';
  bool get isTallying => status.toUpperCase() == 'TALLYING';
  bool get isDisputed => status.toUpperCase() == 'DISPUTED';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get isSecretBallot => ballotType.toUpperCase() == 'SECRET';
  bool get isRunoff => votingMethod.toUpperCase() == 'RUNOFF';

  Map<String, dynamic> toMap() => {
        'id': id,
        'idirId': idirId,
        'title': title,
        if (description != null) 'description': description,
        'roles': roles,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (nominationStartDate != null)
          'nominationStartDate': nominationStartDate!.toIso8601String(),
        if (nominationEndDate != null)
          'nominationEndDate': nominationEndDate!.toIso8601String(),
        'termLengthMonths': termLengthMonths,
        'votingMethod': votingMethod,
        'ballotType': ballotType,
        'quorumPercentage': quorumPercentage,
        'minMembershipTenureDays': minMembershipTenureDays,
        'requiresGoodStanding': requiresGoodStanding,
        'status': status,
        'disputeWindowHours': disputeWindowHours,
        if (handoverDate != null)
          'handoverDate': handoverDate!.toIso8601String(),
        'committeeMembers':
            committeeMembers.map((m) => m.toMap()).toList(),
        if (createdById != null) 'createdById': createdById,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  ElectionModel copyWith({
    String? id,
    String? idirId,
    String? title,
    String? description,
    List<String>? roles,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nominationStartDate,
    DateTime? nominationEndDate,
    int? termLengthMonths,
    String? votingMethod,
    String? ballotType,
    double? quorumPercentage,
    int? minMembershipTenureDays,
    bool? requiresGoodStanding,
    String? status,
    int? disputeWindowHours,
    DateTime? handoverDate,
    List<ElectionCommitteeMemberModel>? committeeMembers,
    String? createdById,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ElectionModel(
      id: id ?? this.id,
      idirId: idirId ?? this.idirId,
      title: title ?? this.title,
      description: description ?? this.description,
      roles: roles ?? this.roles,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nominationStartDate: nominationStartDate ?? this.nominationStartDate,
      nominationEndDate: nominationEndDate ?? this.nominationEndDate,
      termLengthMonths: termLengthMonths ?? this.termLengthMonths,
      votingMethod: votingMethod ?? this.votingMethod,
      ballotType: ballotType ?? this.ballotType,
      quorumPercentage: quorumPercentage ?? this.quorumPercentage,
      minMembershipTenureDays:
          minMembershipTenureDays ?? this.minMembershipTenureDays,
      requiresGoodStanding:
          requiresGoodStanding ?? this.requiresGoodStanding,
      status: status ?? this.status,
      disputeWindowHours: disputeWindowHours ?? this.disputeWindowHours,
      handoverDate: handoverDate ?? this.handoverDate,
      committeeMembers: committeeMembers ?? this.committeeMembers,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        idirId,
        title,
        description,
        roles,
        startDate,
        endDate,
        nominationStartDate,
        nominationEndDate,
        termLengthMonths,
        votingMethod,
        ballotType,
        quorumPercentage,
        minMembershipTenureDays,
        requiresGoodStanding,
        status,
        disputeWindowHours,
        handoverDate,
        committeeMembers,
        createdById,
        createdAt,
        updatedAt,
      ];
}
