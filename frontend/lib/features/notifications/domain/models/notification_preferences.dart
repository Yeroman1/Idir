import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.inAppEnabled = true,
    this.pushEnabled = true,
    this.smsEnabled = true,
    this.emailEnabled = true,
    this.reminderMeetings = true,
    this.reminderContributions = true,
    this.notifyAnnouncements = true,
    this.notifyGovernance = true,
    this.notifyAssistance = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      inAppEnabled: map['inAppEnabled'] as bool? ?? true,
      pushEnabled: map['pushEnabled'] as bool? ?? true,
      smsEnabled: map['smsEnabled'] as bool? ?? true,
      emailEnabled: map['emailEnabled'] as bool? ?? true,
      reminderMeetings: map['reminderMeetings'] as bool? ?? true,
      reminderContributions: map['reminderContributions'] as bool? ?? true,
      notifyAnnouncements: map['notifyAnnouncements'] as bool? ?? true,
      notifyGovernance: map['notifyGovernance'] as bool? ?? true,
      notifyAssistance: map['notifyAssistance'] as bool? ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: map['quietHoursStart']?.toString() ?? '22:00',
      quietHoursEnd: map['quietHoursEnd']?.toString() ?? '07:00',
    );
  }

  final bool inAppEnabled;
  final bool pushEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool reminderMeetings;
  final bool reminderContributions;
  final bool notifyAnnouncements;
  final bool notifyGovernance;
  final bool notifyAssistance;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  Map<String, dynamic> toMap() {
    return {
      'inAppEnabled': inAppEnabled,
      'pushEnabled': pushEnabled,
      'smsEnabled': smsEnabled,
      'emailEnabled': emailEnabled,
      'reminderMeetings': reminderMeetings,
      'reminderContributions': reminderContributions,
      'notifyAnnouncements': notifyAnnouncements,
      'notifyGovernance': notifyGovernance,
      'notifyAssistance': notifyAssistance,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  NotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
    bool? emailEnabled,
    bool? reminderMeetings,
    bool? reminderContributions,
    bool? notifyAnnouncements,
    bool? notifyGovernance,
    bool? notifyAssistance,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      reminderMeetings: reminderMeetings ?? this.reminderMeetings,
      reminderContributions: reminderContributions ?? this.reminderContributions,
      notifyAnnouncements: notifyAnnouncements ?? this.notifyAnnouncements,
      notifyGovernance: notifyGovernance ?? this.notifyGovernance,
      notifyAssistance: notifyAssistance ?? this.notifyAssistance,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  @override
  List<Object?> get props => [
        inAppEnabled,
        pushEnabled,
        smsEnabled,
        emailEnabled,
        reminderMeetings,
        reminderContributions,
        notifyAnnouncements,
        notifyGovernance,
        notifyAssistance,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      ];
}
