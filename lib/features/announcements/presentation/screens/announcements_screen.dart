import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/announcement.dart';
import '../providers/announcements_provider.dart';
import 'post_announcement_dialog.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  Color _categoryColor(AnnouncementCategory cat) {
    switch (cat) {
      case AnnouncementCategory.meeting:
        return const Color(0xFF1565C0); // Blue
      case AnnouncementCategory.funeral:
        return const Color(0xFF455A64); // Slate
      case AnnouncementCategory.reminder:
        return AppColors.secondary; // Amber
      case AnnouncementCategory.general:
        return AppColors.primary; // Teal
    }
  }

  String _categoryLabel(AnnouncementCategory cat) {
    switch (cat) {
      case AnnouncementCategory.meeting:
        return 'MEETING';
      case AnnouncementCategory.funeral:
        return 'CONDOLENCE';
      case AnnouncementCategory.reminder:
        return 'REMINDER';
      case AnnouncementCategory.general:
        return 'GENERAL';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Announcement a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Are you sure you want to delete "${a.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(announcementActionNotifierProvider.notifier)
          .deleteAnnouncement(a.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement removed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final announcements = ref.watch(filteredAnnouncementsProvider);
    final currentFilter = ref.watch(announcementsCategoryFilterProvider);

    final canPost = user?.role == UserRole.chairperson ||
        user?.role == UserRole.treasurer;
    final isChair = user?.role == UserRole.chairperson;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.announcements),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const PostAnnouncementDialog(),
                );
              },
              icon: const Icon(Icons.campaign),
              label: const Text('Post Notice'),
            )
          : null,
      body: Column(
        children: [
          // ── Search Bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: SearchBar(
              hintText: 'Search announcements…',
              leading: const Icon(Icons.search),
              trailing: [
                if (ref.watch(announcementsSearchQueryProvider).isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ref
                          .read(announcementsSearchQueryProvider.notifier)
                          .state = '';
                    },
                  ),
              ],
              onChanged: (q) {
                ref.read(announcementsSearchQueryProvider.notifier).state = q;
              },
            ),
          ),

          // ── Category Filter Chips ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.filterAll),
                  selected: currentFilter == null,
                  onSelected: (_) {
                    ref
                        .read(announcementsCategoryFilterProvider.notifier)
                        .state = null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Meetings'),
                  selected: currentFilter == AnnouncementCategory.meeting,
                  onSelected: (_) {
                    ref
                        .read(announcementsCategoryFilterProvider.notifier)
                        .state = AnnouncementCategory.meeting;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Condolences'),
                  selected: currentFilter == AnnouncementCategory.funeral,
                  onSelected: (_) {
                    ref
                        .read(announcementsCategoryFilterProvider.notifier)
                        .state = AnnouncementCategory.funeral;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Reminders'),
                  selected: currentFilter == AnnouncementCategory.reminder,
                  onSelected: (_) {
                    ref
                        .read(announcementsCategoryFilterProvider.notifier)
                        .state = AnnouncementCategory.reminder;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('General'),
                  selected: currentFilter == AnnouncementCategory.general,
                  onSelected: (_) {
                    ref
                        .read(announcementsCategoryFilterProvider.notifier)
                        .state = AnnouncementCategory.general;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Announcements List ───────────────────────────────────────────
          Expanded(
            child: announcements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 56,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.emptyState,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final a = announcements[index];
                      final catColor = _categoryColor(a.category);
                      final dateStr =
                          DateFormat('dd MMM yyyy, HH:mm').format(a.createdAt);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: a.pinned
                                ? AppColors.secondary.withValues(alpha: 0.5)
                                : theme.dividerColor.withValues(alpha: 0.5),
                            width: a.pinned ? 1.5 : 1.0,
                          ),
                        ),
                        child: Container(
                          decoration: a.pinned
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: AppColors.secondary.withValues(alpha: 0.04),
                                )
                              : null,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top badge row: Pinned tag & Category
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (a.pinned) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.push_pin,
                                                  size: 13,
                                                  color: AppColors.secondary),
                                              SizedBox(width: 4),
                                              Text(
                                                'PINNED',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color:
                                              catColor.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _categoryLabel(a.category),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: catColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Title
                              Text(
                                a.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Body
                              Text(
                                a.body,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              // Footer: Author & Officer Actions
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Posted by: ${a.postedByName}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  if (canPost)
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            a.pinned
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined,
                                            size: 18,
                                            color: a.pinned
                                                ? AppColors.secondary
                                                : Colors.grey,
                                          ),
                                          tooltip: a.pinned
                                              ? 'Unpin from top'
                                              : 'Pin to top',
                                          onPressed: () {
                                            ref
                                                .read(
                                                    announcementActionNotifierProvider
                                                        .notifier)
                                                .togglePin(a.id, !a.pinned);
                                          },
                                        ),
                                        if (isChair)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.error,
                                            ),
                                            tooltip: 'Delete announcement',
                                            onPressed: () =>
                                                _confirmDelete(context, ref, a),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
