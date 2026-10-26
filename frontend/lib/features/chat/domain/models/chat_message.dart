import 'package:equatable/equatable.dart';

enum MessageDeliveryStatus { sending, sent, failed }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.idirId,
    required this.membershipId,
    required this.senderId,
    required this.senderName,
    this.senderRole = 'MEMBER',
    required this.content,
    required this.createdAt,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      idirId: map['idirId']?.toString() ?? map['idir_id']?.toString() ?? '',
      membershipId: map['membershipId']?.toString() ?? map['membership_id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? map['sender_id']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? map['sender_name']?.toString() ?? 'Idir Member',
      senderRole: map['senderRole']?.toString() ?? map['sender_role']?.toString() ?? 'MEMBER',
      content: map['content']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : (map['created_at'] != null
              ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
              : DateTime.now()),
      deliveryStatus: MessageDeliveryStatus.sent,
    );
  }

  final String id;
  final String idirId;
  final String membershipId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String content;
  final DateTime createdAt;
  final MessageDeliveryStatus deliveryStatus;

  bool isFromUser(String currentUserId) => senderId == currentUserId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idirId': idirId,
      'membershipId': membershipId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? idirId,
    String? membershipId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    DateTime? createdAt,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      idirId: idirId ?? this.idirId,
      membershipId: membershipId ?? this.membershipId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  @override
  List<Object?> get props => [
        id,
        idirId,
        membershipId,
        senderId,
        senderName,
        senderRole,
        content,
        createdAt,
        deliveryStatus,
      ];
}
