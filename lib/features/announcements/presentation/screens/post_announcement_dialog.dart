import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/announcement.dart';
import '../providers/announcements_provider.dart';

class PostAnnouncementDialog extends ConsumerStatefulWidget {
  const PostAnnouncementDialog({super.key});

  @override
  ConsumerState<PostAnnouncementDialog> createState() =>
      _PostAnnouncementDialogState();
}

class _PostAnnouncementDialogState
    extends ConsumerState<PostAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  AnnouncementCategory _category = AnnouncementCategory.general;
  bool _isPinned = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final currentUser = ref.read(currentUserProvider);

    setState(() => _isLoading = true);

    try {
      final announcement = Announcement(
        id: const Uuid().v4(),
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        category: _category,
        postedBy: currentUser?.uid ?? 'officer',
        postedByName: currentUser?.name ?? 'Officer',
        createdAt: DateTime.now(),
        pinned: _isPinned,
      );

      final success = await ref
          .read(announcementActionNotifierProvider.notifier)
          .postAnnouncement(announcement);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Announcement posted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          navigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.campaign,
                            color: Color(0xFFE65100),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Post Announcement',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Announcement Title *',
                    hintText: 'e.g. General Assembly Review Meeting',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter an announcement title'
                      : null,
                ),
                const SizedBox(height: 16),

                // Category
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<AnnouncementCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AnnouncementCategory.meeting,
                      child: Text('General Assembly / Meeting'),
                    ),
                    DropdownMenuItem(
                      value: AnnouncementCategory.funeral,
                      child: Text('Bereavement / Funeral Aid'),
                    ),
                    DropdownMenuItem(
                      value: AnnouncementCategory.reminder,
                      child: Text('Payment / Dues Reminder'),
                    ),
                    DropdownMenuItem(
                      value: AnnouncementCategory.general,
                      child: Text('General Community Notice'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),

                // Body
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Announcement Message *',
                    hintText: 'Enter full announcement body text for members…',
                    prefixIcon: Icon(Icons.article_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter announcement text'
                      : null,
                ),
                const SizedBox(height: 12),

                // Pin Checkbox
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPinned,
                  title: const Text(
                    'Pin to top of Dashboard & Announcements',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Pinned notices are highlighted for all members',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (val) {
                    setState(() => _isPinned = val ?? false);
                  },
                  activeColor: AppColors.secondary,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
