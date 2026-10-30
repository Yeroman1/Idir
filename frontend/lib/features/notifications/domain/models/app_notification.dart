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

  String? get invitationId => data?['invitationId']?.toString();
  String? get idirId => data?['idirId']?.toString();
  String? get idirName => data?['idirName']?.toString();

  @override
  List<Object?> get props => [id, title, body, type, data, readAt, createdAt];
}

