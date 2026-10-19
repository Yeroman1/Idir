import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

const String genesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

class AuditLogEntry extends Equatable {
  const AuditLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.targetCollection,
    required this.targetId,
    required this.summary,
    required this.createdAt,
    required this.prevHash,
    required this.hash,
  });

  factory AuditLogEntry.create({
    required String id,
    required String actorUid,
    required String actorName,
    required String actorRole,
    required String action,
    required String targetCollection,
    required String targetId,
    required String summary,
    required DateTime createdAt,
    required String prevHash,
  }) {
    final computedHash = computeHash(
      prevHash: prevHash,
      actorUid: actorUid,
      action: action,
      targetId: targetId,
      createdAt: createdAt,
    );

    return AuditLogEntry(
      id: id,
      actorUid: actorUid,
      actorName: actorName,
      actorRole: actorRole,
      action: action,
      targetCollection: targetCollection,
      targetId: targetId,
      summary: summary,
      createdAt: createdAt,
      prevHash: prevHash,
      hash: computedHash,
    );
  }

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> map) {
    return AuditLogEntry(
      id: id,
      actorUid: map['actorUid'] as String? ?? '',
      actorName: map['actorName'] as String? ?? 'System',
      actorRole: map['actorRole'] as String? ?? 'officer',
      action: map['action'] as String? ?? 'unknown',
      targetCollection: map['targetCollection'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      prevHash: map['prevHash'] as String? ?? genesisHash,
      hash: map['hash'] as String? ?? '',
    );
  }

  final String id;
  final String actorUid;
  final String actorName;
  final String actorRole;
  final String action;
  final String targetCollection;
  final String targetId;
  final String summary;
  final DateTime createdAt;
  final String prevHash;
  final String hash;

  /// Rule 7: hash = SHA-256(prevHash + actorUid + action + targetId + createdAt)
  static String computeHash({
    required String prevHash,
    required String actorUid,
    required String action,
    required String targetId,
    required DateTime createdAt,
  }) {
    final payload =
        '$prevHash$actorUid$action$targetId${createdAt.toIso8601String()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  String computeExpectedHash() => computeHash(
        prevHash: prevHash,
        actorUid: actorUid,
        action: action,
        targetId: targetId,
        createdAt: createdAt,
      );

  bool get isHashValid => computeExpectedHash() == hash;

  Map<String, dynamic> toMap() => {
        'actorUid': actorUid,
        'actorName': actorName,
        'actorRole': actorRole,
        'action': action,
        'targetCollection': targetCollection,
        'targetId': targetId,
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'prevHash': prevHash,
        'hash': hash,
      };

  @override
  List<Object?> get props => [
        id,
        actorUid,
        actorName,
        actorRole,
        action,
        targetCollection,
        targetId,
        summary,
        createdAt,
        prevHash,
        hash,
      ];
}

class AuditVerificationResult extends Equatable {
  const AuditVerificationResult({
    required this.isValid,
    required this.totalEntries,
    required this.verifiedEntries,
    this.brokenEntryIndex,
    this.brokenEntryId,
    this.errorMessage,
  });

  final bool isValid;
  final int totalEntries;
  final int verifiedEntries;
  final int? brokenEntryIndex;
  final String? brokenEntryId;
  final String? errorMessage;

  @override
  List<Object?> get props => [
        isValid,
        totalEntries,
        verifiedEntries,
        brokenEntryIndex,
        brokenEntryId,
        errorMessage,
      ];
}
