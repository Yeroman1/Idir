import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/notification_preferences.dart';
import '../providers/notifications_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(notificationPreferencesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: prefsAsync.when(
        data: (prefs) => _buildPreferencesList(context, ref, prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Failed to load preferences: $err'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    ref.read(notificationPreferencesNotifierProvider.notifier).loadPreferences();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesList(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences prefs,
  ) {
    final theme = Theme.of(context);

    Future<void> update(NotificationPreferences newPrefs) async {
      final success = await ref
          .read(notificationPreferencesNotifierProvider.notifier)
          .updatePreferences(newPrefs);
      if (context.mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification preferences'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section: Delivery Channels
        _buildSectionHeader(context, 'DELIVERY CHANNELS'),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('In-App Notifications'),
                subtitle: const Text('Receive notifications in your Idir notification center'),
                value: prefs.inAppEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(inAppEnabled: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive instant alerts directly to your mobile device'),
                value: prefs.pushEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(pushEnabled: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('SMS Text Messages'),
                subtitle: const Text('Get urgent alerts and reminders via SMS text message'),
                value: prefs.smsEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(smsEnabled: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Email Notifications'),
                subtitle: const Text('Receive monthly summaries and reports via email'),
                value: prefs.emailEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(emailEnabled: val)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section: Reminders & Categories
        _buildSectionHeader(context, 'REMINDERS & TOPICS'),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Contribution Reminders'),
                subtitle: const Text('Timely reminders for upcoming and outstanding dues'),
                value: prefs.reminderContributions,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(reminderContributions: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Meeting Reminders'),
                subtitle: const Text('Notices about scheduled community assemblies'),
                value: prefs.reminderMeetings,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(reminderMeetings: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('General Announcements'),
                subtitle: const Text('Community announcements and leadership messages'),
                value: prefs.notifyAnnouncements,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(notifyAnnouncements: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Governance & Elections'),
                subtitle: const Text('Election schedules, voting booths, and certified outcomes'),
                value: prefs.notifyGovernance,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(notifyGovernance: val)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Assistance & Welfare'),
                subtitle: const Text('Claim decision updates and emergency fund announcements'),
                value: prefs.notifyAssistance,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(notifyAssistance: val)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section: Quiet Hours
        _buildSectionHeader(context, 'QUIET HOURS'),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Quiet Hours'),
                subtitle: const Text('Mute non-urgent push & SMS notifications during resting hours'),
                value: prefs.quietHoursEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) => update(prefs.copyWith(quietHoursEnabled: val)),
              ),
              if (prefs.quietHoursEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  title: const Text('Start Time'),
                  trailing: Text(
                    prefs.quietHoursStart ?? '22:00',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final current = _parseTime(prefs.quietHoursStart ?? '22:00');
                    final picked = await showTimePicker(context: context, initialTime: current);
                    if (picked != null) {
                      final str = _formatTime(picked);
                      update(prefs.copyWith(quietHoursStart: str));
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('End Time'),
                  trailing: Text(
                    prefs.quietHoursEnd ?? '07:00',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final current = _parseTime(prefs.quietHoursEnd ?? '07:00');
                    final picked = await showTimePicker(context: context, initialTime: current);
                    if (picked != null) {
                      final str = _formatTime(picked);
                      update(prefs.copyWith(quietHoursEnd: str));
                    }
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section: Security Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Essential Security Notices',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Account verification, password reset, and urgent community alerts are always delivered to protect your safety.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 22 : 22;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
