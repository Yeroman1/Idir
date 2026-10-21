class InvitationItem {
  const InvitationItem({
    required this.id,
    required this.phoneNumber,
    required this.inviteUrl,
    required this.expiresAt,
  });

  factory InvitationItem.fromMap(Map<String, dynamic> map) {
    return InvitationItem(
      id: map['id']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      inviteUrl: map['inviteUrl']?.toString() ?? '',
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String id;
  final String phoneNumber;
  final String inviteUrl;
  final DateTime expiresAt;
}

class SkippedInvitation {
  const SkippedInvitation({
    required this.phoneNumber,
    required this.reason,
  });

  factory SkippedInvitation.fromMap(Map<String, dynamic> map) {
    return SkippedInvitation(
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
    );
  }

  final String phoneNumber;
  final String reason;
}

class BatchInvitationResult {
  const BatchInvitationResult({
    required this.totalRequested,
    required this.sentCount,
    required this.invitations,
    required this.skipped,
  });

  factory BatchInvitationResult.fromMap(Map<String, dynamic> map) {
    final invList = (map['invitations'] as List?)
            ?.map((x) => InvitationItem.fromMap(x as Map<String, dynamic>))
            .toList() ??
        [];

    final skipList = (map['skipped'] as List?)
            ?.map((x) => SkippedInvitation.fromMap(x as Map<String, dynamic>))
            .toList() ??
        [];

    return BatchInvitationResult(
      totalRequested: (map['totalRequested'] as num?)?.toInt() ?? 0,
      sentCount: (map['sentCount'] as num?)?.toInt() ?? invList.length,
      invitations: invList,
      skipped: skipList,
    );
  }

  final int totalRequested;
  final int sentCount;
  final List<InvitationItem> invitations;
  final List<SkippedInvitation> skipped;
}

class PublicInvitationDetails {
  const PublicInvitationDetails({
    required this.phoneNumber,
    required this.expiresAt,
    required this.idirId,
    required this.idirName,
    required this.community,
    required this.location,
    required this.purpose,
    required this.rules,
    required this.contributionAmount,
    required this.contributionFrequency,
  });

  factory PublicInvitationDetails.fromMap(Map<String, dynamic> map) {
    final inv = map['invitation'] as Map<String, dynamic>? ?? {};
    final idir = map['idir'] as Map<String, dynamic>? ?? {};

    return PublicInvitationDetails(
      phoneNumber: inv['phoneNumber']?.toString() ?? '',
      expiresAt: inv['expiresAt'] != null
          ? DateTime.tryParse(inv['expiresAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      idirId: idir['id']?.toString() ?? '',
      idirName: idir['name']?.toString() ?? '',
      community: idir['community']?.toString() ?? '',
      location: idir['location']?.toString() ?? '',
      purpose: idir['purpose']?.toString() ?? '',
      rules: idir['rules']?.toString() ?? '',
      contributionAmount: (idir['contributionAmount'] as num?)?.toDouble() ?? 0.0,
      contributionFrequency: idir['contributionFrequency']?.toString() ?? 'MONTHLY',
    );
  }

  final String phoneNumber;
  final DateTime expiresAt;
  final String idirId;
  final String idirName;
  final String community;
  final String location;
  final String purpose;
  final String rules;
  final double contributionAmount;
  final String contributionFrequency;
}

