import 'package:equatable/equatable.dart';

class NoConfidenceVoteModel extends Equatable {
  const NoConfidenceVoteModel({
    required this.id,
    required this.idirId,
    required this.targetMembershipId,
    this.targetName,
    this.targetPhone,
    required this.targetRole,
    this.initiatedByName,
    required this.reason,
    required this.thresholdPercentage,
    required this.quorumPercentage,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalEligibleMembers,
    required this.totalVotesCast,
    required this.supportVotes,
    required this.opposeVotes,
    this.resolvedAt,
    this.hasVoted = false,
  });

  factory NoConfidenceVoteModel.fromMap(Map<String, dynamic> map) {
    String? targetName;
    String? targetPhone;
    final targetMbr = map['targetMembership'];
    if (targetMbr is Map<String, dynamic>) {
      final user = targetMbr['user'];
      if (user is Map<String, dynamic>) {
        targetName = user['fullName'] as String?;
        targetPhone = user['phoneNumber'] as String?;
      }
    }

    String? initiatedByName;
    final initMbr = map['initiatedByMembership'];
    if (initMbr is Map<String, dynamic>) {
      final user = initMbr['user'];
      if (user is Map<String, dynamic>) {
        initiatedByName = user['fullName'] as String?;
      }
    }

    return NoConfidenceVoteModel(
      id: map['id'] as String? ?? '',
      idirId: map['idirId'] as String? ?? '',
      targetMembershipId: map['targetMembershipId'] as String? ?? '',
      targetName: targetName ?? (map['targetName'] as String?),
      targetPhone: targetPhone ?? (map['targetPhone'] as String?),
      targetRole: map['targetRole'] as String? ?? 'OFFICER',
      initiatedByName: initiatedByName ?? (map['initiatedByName'] as String?),
      reason: map['reason'] as String? ?? '',
      thresholdPercentage: (map['thresholdPercentage'] as num?)?.toDouble() ?? 66.67,
      quorumPercentage: (map['quorumPercentage'] as num?)?.toDouble() ?? 50.0,
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status'] as String? ?? 'ACTIVE',
      totalEligibleMembers: (map['totalEligibleMembers'] as num?)?.toInt() ?? 0,
      totalVotesCast: (map['totalVotesCast'] as num?)?.toInt() ?? 0,
      supportVotes: (map['supportVotes'] as num?)?.toInt() ?? 0,
      opposeVotes: (map['opposeVotes'] as num?)?.toInt() ?? 0,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())
          : null,
      hasVoted: map['hasVoted'] as bool? ?? false,
    );
  }

  final String id;
  final String idirId;
  final String targetMembershipId;
  final String? targetName;
  final String? targetPhone;
  final String targetRole;
  final String? initiatedByName;
  final String reason;
  final double thresholdPercentage;
  final double quorumPercentage;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final int totalEligibleMembers;
  final int totalVotesCast;
  final int supportVotes;
  final int opposeVotes;
  final DateTime? resolvedAt;
  final bool hasVoted;

  bool get isActive => status == 'ACTIVE';
  bool get isPassed => status == 'PASSED';
  bool get isFailed => status == 'FAILED' || status == 'FAILED_NO_QUORUM';

  double get turnoutPercentage =>
      totalEligibleMembers > 0 ? (totalVotesCast / totalEligibleMembers) * 100 : 0.0;

  double get supportPercentage =>
      totalVotesCast > 0 ? (supportVotes / totalVotesCast) * 100 : 0.0;

  bool get quorumReached => turnoutPercentage >= quorumPercentage;

  bool get thresholdReached => supportPercentage >= thresholdPercentage;

  NoConfidenceVoteModel copyWith({
    String? id,
    String? idirId,
    String? targetMembershipId,
    String? targetName,
    String? targetPhone,
    String? targetRole,
    String? initiatedByName,
    String? reason,
    double? thresholdPercentage,
    double? quorumPercentage,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int? totalEligibleMembers,
    int? totalVotesCast,
    int? supportVotes,
    int? opposeVotes,
    DateTime? resolvedAt,
    bool? hasVoted,
  }) {
    return NoConfidenceVoteModel(
      id: id ?? this.id,
      idirId: idirId ?? this.idirId,
      targetMembershipId: targetMembershipId ?? this.targetMembershipId,
      targetName: targetName ?? this.targetName,
      targetPhone: targetPhone ?? this.targetPhone,
      targetRole: targetRole ?? this.targetRole,
      initiatedByName: initiatedByName ?? this.initiatedByName,
      reason: reason ?? this.reason,
      thresholdPercentage: thresholdPercentage ?? this.thresholdPercentage,
      quorumPercentage: quorumPercentage ?? this.quorumPercentage,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      totalEligibleMembers: totalEligibleMembers ?? this.totalEligibleMembers,
      totalVotesCast: totalVotesCast ?? this.totalVotesCast,
      supportVotes: supportVotes ?? this.supportVotes,
      opposeVotes: opposeVotes ?? this.opposeVotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      hasVoted: hasVoted ?? this.hasVoted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'idirId': idirId,
        'targetMembershipId': targetMembershipId,
        if (targetName != null) 'targetName': targetName,
        if (targetPhone != null) 'targetPhone': targetPhone,
        'targetRole': targetRole,
        if (initiatedByName != null) 'initiatedByName': initiatedByName,
        'reason': reason,
        'thresholdPercentage': thresholdPercentage,
        'quorumPercentage': quorumPercentage,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'status': status,
        'totalEligibleMembers': totalEligibleMembers,
        'totalVotesCast': totalVotesCast,
        'supportVotes': supportVotes,
        'opposeVotes': opposeVotes,
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
        'hasVoted': hasVoted,
      };

  @override
  List<Object?> get props => [
        id,
        idirId,
        targetMembershipId,
        targetName,
        targetPhone,
        targetRole,
        initiatedByName,
        reason,
        thresholdPercentage,
        quorumPercentage,
        startDate,
        endDate,
        status,
        totalEligibleMembers,
        totalVotesCast,
        supportVotes,
        opposeVotes,
        resolvedAt,
        hasVoted,
      ];
}

class LeadershipVacancyModel extends Equatable {
  const LeadershipVacancyModel({
    required this.role,
    required this.status,
    this.holderMembershipId,
    this.holderName,
    this.holderPhone,
    this.holderMemberNumber,
    this.termStatus,
    this.termEndDate,
    this.activeNoConfidenceVoteId,
  });

  factory LeadershipVacancyModel.fromMap(Map<String, dynamic> map) {
    String? holderMembershipId;
    String? holderName;
    String? holderPhone;
    String? holderMemberNumber;

    final currentHolder = map['currentHolder'];
    if (currentHolder is Map<String, dynamic>) {
      holderMembershipId = currentHolder['membershipId'] as String?;
      holderName = currentHolder['fullName'] as String?;
      holderPhone = currentHolder['phoneNumber'] as String?;
      holderMemberNumber = currentHolder['memberNumber'] as String?;
    }

    String? termStatus;
    DateTime? termEndDate;
    final term = map['term'];
    if (term is Map<String, dynamic>) {
      termStatus = term['status'] as String?;
      if (term['endDate'] != null) {
        termEndDate = DateTime.tryParse(term['endDate'].toString());
      }
    }

    return LeadershipVacancyModel(
      role: map['role'] as String? ?? '',
      status: map['status'] as String? ?? 'VACANT',
      holderMembershipId: holderMembershipId,
      holderName: holderName,
      holderPhone: holderPhone,
      holderMemberNumber: holderMemberNumber,
      termStatus: termStatus,
      termEndDate: termEndDate,
      activeNoConfidenceVoteId: map['activeNoConfidenceVoteId'] as String?,
    );
  }

  final String role;
  final String status; // 'OCCUPIED' | 'VACANT' | 'INTERIM'
  final String? holderMembershipId;
  final String? holderName;
  final String? holderPhone;
  final String? holderMemberNumber;
  final String? termStatus;
  final DateTime? termEndDate;
  final String? activeNoConfidenceVoteId;

  bool get isVacant => status == 'VACANT';
  bool get isInterim => status == 'INTERIM';
  bool get isOccupied => status == 'OCCUPIED';

  Map<String, dynamic> toMap() => {
        'role': role,
        'status': status,
        if (holderMembershipId != null) 'holderMembershipId': holderMembershipId,
        if (holderName != null) 'holderName': holderName,
        if (holderPhone != null) 'holderPhone': holderPhone,
        if (holderMemberNumber != null) 'holderMemberNumber': holderMemberNumber,
        if (termStatus != null) 'termStatus': termStatus,
        if (termEndDate != null) 'termEndDate': termEndDate!.toIso8601String(),
        if (activeNoConfidenceVoteId != null)
          'activeNoConfidenceVoteId': activeNoConfidenceVoteId,
      };

  @override
  List<Object?> get props => [
        role,
        status,
        holderMembershipId,
        holderName,
        holderPhone,
        holderMemberNumber,
        termStatus,
        termEndDate,
        activeNoConfidenceVoteId,
      ];
}
