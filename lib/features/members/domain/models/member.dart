import 'package:equatable/equatable.dart';

enum MemberStatus { active, suspended, deceased }

extension MemberStatusX on MemberStatus {
  String get name => switch (this) {
        MemberStatus.active => 'active',
        MemberStatus.suspended => 'suspended',
        MemberStatus.deceased => 'deceased',
      };

  static MemberStatus fromString(String? s) => switch (s?.toLowerCase()) {
        'suspended' => MemberStatus.suspended,
        'deceased' => MemberStatus.deceased,
        _ => MemberStatus.active,
      };
}

class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
    );
  }

  final String name;
  final String phone;
  final String relationship;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  @override
  List<Object?> get props => [name, phone, relationship];
}

class Dependent extends Equatable {
  const Dependent({
    required this.id,
    required this.name,
    required this.relationship,
  });

  factory Dependent.fromMap(Map<String, dynamic> map) {
    return Dependent(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String relationship;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'relationship': relationship,
      };

  @override
  List<Object?> get props => [id, name, relationship];
}

class Member extends Equatable {
  const Member({
    required this.id,
    required this.memberId,
    required this.fullName,
    required this.phone,
    required this.registeredAt,
    this.monthlyDues = 50.0,
    this.status = MemberStatus.active,
    this.emergencyContact,
    this.dependents = const [],
    this.totalPaid = 0.0,
    this.balance = 0.0,
    this.arrears = 0.0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Member.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      try {
        // Support Firestore Timestamp
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.tryParse(value.toString()) ?? DateTime.now();
      }
    }

    final depList = (map['dependents'] as List<dynamic>? ?? [])
        .map((d) => Dependent.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

    return Member(
      id: docId,
      memberId: map['memberId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      registeredAt: parseDate(map['registeredAt']),
      monthlyDues: (map['monthlyDues'] as num?)?.toDouble() ?? 50.0,
      status: MemberStatusX.fromString(map['status'] as String?),
      emergencyContact: map['emergencyContact'] != null
          ? EmergencyContact.fromMap(
              Map<String, dynamic>.from(map['emergencyContact'] as Map))
          : null,
      dependents: depList,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      arrears: (map['arrears'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  final String id;
  final String memberId;
  final String fullName;
  final String phone;
  final DateTime registeredAt;
  final double monthlyDues;
  final MemberStatus status;
  final EmergencyContact? emergencyContact;
  final List<Dependent> dependents;
  final double totalPaid;
  final double balance;
  final double arrears;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == MemberStatus.active;
  bool get isSuspended => status == MemberStatus.suspended;
  bool get isDeceased => status == MemberStatus.deceased;

  Member copyWith({
    String? id,
    String? memberId,
    String? fullName,
    String? phone,
    DateTime? registeredAt,
    double? monthlyDues,
    MemberStatus? status,
    EmergencyContact? emergencyContact,
    List<Dependent>? dependents,
    double? totalPaid,
    double? balance,
    double? arrears,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      registeredAt: registeredAt ?? this.registeredAt,
      monthlyDues: monthlyDues ?? this.monthlyDues,
      status: status ?? this.status,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      dependents: dependents ?? this.dependents,
      totalPaid: totalPaid ?? this.totalPaid,
      balance: balance ?? this.balance,
      arrears: arrears ?? this.arrears,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'memberId': memberId,
        'fullName': fullName,
        'phone': phone,
        'registeredAt': registeredAt.toIso8601String(),
        'monthlyDues': monthlyDues,
        'status': status.name,
        'emergencyContact': emergencyContact?.toMap(),
        'dependents': dependents.map((d) => d.toMap()).toList(),
        'totalPaid': totalPaid,
        'balance': balance,
        'arrears': arrears,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        memberId,
        fullName,
        phone,
        registeredAt,
        monthlyDues,
        status,
        emergencyContact,
        dependents,
        totalPaid,
        balance,
        arrears,
        notes,
        createdAt,
        updatedAt,
      ];
}
