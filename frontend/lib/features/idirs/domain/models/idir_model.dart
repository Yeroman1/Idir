class IdirModel {
  const IdirModel({
    required this.id,
    required this.name,
    required this.community,
    required this.location,
    required this.purpose,
    required this.contributionAmount,
    required this.contributionFrequency,
    required this.status,
    this.createdById,
    this.createdAt,
    this.updatedAt,
  });

  factory IdirModel.fromMap(Map<String, dynamic> map) {
    return IdirModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      community: map['community'] as String? ?? '',
      location: map['location'] as String? ?? '',
      purpose: map['purpose'] as String? ?? '',
      contributionAmount: (map['contributionAmount'] != null)
          ? double.tryParse(map['contributionAmount'].toString()) ?? 0.0
          : 0.0,
      contributionFrequency:
          map['contributionFrequency'] as String? ?? 'MONTHLY',
      status: map['status'] as String? ?? 'DRAFT',
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
  final String name;
  final String community;
  final String location;
  final String purpose;
  final double contributionAmount;
  final String contributionFrequency;
  final String status;
  final String? createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => status.toUpperCase() == 'DRAFT';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'community': community,
        'location': location,
        'purpose': purpose,
        'contributionAmount': contributionAmount,
        'contributionFrequency': contributionFrequency,
        'status': status,
        if (createdById != null) 'createdById': createdById,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}
