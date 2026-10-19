import 'package:equatable/equatable.dart';

enum AnnouncementCategory {
  meeting,
  funeral,
  reminder,
  general,
}

extension AnnouncementCategoryX on AnnouncementCategory {
  String get name => switch (this) {
        AnnouncementCategory.meeting => 'meeting',
        AnnouncementCategory.funeral => 'funeral',
        AnnouncementCategory.reminder => 'reminder',
        AnnouncementCategory.general => 'general',
      };

  static AnnouncementCategory fromString(String? s) => switch (s?.toLowerCase()) {
        'meeting' => AnnouncementCategory.meeting,
        'funeral' => AnnouncementCategory.funeral,
        'reminder' => AnnouncementCategory.reminder,
        _ => AnnouncementCategory.general,
      };
}

class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.postedBy,
    required this.postedByName,
    required this.createdAt,
    this.pinned = false,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> map) {
    return Announcement(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: AnnouncementCategoryX.fromString(map['category'] as String?),
      postedBy: map['postedBy'] as String? ?? '',
      postedByName: map['postedByName'] as String? ?? 'Officer',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      pinned: map['pinned'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String body;
  final AnnouncementCategory category;
  final String postedBy;
  final String postedByName;
  final DateTime createdAt;
  final bool pinned;

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    AnnouncementCategory? category,
    String? postedBy,
    String? postedByName,
    DateTime? createdAt,
    bool? pinned,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      postedBy: postedBy ?? this.postedBy,
      postedByName: postedByName ?? this.postedByName,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'category': category.name,
        'postedBy': postedBy,
        'postedByName': postedByName,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
      };

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        category,
        postedBy,
        postedByName,
        createdAt,
        pinned,
      ];
}
