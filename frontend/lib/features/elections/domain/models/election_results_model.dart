import 'package:equatable/equatable.dart';

class CandidateTallyModel extends Equatable {
  const CandidateTallyModel({
    required this.nominationId,
    required this.nomineeMembershipId,
    required this.nomineeName,
    this.statement,
    required this.votes,
    required this.percentage,
  });

  factory CandidateTallyModel.fromMap(Map<String, dynamic> map) {
    return CandidateTallyModel(
      nominationId: map['nominationId'] as String? ?? '',
      nomineeMembershipId: map['nomineeMembershipId'] as String? ?? '',
      nomineeName: map['nomineeName'] as String? ?? 'Candidate',
      statement: map['statement'] as String?,
      votes: (map['votes'] as num?)?.toInt() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String nominationId;
  final String nomineeMembershipId;
  final String nomineeName;
  final String? statement;
  final int votes;
  final double percentage;

  Map<String, dynamic> toMap() => {
        'nominationId': nominationId,
        'nomineeMembershipId': nomineeMembershipId,
        'nomineeName': nomineeName,
        if (statement != null) 'statement': statement,
        'votes': votes,
        'percentage': percentage,
      };

  @override
  List<Object?> get props => [
        nominationId,
        nomineeMembershipId,
        nomineeName,
        statement,
        votes,
        percentage,
      ];
}

class RoleResultModel extends Equatable {
  const RoleResultModel({
    required this.role,
    this.winnerNominationId,
    this.winnerName,
    this.winnerMembershipId,
    required this.totalVotesCast,
    required this.votesReceived,
    required this.isTie,
    this.tiedCandidateIds = const [],
    required this.candidates,
  });

  factory RoleResultModel.fromMap(Map<String, dynamic> map) {
    final rawCandidates = map['candidates'];
    final List<CandidateTallyModel> parsedCandidates = rawCandidates is List
        ? rawCandidates
            .whereType<Map<String, dynamic>>()
            .map((c) => CandidateTallyModel.fromMap(c))
            .toList()
        : <CandidateTallyModel>[];

    final rawTied = map['tiedCandidateIds'];
    final List<String> parsedTied = rawTied is List
        ? rawTied.map((e) => e.toString()).toList()
        : <String>[];

    return RoleResultModel(
      role: map['role'] as String? ?? '',
      winnerNominationId: map['winnerNominationId'] as String?,
      winnerName: map['winnerName'] as String?,
      winnerMembershipId: map['winnerMembershipId'] as String?,
      totalVotesCast: (map['totalVotesCast'] as num?)?.toInt() ?? 0,
      votesReceived: (map['votesReceived'] as num?)?.toInt() ?? 0,
      isTie: map['isTie'] as bool? ?? false,
      tiedCandidateIds: parsedTied,
      candidates: parsedCandidates,
    );
  }

  final String role;
  final String? winnerNominationId;
  final String? winnerName;
  final String? winnerMembershipId;
  final int totalVotesCast;
  final int votesReceived;
  final bool isTie;
  final List<String> tiedCandidateIds;
  final List<CandidateTallyModel> candidates;

  bool get hasWinner => winnerNominationId != null && !isTie;

  Map<String, dynamic> toMap() => {
        'role': role,
        if (winnerNominationId != null) 'winnerNominationId': winnerNominationId,
        if (winnerName != null) 'winnerName': winnerName,
        if (winnerMembershipId != null) 'winnerMembershipId': winnerMembershipId,
        'totalVotesCast': totalVotesCast,
        'votesReceived': votesReceived,
        'isTie': isTie,
        'tiedCandidateIds': tiedCandidateIds,
        'candidates': candidates.map((c) => c.toMap()).toList(),
      };

  @override
  List<Object?> get props => [
        role,
        winnerNominationId,
        winnerName,
        winnerMembershipId,
        totalVotesCast,
        votesReceived,
        isTie,
        tiedCandidateIds,
        candidates,
      ];
}

class ElectionResultsModel extends Equatable {
  const ElectionResultsModel({
    required this.electionId,
    required this.electionTitle,
    required this.status,
    required this.votingMethod,
    required this.ballotType,
    required this.termLengthMonths,
    this.handoverDate,
    required this.totalEligibleMembers,
    required this.uniqueVotersCount,
    required this.turnoutPercentage,
    required this.quorumPercentage,
    required this.quorumReached,
    this.disputeWindowEndsAt,
    required this.isDisputeWindowOpen,
    required this.hoursRemaining,
    required this.pendingDisputesCount,
    required this.isCertified,
    required this.roles,
  });

  factory ElectionResultsModel.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];
    final List<RoleResultModel> parsedRoles = rawRoles is List
        ? rawRoles
            .whereType<Map<String, dynamic>>()
            .map((r) => RoleResultModel.fromMap(r))
            .toList()
        : <RoleResultModel>[];

    return ElectionResultsModel(
      electionId: map['electionId'] as String? ?? '',
      electionTitle: map['electionTitle'] as String? ?? '',
      status: map['status'] as String? ?? 'TALLYING',
      votingMethod: map['votingMethod'] as String? ?? 'SIMPLE_MAJORITY',
      ballotType: map['ballotType'] as String? ?? 'SECRET',
      termLengthMonths: (map['termLengthMonths'] as num?)?.toInt() ?? 12,
      handoverDate: map['handoverDate'] != null
          ? DateTime.tryParse(map['handoverDate'].toString())
          : null,
      totalEligibleMembers: (map['totalEligibleMembers'] as num?)?.toInt() ?? 0,
      uniqueVotersCount: (map['uniqueVotersCount'] as num?)?.toInt() ?? 0,
      turnoutPercentage: (map['turnoutPercentage'] as num?)?.toDouble() ?? 0.0,
      quorumPercentage: (map['quorumPercentage'] as num?)?.toDouble() ?? 50.0,
      quorumReached: map['quorumReached'] as bool? ?? false,
      disputeWindowEndsAt: map['disputeWindowEndsAt'] != null
          ? DateTime.tryParse(map['disputeWindowEndsAt'].toString())
          : null,
      isDisputeWindowOpen: map['isDisputeWindowOpen'] as bool? ?? false,
      hoursRemaining: (map['hoursRemaining'] as num?)?.toDouble() ?? 0.0,
      pendingDisputesCount: (map['pendingDisputesCount'] as num?)?.toInt() ?? 0,
      isCertified: map['isCertified'] as bool? ?? false,
      roles: parsedRoles,
    );
  }

  final String electionId;
  final String electionTitle;
  final String status;
  final String votingMethod;
  final String ballotType;
  final int termLengthMonths;
  final DateTime? handoverDate;
  final int totalEligibleMembers;
  final int uniqueVotersCount;
  final double turnoutPercentage;
  final double quorumPercentage;
  final bool quorumReached;
  final DateTime? disputeWindowEndsAt;
  final bool isDisputeWindowOpen;
  final double hoursRemaining;
  final int pendingDisputesCount;
  final bool isCertified;
  final List<RoleResultModel> roles;

  bool get hasTies => roles.any((r) => r.isTie);
  bool get canCertify =>
      quorumReached &&
      !hasTies &&
      pendingDisputesCount == 0 &&
      !isCertified &&
      roles.isNotEmpty &&
      roles.every((r) => r.hasWinner);

  Map<String, dynamic> toMap() => {
        'electionId': electionId,
        'electionTitle': electionTitle,
        'status': status,
        'votingMethod': votingMethod,
        'ballotType': ballotType,
        'termLengthMonths': termLengthMonths,
        if (handoverDate != null) 'handoverDate': handoverDate!.toIso8601String(),
        'totalEligibleMembers': totalEligibleMembers,
        'uniqueVotersCount': uniqueVotersCount,
        'turnoutPercentage': turnoutPercentage,
        'quorumPercentage': quorumPercentage,
        'quorumReached': quorumReached,
        if (disputeWindowEndsAt != null)
          'disputeWindowEndsAt': disputeWindowEndsAt!.toIso8601String(),
        'isDisputeWindowOpen': isDisputeWindowOpen,
        'hoursRemaining': hoursRemaining,
        'pendingDisputesCount': pendingDisputesCount,
        'isCertified': isCertified,
        'roles': roles.map((r) => r.toMap()).toList(),
      };

  @override
  List<Object?> get props => [
        electionId,
        electionTitle,
        status,
        votingMethod,
        ballotType,
        termLengthMonths,
        handoverDate,
        totalEligibleMembers,
        uniqueVotersCount,
        turnoutPercentage,
        quorumPercentage,
        quorumReached,
        disputeWindowEndsAt,
        isDisputeWindowOpen,
        hoursRemaining,
        pendingDisputesCount,
        isCertified,
        roles,
      ];
}

class ElectionDisputeModel extends Equatable {
  const ElectionDisputeModel({
    required this.id,
    required this.electionId,
    required this.filedByMembershipId,
    this.filerName,
    this.filerPhone,
    required this.reason,
    required this.status,
    this.resolution,
    this.resolvedAt,
    this.createdAt,
  });

  factory ElectionDisputeModel.fromMap(Map<String, dynamic> map) {
    String? filerName;
    String? filerPhone;

    final membership = map['filedByMembership'];
    if (membership is Map<String, dynamic>) {
      final user = membership['user'];
      if (user is Map<String, dynamic>) {
        filerName = user['fullName'] as String?;
        filerPhone = user['phoneNumber'] as String?;
      }
    }

    return ElectionDisputeModel(
      id: map['id'] as String? ?? '',
      electionId: map['electionId'] as String? ?? '',
      filedByMembershipId: map['filedByMembershipId'] as String? ?? '',
      filerName: filerName ?? (map['filerName'] as String?),
      filerPhone: filerPhone ?? (map['filerPhone'] as String?),
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'PENDING',
      resolution: map['resolution'] as String?,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  final String id;
  final String electionId;
  final String filedByMembershipId;
  final String? filerName;
  final String? filerPhone;
  final String reason;
  final String status;
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  bool get isPending => status == 'PENDING';
  bool get isResolved => status == 'RESOLVED';
  bool get isDismissed => status == 'DISMISSED';

  ElectionDisputeModel copyWith({
    String? id,
    String? electionId,
    String? filedByMembershipId,
    String? filerName,
    String? filerPhone,
    String? reason,
    String? status,
    String? resolution,
    DateTime? resolvedAt,
    DateTime? createdAt,
  }) {
    return ElectionDisputeModel(
      id: id ?? this.id,
      electionId: electionId ?? this.electionId,
      filedByMembershipId: filedByMembershipId ?? this.filedByMembershipId,
      filerName: filerName ?? this.filerName,
      filerPhone: filerPhone ?? this.filerPhone,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'electionId': electionId,
        'filedByMembershipId': filedByMembershipId,
        if (filerName != null) 'filerName': filerName,
        if (filerPhone != null) 'filerPhone': filerPhone,
        'reason': reason,
        'status': status,
        if (resolution != null) 'resolution': resolution,
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        electionId,
        filedByMembershipId,
        filerName,
        filerPhone,
        reason,
        status,
        resolution,
        resolvedAt,
        createdAt,
      ];
}
