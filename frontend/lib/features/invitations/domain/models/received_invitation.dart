import 'package:equatable/equatable.dart';

class ReceivedInvitation extends Equatable {
  const ReceivedInvitation({
    required this.id,
    required this.idirId,
    required this.idirName,
    this.community,
    this.location,
    this.description,
    this.contributionAmount,
    this.contributionFrequency,
    required this.invitedBy,
    this.phoneNumber,
    this.email,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  factory ReceivedInvitation.fromMap(Map<String, dynamic> map) {
    return ReceivedInvitation(
      id: map['id']?.toString() ?? '',
      idirId: map['idirId']?.toString() ?? '',
      idirName: map['idirName']?.toString() ?? 'Idir',
      community: map['community']?.toString(),
      location: map['location']?.toString(),
      description: map['description']?.toString(),
      contributionAmount: map['contributionAmount'] != null
          ? double.tryParse(map['contributionAmount'].toString())
          : null,
      contributionFrequency: map['contributionFrequency']?.toString(),
      invitedBy: map['invitedBy']?.toString() ?? 'Idir Officer',
      phoneNumber: map['phoneNumber']?.toString(),
      email: map['email']?.toString(),
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? (DateTime.tryParse(map['expiresAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: map['status']?.toString() ?? 'PENDING',
    );
  }

  final String id;
  final String idirId;
  final String idirName;
  final String? community;
  final String? location;
  final String? description;
  final double? contributionAmount;
  final String? contributionFrequency;
  final String invitedBy;
  final String? phoneNumber;
  final String? email;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;

  @override
  List<Object?> get props => [
        id,
        idirId,
        idirName,
        community,
        location,
        description,
        contributionAmount,
        contributionFrequency,
        invitedBy,
        phoneNumber,
        email,
        createdAt,
        expiresAt,
        status,
      ];
}
