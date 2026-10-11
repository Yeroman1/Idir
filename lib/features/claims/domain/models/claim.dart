import 'package:equatable/equatable.dart';

import '../../../../core/models/app_user.dart';

enum ClaimType {
  funeral,
  illness,
  other,
}

extension ClaimTypeX on ClaimType {
  String get name => switch (this) {
        ClaimType.funeral => 'funeral',
        ClaimType.illness => 'illness',
        ClaimType.other => 'other',
      };

  static ClaimType fromString(String? s) => switch (s?.toLowerCase()) {
        'funeral' => ClaimType.funeral,
        'illness' => ClaimType.illness,
        _ => ClaimType.other,
      };
}

enum ClaimStatus {
  submitted,
  approved,
  rejected,
  paid,
}

extension ClaimStatusX on ClaimStatus {
  String get name => switch (this) {
        ClaimStatus.submitted => 'submitted',
        ClaimStatus.approved => 'approved',
        ClaimStatus.rejected => 'rejected',
        ClaimStatus.paid => 'paid',
      };

  static ClaimStatus fromString(String? s) => switch (s?.toLowerCase()) {
        'approved' => ClaimStatus.approved,
        'rejected' => ClaimStatus.rejected,
        'paid' => ClaimStatus.paid,
        _ => ClaimStatus.submitted,
      };
}

class ClaimApproval extends Equatable {
  const ClaimApproval({
    required this.uid,
    required this.name,
    required this.role,
    required this.decision,
    required this.comment,
    required this.at,
  });

  factory ClaimApproval.fromMap(Map<String, dynamic> map) {
    return ClaimApproval(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? '',
      decision: map['decision'] as String? ?? 'approved',
      comment: map['comment'] as String? ?? '',
      at: map['at'] != null
          ? DateTime.tryParse(map['at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String uid;
  final String name;
  final String role;
  final String decision; // 'approved' | 'rejected'
  final String comment;
  final DateTime at;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'role': role,
        'decision': decision,
        'comment': comment,
        'at': at.toIso8601String(),
      };

  @override
  List<Object?> get props => [uid, name, role, decision, comment, at];
}

class Claim extends Equatable {
  const Claim({
    required this.id,
    required this.claimNumber,
    required this.memberId,
    required this.memberName,
    required this.type,
    required this.description,
    required this.requestedAmount,
    required this.status,
    required this.submittedBy,
    required this.submittedByName,
    required this.approvals,
    this.payoutAmount,
    this.paidAt,
    this.payoutExpenseId,
    required this.createdAt,
  });

  factory Claim.fromMap(String id, Map<String, dynamic> map) {
    final rawApprovals = map['approvals'] as List<dynamic>? ?? [];
    final approvalsList = rawApprovals
        .map((a) => ClaimApproval.fromMap(a as Map<String, dynamic>))
        .toList();

    return Claim(
      id: id,
      claimNumber: map['claimNumber'] as String? ?? 'CLM-001',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      type: ClaimTypeX.fromString(map['type'] as String?),
      description: map['description'] as String? ?? '',
      requestedAmount: (map['requestedAmount'] as num?)?.toDouble() ?? 0.0,
      status: ClaimStatusX.fromString(map['status'] as String?),
      submittedBy: map['submittedBy'] as String? ?? '',
      submittedByName: map['submittedByName'] as String? ?? '',
      approvals: approvalsList,
      payoutAmount: (map['payoutAmount'] as num?)?.toDouble(),
      paidAt: map['paidAt'] != null
          ? DateTime.tryParse(map['paidAt'].toString())
          : null,
      payoutExpenseId: map['payoutExpenseId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String id;
  final String claimNumber;
  final String memberId;
  final String memberName;
  final ClaimType type;
  final String description;
  final double requestedAmount;
  final ClaimStatus status;
  final String submittedBy;
  final String submittedByName;
  final List<ClaimApproval> approvals;
  final double? payoutAmount;
  final DateTime? paidAt;
  final String? payoutExpenseId;
  final DateTime createdAt;

  int get approvedCount =>
      approvals.where((a) => a.decision == 'approved').length;
  int get rejectedCount =>
      approvals.where((a) => a.decision == 'rejected').length;

  bool hasVoted(String uid) => approvals.any((a) => a.uid == uid);

  /// An officer cannot approve their own submitted claim (Self-approval prevention)
  bool canVote(String uid, UserRole role) {
    final isOfficer =
        role == UserRole.chairperson || role == UserRole.treasurer;
    final isSelf = submittedBy == uid;
    return isOfficer && !isSelf && !hasVoted(uid) && status == ClaimStatus.submitted;
  }

  /// Treasurer can record payout only when approved
  bool canRecordPayout(UserRole role) {
    return role == UserRole.treasurer && status == ClaimStatus.approved;
  }

  Claim copyWith({
    String? id,
    String? claimNumber,
    String? memberId,
    String? memberName,
    ClaimType? type,
    String? description,
    double? requestedAmount,
    ClaimStatus? status,
    String? submittedBy,
    String? submittedByName,
    List<ClaimApproval>? approvals,
    double? payoutAmount,
    DateTime? paidAt,
    String? payoutExpenseId,
    DateTime? createdAt,
  }) {
    return Claim(
      id: id ?? this.id,
      claimNumber: claimNumber ?? this.claimNumber,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      type: type ?? this.type,
      description: description ?? this.description,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      status: status ?? this.status,
      submittedBy: submittedBy ?? this.submittedBy,
      submittedByName: submittedByName ?? this.submittedByName,
      approvals: approvals ?? this.approvals,
      payoutAmount: payoutAmount ?? this.payoutAmount,
      paidAt: paidAt ?? this.paidAt,
      payoutExpenseId: payoutExpenseId ?? this.payoutExpenseId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'claimNumber': claimNumber,
        'memberId': memberId,
        'memberName': memberName,
        'type': type.name,
        'description': description,
        'requestedAmount': requestedAmount,
        'status': status.name,
        'submittedBy': submittedBy,
        'submittedByName': submittedByName,
        'approvals': approvals.map((a) => a.toMap()).toList(),
        if (payoutAmount != null) 'payoutAmount': payoutAmount,
        if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
        if (payoutExpenseId != null) 'payoutExpenseId': payoutExpenseId,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        claimNumber,
        memberId,
        memberName,
        type,
        description,
        requestedAmount,
        status,
        submittedBy,
        submittedByName,
        approvals,
        payoutAmount,
        paidAt,
        payoutExpenseId,
        createdAt,
      ];
}
