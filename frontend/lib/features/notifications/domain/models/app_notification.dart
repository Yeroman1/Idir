import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'ANNOUNCEMENT',
      data: map['data'] is Map<String, dynamic> ? map['data'] as Map<String, dynamic> : null,
      readAt: map['readAt'] != null ? DateTime.tryParse(map['readAt'].toString()) : null,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  bool get isInvitation =>
      type == 'INVITATION' ||
      (data != null && data!['type'] == 'INVITATION') ||
      title.toLowerCase().contains('invitation');

  bool get isMeeting =>
      type == 'MEETING_REMINDER' ||
      (data != null && data!['meetingId'] != null) ||
      title.toLowerCase().contains('meeting');

  bool get isContribution =>
      type == 'PAYMENT_DUE' ||
      type == 'PAYMENT_CONFIRMED' ||
      (data != null && (data!['contributionId'] != null || data!['periodMonth'] != null)) ||
      title.toLowerCase().contains('contribution') ||
      title.toLowerCase().contains('payment');

  bool get isIkub =>
      type == 'IKUB_DRAW' ||
      (data != null && data!['ikubGroupId'] != null) ||
      title.toLowerCase().contains('ikub');

  bool get isAssistance =>
      type == 'ASSISTANCE_UPDATE' ||
      (data != null && data!['caseId'] != null) ||
      title.toLowerCase().contains('assistance');

  bool get isGovernance =>
      type == 'GOVERNANCE' ||
      (data != null && data!['electionId'] != null) ||
      title.toLowerCase().contains('election');

  bool get isUrgent =>
      type == 'URGENT_ALERT' ||
      (data != null && data!['priority'] == 'URGENT');

  String? get invitationId => data?['invitationId']?.toString();
  String? get idirId => data?['idirId']?.toString();
  String? get idirName => data?['idirName']?.toString();
  String? get meetingId => data?['meetingId']?.toString();
  String? get contributionId => data?['contributionId']?.toString();
  String? get electionId => data?['electionId']?.toString();
  String? get caseId => data?['caseId']?.toString();

  @override
  List<Object?> get props => [id, title, body, type, data, readAt, createdAt];
}
