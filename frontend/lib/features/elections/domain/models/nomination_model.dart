import 'package:equatable/equatable.dart';

class NominationModel extends Equatable {
  const NominationModel({
    required this.id,
    required this.electionId,
    required this.role,
    required this.nomineeMembershipId,
    required this.nominatedByMembershipId,
    this.statement,
    required this.status,
    this.nomineeName,
    this.nomineeMemberNumber,
    this.nomineePhone,
    this.nomineeJoinedAt,
    this.nominatedByName,
    this.acceptedAt,
    this.declinedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory NominationModel.fromMap(Map<String, dynamic> map) {
    final nomineeMembership =
        map['nomineeMembership'] as Map<String, dynamic>?;
    final nomineeUser =
        nomineeMembership?['user'] as Map<String, dynamic>?;

    final nominatedByMembership =
        map['nominatedByMembership'] as Map<String, dynamic>?;
    final nominatedByUser =
        nominatedByMembership?['user'] as Map<String, dynamic>?;

    return NominationModel(
      id: map['id'] as String? ?? '',
      electionId: map['electionId'] as String? ?? '',
      role: map['role'] as String? ?? '',
      nomineeMembershipId: map['nomineeMembershipId'] as String? ??
          (nomineeMembership?['id'] as String? ?? ''),
      nominatedByMembershipId: map['nominatedByMembershipId'] as String? ??
          (nominatedByMembership?['id'] as String? ?? ''),
      statement: map['statement'] as String?,
      status: map['status'] as String? ?? 'PENDING',
      nomineeName: nomineeUser?['fullName'] as String? ??
          map['nomineeName'] as String?,
      nomineeMemberNumber: nomineeMembership?['memberNumber'] as String? ??
          map['nomineeMemberNumber'] as String?,
      nomineePhone: nomineeUser?['phoneNumber'] as String? ??
          map['nomineePhone'] as String?,
      nomineeJoinedAt: nomineeMembership?['joinedAt'] != null
          ? DateTime.tryParse(nomineeMembership!['joinedAt'].toString())
          : null,
      nominatedByName: nominatedByUser?['fullName'] as String? ??
          map['nominatedByName'] as String?,
      acceptedAt: map['acceptedAt'] != null
          ? DateTime.tryParse(map['acceptedAt'].toString())
          : null,
      declinedAt: map['declinedAt'] != null
          ? DateTime.tryParse(map['declinedAt'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  final String id;
  final String electionId;
  final String role;
  final String nomineeMembershipId;
  final String nominatedByMembershipId;
  final String? statement;
  final String status;
  final String? nomineeName;
  final String? nomineeMemberNumber;
  final String? nomineePhone;
  final DateTime? nomineeJoinedAt;
  final String? nominatedByName;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isDeclined => status.toUpperCase() == 'DECLINED';
  bool get isWithdrawn => status.toUpperCase() == 'WITHDRAWN';
  bool get isSelfNomination => nomineeMembershipId == nominatedByMembershipId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'electionId': electionId,
        'role': role,
        'nomineeMembershipId': nomineeMembershipId,
        'nominatedByMembershipId': nominatedByMembershipId,
        if (statement != null) 'statement': statement,
        'status': status,
        if (nomineeName != null) 'nomineeName': nomineeName,
        if (nomineeMemberNumber != null)
          'nomineeMemberNumber': nomineeMemberNumber,
        if (nomineePhone != null) 'nomineePhone': nomineePhone,
        if (nomineeJoinedAt != null)
          'nomineeJoinedAt': nomineeJoinedAt!.toIso8601String(),
        if (nominatedByName != null) 'nominatedByName': nominatedByName,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
        if (declinedAt != null) 'declinedAt': declinedAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  NominationModel copyWith({
    String? id,
    String? electionId,
    String? role,
    String? nomineeMembershipId,
    String? nominatedByMembershipId,
    String? statement,
    String? status,
    String? nomineeName,
    String? nomineeMemberNumber,
    String? nomineePhone,
    DateTime? nomineeJoinedAt,
    String? nominatedByName,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NominationModel(
      id: id ?? this.id,
      electionId: electionId ?? this.electionId,
      role: role ?? this.role,
      nomineeMembershipId: nomineeMembershipId ?? this.nomineeMembershipId,
      nominatedByMembershipId:
          nominatedByMembershipId ?? this.nominatedByMembershipId,
      statement: statement ?? this.statement,
      status: status ?? this.status,
      nomineeName: nomineeName ?? this.nomineeName,
      nomineeMemberNumber: nomineeMemberNumber ?? this.nomineeMemberNumber,
      nomineePhone: nomineePhone ?? this.nomineePhone,
      nomineeJoinedAt: nomineeJoinedAt ?? this.nomineeJoinedAt,
      nominatedByName: nominatedByName ?? this.nominatedByName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        electionId,
        role,
        nomineeMembershipId,
        nominatedByMembershipId,
        statement,
        status,
        nomineeName,
        nomineeMemberNumber,
        nomineePhone,
        nomineeJoinedAt,
        nominatedByName,
        acceptedAt,
        declinedAt,
        createdAt,
        updatedAt,
      ];
}
