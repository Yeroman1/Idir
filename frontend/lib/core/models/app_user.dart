import 'package:equatable/equatable.dart';

/// Roles supported by the app.
enum UserRole { chairperson, treasurer, auditor, member }

extension UserRoleX on UserRole {
  String get name => switch (this) {
        UserRole.chairperson => 'chairperson',
        UserRole.treasurer => 'treasurer',
        UserRole.auditor => 'auditor',
        UserRole.member => 'member',
      };

  static UserRole fromString(String s) => switch (s.toLowerCase()) {
        'chairperson' || 'creator' => UserRole.chairperson,
        'treasurer' => UserRole.treasurer,
        'auditor' || 'secretary' => UserRole.auditor,
        _ => UserRole.member,
      };

  // ── Permission helpers ──────────────────────────────────────────────
  bool get canManageMembers =>
      this == UserRole.chairperson || this == UserRole.treasurer;

  bool get canRecordContribution => this == UserRole.treasurer;

  bool get canSubmitClaim =>
      this == UserRole.chairperson ||
      this == UserRole.treasurer ||
      this == UserRole.member;

  bool get canApproveOrRejectClaim =>
      this == UserRole.chairperson || this == UserRole.treasurer;

  bool get canRecordPayout => this == UserRole.treasurer;

  bool get canPostAnnouncement =>
      this == UserRole.chairperson || this == UserRole.treasurer;

  bool get canViewAllFinances =>
      this == UserRole.chairperson ||
      this == UserRole.treasurer ||
      this == UserRole.auditor;

  bool get canViewAuditLog =>
      this == UserRole.chairperson || this == UserRole.auditor;

  bool get canViewOwnBalance => true;

  bool get canChangeSettings => this == UserRole.chairperson;

  bool get canManageElections => this == UserRole.chairperson;
}

/// Domain model representing a user's membership in a specific Idir association.
class UserMembership extends Equatable {
  const UserMembership({
    required this.id,
    required this.idirId,
    required this.idirName,
    required this.role,
    required this.memberNumber,
    required this.status,
    this.community,
    this.location,
    this.contributionAmount,
    this.contributionFrequency,
  });

  factory UserMembership.fromMap(Map<String, dynamic> map) {
    final roleStr = (map['role'] as String? ?? 'member').toUpperCase();
    final role = switch (roleStr) {
      'CREATOR' || 'CHAIRPERSON' => UserRole.chairperson,
      'TREASURER' => UserRole.treasurer,
      'AUDITOR' || 'SECRETARY' => UserRole.auditor,
      _ => UserRole.member,
    };
    final idirMap = map['idir'] as Map<String, dynamic>?;
    return UserMembership(
      id: map['id'] as String? ?? map['idirId'] as String? ?? '',
      idirId: map['idirId'] as String? ?? idirMap?['id'] as String? ?? '',
      idirName: map['idirName'] as String? ?? idirMap?['name'] as String? ?? 'Idir Community',
      role: role,
      memberNumber: map['memberNumber'] as String? ?? '',
      status: map['status'] as String? ?? idirMap?['status'] as String? ?? 'ACTIVE',
      community: map['community'] as String? ?? idirMap?['community'] as String?,
      location: map['location'] as String? ?? idirMap?['location'] as String?,
      contributionAmount: (map['contributionAmount'] != null)
          ? double.tryParse(map['contributionAmount'].toString())
          : (idirMap?['contributionAmount'] != null
              ? double.tryParse(idirMap!['contributionAmount'].toString())
              : null),
      contributionFrequency: map['contributionFrequency'] as String? ??
          idirMap?['contributionFrequency'] as String?,
    );
  }

  final String id;
  final String idirId;
  final String idirName;
  final UserRole role;
  final String memberNumber;
  final String status;
  final String? community;
  final String? location;
  final double? contributionAmount;
  final String? contributionFrequency;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isDraft => status.toUpperCase() == 'DRAFT';

  Map<String, dynamic> toMap() => {
        'id': id,
        'idirId': idirId,
        'idirName': idirName,
        'role': role.name,
        'memberNumber': memberNumber,
        'status': status,
        if (community != null) 'community': community,
        if (location != null) 'location': location,
        if (contributionAmount != null) 'contributionAmount': contributionAmount,
        if (contributionFrequency != null)
          'contributionFrequency': contributionFrequency,
      };

  UserMembership copyWith({
    String? id,
    String? idirId,
    String? idirName,
    UserRole? role,
    String? memberNumber,
    String? status,
    String? community,
    String? location,
    double? contributionAmount,
    String? contributionFrequency,
  }) {
    return UserMembership(
      id: id ?? this.id,
      idirId: idirId ?? this.idirId,
      idirName: idirName ?? this.idirName,
      role: role ?? this.role,
      memberNumber: memberNumber ?? this.memberNumber,
      status: status ?? this.status,
      community: community ?? this.community,
      location: location ?? this.location,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      contributionFrequency:
          contributionFrequency ?? this.contributionFrequency,
    );
  }

  @override
  List<Object?> get props => [
        id,
        idirId,
        idirName,
        role,
        memberNumber,
        status,
        community,
        location,
        contributionAmount,
        contributionFrequency,
      ];
}

/// Domain model for an authenticated user.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    required this.memberId,
    required this.isActive,
    required this.createdAt,
    this.idirId,
    this.idirName,
    this.memberships = const [],
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final membershipsList = (map['memberships'] as List<dynamic>?)
            ?.map((m) => UserMembership.fromMap(m as Map<String, dynamic>))
            .toList() ??
        const [];

    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String? ?? 'member'),
      memberId: map['memberId'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: switch (map['createdAt']) {
        DateTime dt => dt,
        Object obj => DateTime.tryParse(obj.toString()) ?? DateTime.now(),
        _ => DateTime.now(),
      },
      idirId: map['idirId'] as String?,
      idirName: map['idirName'] as String?,
      memberships: membershipsList,
    );
  }

  final String uid;
  final String name;
  final String phone;
  final UserRole role;
  final String memberId;
  final bool isActive;
  final DateTime createdAt;
  final String? idirId;
  final String? idirName;
  final List<UserMembership> memberships;

  String? get faydaId => null;
  bool get isFaydaVerified => true;

  bool get hasIdir => idirId != null && idirId!.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'role': role.name,
        'memberId': memberId,
        'isActive': isActive,
        'createdAt': createdAt,
        if (idirId != null) 'idirId': idirId,
        if (idirName != null) 'idirName': idirName,
        'memberships': memberships.map((m) => m.toMap()).toList(),
      };

  AppUser copyWith({
    String? uid,
    String? name,
    String? phone,
    UserRole? role,
    String? memberId,
    bool? isActive,
    DateTime? createdAt,
    String? idirId,
    String? idirName,
    List<UserMembership>? memberships,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      memberId: memberId ?? this.memberId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      idirId: idirId ?? this.idirId,
      idirName: idirName ?? this.idirName,
      memberships: memberships ?? this.memberships,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        name,
        phone,
        role,
        memberId,
        isActive,
        createdAt,
        idirId,
        idirName,
        memberships,
      ];
}
