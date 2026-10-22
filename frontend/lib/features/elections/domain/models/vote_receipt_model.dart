import 'package:equatable/equatable.dart';

class VoteReceiptModel extends Equatable {
  const VoteReceiptModel({
    required this.id,
    required this.electionId,
    required this.role,
    required this.votedAt,
    this.receiptTokenHash,
    this.ballotType = 'SECRET',
    this.isSecret = true,
  });

  factory VoteReceiptModel.fromMap(Map<String, dynamic> map) {
    return VoteReceiptModel(
      id: map['id'] as String? ?? (map['receiptId'] as String? ?? ''),
      electionId: map['electionId'] as String? ?? '',
      role: map['role'] as String? ?? '',
      votedAt: map['votedAt'] != null
          ? DateTime.tryParse(map['votedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      receiptTokenHash: map['receiptTokenHash'] as String?,
      ballotType: map['ballotType'] as String? ?? 'SECRET',
      isSecret: map['isSecret'] as bool? ?? (map['ballotType'] != 'OPEN'),
    );
  }

  final String id;
  final String electionId;
  final String role;
  final DateTime votedAt;
  final String? receiptTokenHash;
  final String ballotType;
  final bool isSecret;

  Map<String, dynamic> toMap() => {
        'id': id,
        'electionId': electionId,
        'role': role,
        'votedAt': votedAt.toIso8601String(),
        if (receiptTokenHash != null) 'receiptTokenHash': receiptTokenHash,
        'ballotType': ballotType,
        'isSecret': isSecret,
      };

  @override
  List<Object?> get props => [
        id,
        electionId,
        role,
        votedAt,
        receiptTokenHash,
        ballotType,
        isSecret,
      ];
}

class VotingStatusModel extends Equatable {
  const VotingStatusModel({
    required this.electionId,
    required this.electionTitle,
    required this.ballotType,
    required this.votingMethod,
    required this.isWindowOpen,
    required this.isFaydaVerified,
    required this.isTenureEligible,
    required this.canVote,
    required this.roles,
    required this.votedRoles,
    required this.pendingRoles,
    required this.receipts,
    required this.allRolesVoted,
  });

  factory VotingStatusModel.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'];
    final List<String> parsedRoles = rawRoles is List
        ? rawRoles.map((e) => e.toString()).toList()
        : <String>[];

    final rawVoted = map['votedRoles'];
    final List<String> parsedVoted = rawVoted is List
        ? rawVoted.map((e) => e.toString()).toList()
        : <String>[];

    final rawPending = map['pendingRoles'];
    final List<String> parsedPending = rawPending is List
        ? rawPending.map((e) => e.toString()).toList()
        : <String>[];

    final rawReceipts = map['receipts'];
    final List<VoteReceiptModel> parsedReceipts = rawReceipts is List
        ? rawReceipts
            .whereType<Map<String, dynamic>>()
            .map((r) => VoteReceiptModel.fromMap(r))
            .toList()
        : <VoteReceiptModel>[];

    return VotingStatusModel(
      electionId: map['electionId'] as String? ?? '',
      electionTitle: map['electionTitle'] as String? ?? 'Leadership Election',
      ballotType: map['ballotType'] as String? ?? 'SECRET',
      votingMethod: map['votingMethod'] as String? ?? 'SIMPLE_MAJORITY',
      isWindowOpen: map['isWindowOpen'] as bool? ?? false,
      isFaydaVerified: map['isFaydaVerified'] as bool? ?? false,
      isTenureEligible: map['isTenureEligible'] as bool? ?? true,
      canVote: map['canVote'] as bool? ?? false,
      roles: parsedRoles,
      votedRoles: parsedVoted,
      pendingRoles: parsedPending,
      receipts: parsedReceipts,
      allRolesVoted: map['allRolesVoted'] as bool? ?? false,
    );
  }

  final String electionId;
  final String electionTitle;
  final String ballotType;
  final String votingMethod;
  final bool isWindowOpen;
  final bool isFaydaVerified;
  final bool isTenureEligible;
  final bool canVote;
  final List<String> roles;
  final List<String> votedRoles;
  final List<String> pendingRoles;
  final List<VoteReceiptModel> receipts;
  final bool allRolesVoted;

  bool hasVotedForRole(String role) => votedRoles.contains(role);

  VoteReceiptModel? getReceiptForRole(String role) {
    try {
      return receipts.firstWhere((r) => r.role == role);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        electionId,
        electionTitle,
        ballotType,
        votingMethod,
        isWindowOpen,
        isFaydaVerified,
        isTenureEligible,
        canVote,
        roles,
        votedRoles,
        pendingRoles,
        receipts,
        allRolesVoted,
      ];
}
