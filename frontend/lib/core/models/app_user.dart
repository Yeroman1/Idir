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

  static UserRole fromString(String s) => switch (s) {
        'chairperson' => UserRole.chairperson,
        'treasurer' => UserRole.treasurer,
        'auditor' => UserRole.auditor,
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
    this.faydaId,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String? ?? 'member'),
      memberId: map['memberId'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      faydaId: map['faydaId'] as String?,
    );
  }

  final String uid;
  final String name;
  final String phone;
  final UserRole role;
  final String memberId;
  final bool isActive;
  final DateTime createdAt;
  final String? faydaId;

  bool get isFaydaVerified => faydaId != null && faydaId!.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'role': role.name,
        'memberId': memberId,
        'isActive': isActive,
        'createdAt': createdAt,
        if (faydaId != null) 'faydaId': faydaId,
      };

  AppUser copyWith({
    String? uid,
    String? name,
    String? phone,
    UserRole? role,
    String? memberId,
    bool? isActive,
    DateTime? createdAt,
    String? faydaId,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      memberId: memberId ?? this.memberId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      faydaId: faydaId ?? this.faydaId,
    );
  }

  @override
  List<Object?> get props =>
      [uid, name, phone, role, memberId, isActive, createdAt, faydaId];
}
