import 'package:equatable/equatable.dart';

enum MessageDeliveryStatus { sending, sent, failed }

class MessageReaction extends Equatable {
  const MessageReaction({
    required this.emoji,
    required this.userId,
    required this.userName,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    return MessageReaction(
      emoji: map['emoji']?.toString() ?? '',
      userId: map['userId']?.toString() ?? map['user_id']?.toString() ?? '',
      userName: map['userName']?.toString() ?? map['user_name']?.toString() ?? '',
    );
  }

  final String emoji;
  final String userId;
  final String userName;

  Map<String, dynamic> toMap() => {
        'emoji': emoji,
        'userId': userId,
        'userName': userName,
      };

  @override
  List<Object?> get props => [emoji, userId, userName];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.idirId,
    required this.membershipId,
    required this.senderId,
    required this.senderName,
    this.senderRole = 'MEMBER',
    required this.content,
    this.messageType = 'TEXT',
    this.isEdited = false,
    this.isDeleted = false,
    this.isForwarded = false,
    this.forwardedFromName,
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedById,
    this.replyToId,
    this.replyToSenderName,
    this.replyToContent,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentDuration,
    this.reactions = const [],
    this.mentions = const [],
    this.clientMutationId,
    required this.createdAt,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    List<MessageReaction> parsedReactions = [];
    if (map['reactions'] is List) {
      parsedReactions = (map['reactions'] as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => MessageReaction.fromMap(r))
          .toList();
    }

    List<String> parsedMentions = [];
    if (map['mentions'] is List) {
      parsedMentions = (map['mentions'] as List)
          .map((m) => m?.toString() ?? '')
          .where((m) => m.isNotEmpty)
          .toList();
    }

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      idirId: map['idirId']?.toString() ?? map['idir_id']?.toString() ?? '',
      membershipId: map['membershipId']?.toString() ?? map['membership_id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? map['sender_id']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? map['sender_name']?.toString() ?? 'Idir Member',
      senderRole: map['senderRole']?.toString() ?? map['sender_role']?.toString() ?? 'MEMBER',
      content: map['content']?.toString() ?? '',
      messageType: map['messageType']?.toString() ?? map['message_type']?.toString() ?? 'TEXT',
      isEdited: map['isEdited'] == true || map['is_edited'] == true,
      isDeleted: map['isDeleted'] == true || map['is_deleted'] == true,
      isForwarded: map['isForwarded'] == true || map['is_forwarded'] == true,
      forwardedFromName: map['forwardedFromName']?.toString() ?? map['forwarded_from_name']?.toString(),
      isPinned: map['isPinned'] == true || map['is_pinned'] == true,
      pinnedAt: map['pinnedAt'] != null
          ? DateTime.tryParse(map['pinnedAt'].toString())
          : (map['pinned_at'] != null ? DateTime.tryParse(map['pinned_at'].toString()) : null),
      pinnedById: map['pinnedById']?.toString() ?? map['pinned_by_id']?.toString(),
      replyToId: map['replyToId']?.toString() ?? map['reply_to_id']?.toString(),
      replyToSenderName: map['replyToSenderName']?.toString() ?? map['reply_to_sender_name']?.toString(),
      replyToContent: map['replyToContent']?.toString() ?? map['reply_to_content']?.toString(),
      attachmentUrl: map['attachmentUrl']?.toString() ?? map['attachment_url']?.toString(),
      attachmentType: map['attachmentType']?.toString() ?? map['attachment_type']?.toString(),
      attachmentName: map['attachmentName']?.toString() ?? map['attachment_name']?.toString(),
      attachmentSize: map['attachmentSize'] is int
          ? map['attachmentSize'] as int
          : int.tryParse(map['attachmentSize']?.toString() ?? ''),
      attachmentDuration: map['attachmentDuration'] is int
          ? map['attachmentDuration'] as int
          : int.tryParse(map['attachmentDuration']?.toString() ?? ''),
      reactions: parsedReactions,
      mentions: parsedMentions,
      clientMutationId: map['clientMutationId']?.toString() ?? map['client_mutation_id']?.toString(),
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
  final String messageType;
  final bool isEdited;
  final bool isDeleted;
  final bool isForwarded;
  final String? forwardedFromName;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? pinnedById;
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToContent;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final int? attachmentSize;
  final int? attachmentDuration;
  final List<MessageReaction> reactions;
  final List<String> mentions;
  final String? clientMutationId;
  final DateTime createdAt;
  final MessageDeliveryStatus deliveryStatus;

  bool isFromUser(String currentUserId) => senderId == currentUserId;

  bool get isAnnouncement => messageType == 'ANNOUNCEMENT';
  bool get isEmergency => messageType == 'EMERGENCY';
  bool get isContributionReminder => messageType == 'CONTRIBUTION_REMINDER';
  bool get isSpecialAlert => isAnnouncement || isEmergency || isContributionReminder;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage =>
      messageType == 'IMAGE' || (attachmentType != null && attachmentType!.startsWith('image/'));
  bool get isVideo =>
      messageType == 'VIDEO' || (attachmentType != null && attachmentType!.startsWith('video/'));
  bool get isAudioOrVoice =>
      messageType == 'AUDIO' ||
      messageType == 'VOICE' ||
      (attachmentType != null && attachmentType!.startsWith('audio/'));
  bool get isPdfOrDoc =>
      messageType == 'DOCUMENT' ||
      (attachmentType != null &&
          (attachmentType!.contains('pdf') ||
              attachmentType!.contains('document') ||
              attachmentType!.contains('word') ||
              attachmentType!.contains('sheet')));

  bool get hasReply => replyToId != null && replyToId!.isNotEmpty;

  Map<String, List<MessageReaction>> get groupedReactions {
    final Map<String, List<MessageReaction>> grouped = {};
    for (final r in reactions) {
      if (!grouped.containsKey(r.emoji)) {
        grouped[r.emoji] = [];
      }
      grouped[r.emoji]!.add(r);
    }
    return grouped;
  }

  bool hasUserReacted(String userId, String emoji) {
    return reactions.any((r) => r.userId == userId && r.emoji == emoji);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idirId': idirId,
      'membershipId': membershipId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'content': content,
      'messageType': messageType,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isForwarded': isForwarded,
      if (forwardedFromName != null) 'forwardedFromName': forwardedFromName,
      'isPinned': isPinned,
      if (pinnedAt != null) 'pinnedAt': pinnedAt!.toIso8601String(),
      if (pinnedById != null) 'pinnedById': pinnedById,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentType != null) 'attachmentType': attachmentType,
      if (attachmentName != null) 'attachmentName': attachmentName,
      if (attachmentSize != null) 'attachmentSize': attachmentSize,
      if (attachmentDuration != null) 'attachmentDuration': attachmentDuration,
      'reactions': reactions.map((r) => r.toMap()).toList(),
      'mentions': mentions,
      if (clientMutationId != null) 'clientMutationId': clientMutationId,
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
    String? messageType,
    bool? isEdited,
    bool? isDeleted,
    bool? isForwarded,
    String? forwardedFromName,
    bool? isPinned,
    DateTime? pinnedAt,
    String? pinnedById,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    int? attachmentSize,
    int? attachmentDuration,
    List<MessageReaction>? reactions,
    List<String>? mentions,
    String? clientMutationId,
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
      messageType: messageType ?? this.messageType,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFromName: forwardedFromName ?? this.forwardedFromName,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      pinnedById: pinnedById ?? this.pinnedById,
      replyToId: replyToId ?? this.replyToId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToContent: replyToContent ?? this.replyToContent,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      attachmentDuration: attachmentDuration ?? this.attachmentDuration,
      reactions: reactions ?? this.reactions,
      mentions: mentions ?? this.mentions,
      clientMutationId: clientMutationId ?? this.clientMutationId,
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
        messageType,
        isEdited,
        isDeleted,
        isForwarded,
        forwardedFromName,
        isPinned,
        pinnedAt,
        pinnedById,
        replyToId,
        replyToSenderName,
        replyToContent,
        attachmentUrl,
        attachmentType,
        attachmentName,
        attachmentSize,
        attachmentDuration,
        reactions,
        mentions,
        clientMutationId,
        createdAt,
        deliveryStatus,
      ];
}
