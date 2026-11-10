import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/core/theme/app_theme.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/cooperation/domain/models/cooperation_models.dart';
import 'package:idir_app/features/cooperation/presentation/providers/cooperation_provider.dart';
import 'package:idir_app/features/cooperation/presentation/widgets/cooperation_dialogs.dart';

class CooperationDetailScreen extends ConsumerStatefulWidget {
  const CooperationDetailScreen({
    super.key,
    required this.agreementId,
  });

  final String agreementId;

  @override
  ConsumerState<CooperationDetailScreen> createState() => _CooperationDetailScreenState();
}

class _CooperationDetailScreenState extends ConsumerState<CooperationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getIdirId() {
    final user = ref.read(currentUserProvider);
    if (user == null) return '';
    if (user.memberships.isEmpty) return user.idirId ?? '';
    try {
      return user.memberships.firstWhere((m) => m.isActive).idirId;
    } catch (_) {
      return user.memberships.first.idirId;
    }
  }

  Future<void> _respondToCooperation(String action, {String? rejectionReason}) async {
    final idirId = _getIdirId();
    await ref.read(cooperationActionProvider.notifier).respondToCooperation(
          idirId,
          widget.agreementId,
          action: action,
          rejectionReason: rejectionReason,
        );
    if (mounted) {
      final s = ref.read(cooperationActionProvider);
      s.when(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(action == 'accept' ? 'Cooperation accepted!' : 'Cooperation rejected.'),
              backgroundColor: action == 'accept' ? AppColors.success : AppColors.error,
            ),
          );
          ref.invalidate(cooperationDetailProvider((idirId, widget.agreementId)));
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        },
        loading: () {},
      );
    }
  }

  Future<void> _endCooperation(String reason) async {
    final idirId = _getIdirId();
    await ref.read(cooperationActionProvider.notifier).endCooperation(idirId, widget.agreementId, reason);
    if (mounted) {
      final s = ref.read(cooperationActionProvider);
      s.when(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cooperation ended.'), backgroundColor: AppColors.warning),
          );
          ref.invalidate(cooperationDetailProvider((idirId, widget.agreementId)));
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        },
        loading: () {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final idirId = _getIdirId();
    final isChairperson = user?.role == UserRole.chairperson;
    final agreementAsync = ref.watch(cooperationDetailProvider((idirId, widget.agreementId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperation Detail'),
        actions: agreementAsync.whenOrNull(
          data: (agreement) {
            if (!isChairperson) return null;
            final actions = <Widget>[];
            if (agreement.status == CooperationStatus.pending) {
              actions.addAll([
                TextButton(
                  onPressed: () => _respondToCooperation('accept'),
                  child: const Text('Accept', style: TextStyle(color: AppColors.success)),
                ),
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => RespondToCooperationDialog(
                      onRespond: (action, reason) => _respondToCooperation(action, rejectionReason: reason),
                    ),
                  ),
                  child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                ),
              ]);
            } else if (agreement.status == CooperationStatus.active) {
              actions.add(
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => EndCooperationDialog(
                      onConfirm: (reason) => _endCooperation(reason),
                    ),
                  ),
                  child: const Text('End', style: TextStyle(color: AppColors.error)),
                ),
              );
            }
            return actions;
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Initiatives'),
            Tab(text: 'Announcements'),
            Tab(text: 'Emergencies'),
            Tab(text: 'Financial'),
          ],
        ),
      ),
      body: agreementAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(cooperationDetailProvider((idirId, widget.agreementId))),
        ),
        data: (agreement) {
          return TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(agreement: agreement, idirId: idirId),
              _InitiativesTab(
                idirId: idirId,
                agreementId: widget.agreementId,
                isChairperson: isChairperson,
              ),
              _AnnouncementsTab(
                idirId: idirId,
                agreementId: widget.agreementId,
                isChairperson: isChairperson,
              ),
              _EmergenciesTab(
                idirId: idirId,
                agreementId: widget.agreementId,
                isChairperson: isChairperson,
              ),
              _FinancialTab(
                idirId: idirId,
                agreementId: widget.agreementId,
                isChairperson: isChairperson,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.agreement, required this.idirId});
  final CooperationAgreement agreement;
  final String idirId;

  Color _statusColor(CooperationStatus s) => switch (s) {
        CooperationStatus.active => AppColors.success,
        CooperationStatus.pending => Colors.amber.shade700,
        CooperationStatus.rejected => AppColors.error,
        CooperationStatus.completed || CooperationStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final partnerName = agreement.idirAId == idirId ? agreement.idirBName : agreement.idirAName;
    final statusColor = _statusColor(agreement.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Partner Idir', style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(partnerName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Chip(
                    label: Text(agreement.status.label),
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Purpose', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(agreement.purpose, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Text('Description', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(agreement.description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Timeline', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  if (agreement.proposedDuration != null)
                    _InfoRow('Duration', '${agreement.proposedDuration} months'),
                  if (agreement.startDate != null)
                    _InfoRow('Start Date', _formatDate(agreement.startDate!)),
                  if (agreement.endDate != null)
                    _InfoRow('End Date', _formatDate(agreement.endDate!)),
                  _InfoRow('Proposed', _formatDate(agreement.createdAt)),
                  if (agreement.endReason != null) ...[
                    const SizedBox(height: 8),
                    Text('End Reason', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(agreement.endReason!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          if (agreement.participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Participants', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    ...agreement.participants.map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.group_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(p.idirName, style: Theme.of(context).textTheme.bodyMedium),
                              ),
                              Chip(
                                label: Text(p.status.label, style: const TextStyle(fontSize: 10)),
                                backgroundColor: _statusColor(p.status).withValues(alpha: 0.12),
                                labelStyle: TextStyle(color: _statusColor(p.status)),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Initiatives Tab ───────────────────────────────────────────────────────────

class _InitiativesTab extends ConsumerWidget {
  const _InitiativesTab({
    required this.idirId,
    required this.agreementId,
    required this.isChairperson,
  });

  final String idirId;
  final String agreementId;
  final bool isChairperson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initiativesAsync = ref.watch(initiativeListProvider((idirId, agreementId)));

    return Scaffold(
      body: initiativesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(initiativeListProvider((idirId, agreementId))),
        ),
        data: (initiatives) {
          if (initiatives.isEmpty) {
            return _EmptyState(
              icon: Icons.lightbulb_outline,
              message: 'No initiatives yet',
              hint: isChairperson ? 'Tap + to create an initiative' : null,
            );
          }
          return ListView.builder(
            itemCount: initiatives.length,
            itemBuilder: (context, i) {
              final initiative = initiatives[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1A1D4ED8),
                    child: Icon(Icons.lightbulb_outline, color: AppColors.primary),
                  ),
                  title: Text(initiative.title, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text(initiative.category.label,
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: Chip(
                    label: Text(initiative.status.label),
                    backgroundColor: _initiativeStatusColor(initiative.status).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _initiativeStatusColor(initiative.status),
                      fontSize: 11,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onTap: () => context.push('/cooperation/$agreementId/initiatives/${initiative.id}',
                      extra: idirId),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isChairperson
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateInitiativeDialog(
                  idirId: idirId,
                  agreementId: agreementId,
                  onCreated: () => ref.invalidate(initiativeListProvider((idirId, agreementId))),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Color _initiativeStatusColor(InitiativeStatus s) => switch (s) {
        InitiativeStatus.active => AppColors.success,
        InitiativeStatus.draft => Colors.amber.shade700,
        InitiativeStatus.completed => AppColors.primary,
        InitiativeStatus.cancelled => Colors.grey,
      };
}

// ── Announcements Tab ─────────────────────────────────────────────────────────

class _AnnouncementsTab extends ConsumerWidget {
  const _AnnouncementsTab({
    required this.idirId,
    required this.agreementId,
    required this.isChairperson,
  });

  final String idirId;
  final String agreementId;
  final bool isChairperson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementListProvider((idirId, agreementId)));

    return Scaffold(
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(announcementListProvider((idirId, agreementId))),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return _EmptyState(
              icon: Icons.campaign_outlined,
              message: 'No cross-Idir announcements',
              hint: isChairperson ? 'Tap + to create one' : null,
            );
          }
          return ListView.builder(
            itemCount: announcements.length,
            itemBuilder: (context, i) {
              final a = announcements[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: a.isWithdrawn
                        ? Colors.grey.withValues(alpha: 0.1)
                        : const Color(0x1A1D4ED8),
                    child: Icon(Icons.campaign_outlined,
                        color: a.isWithdrawn ? Colors.grey : AppColors.primary),
                  ),
                  title: Text(
                    a.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          decoration: a.isWithdrawn ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.publisherIdirName, style: Theme.of(context).textTheme.bodySmall),
                      Text(a.category.label, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  trailing: isChairperson && !a.isWithdrawn
                      ? IconButton(
                          icon: const Icon(Icons.unpublished_outlined, color: AppColors.error),
                          tooltip: 'Withdraw',
                          onPressed: () async {
                            await ref
                                .read(cooperationActionProvider.notifier)
                                .withdrawAnnouncement(idirId, agreementId, a.id);
                            ref.invalidate(announcementListProvider((idirId, agreementId)));
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isChairperson
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateAnnouncementDialog(
                  idirId: idirId,
                  agreementId: agreementId,
                  onCreated: () => ref.invalidate(announcementListProvider((idirId, agreementId))),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Emergencies Tab ───────────────────────────────────────────────────────────

class _EmergenciesTab extends ConsumerWidget {
  const _EmergenciesTab({
    required this.idirId,
    required this.agreementId,
    required this.isChairperson,
  });

  final String idirId;
  final String agreementId;
  final bool isChairperson;

  Color _urgencyColor(EmergencyUrgency u) => switch (u) {
        EmergencyUrgency.critical => AppColors.error,
        EmergencyUrgency.high => Colors.orange,
        EmergencyUrgency.medium => Colors.amber.shade700,
        EmergencyUrgency.low => AppColors.success,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergenciesAsync = ref.watch(emergencyListProvider((idirId, agreementId)));

    return Scaffold(
      body: emergenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(emergencyListProvider((idirId, agreementId))),
        ),
        data: (emergencies) {
          if (emergencies.isEmpty) {
            return _EmptyState(
              icon: Icons.local_fire_department_outlined,
              message: 'No emergencies reported',
              hint: isChairperson ? 'Tap + to report an emergency' : null,
            );
          }
          return ListView.builder(
            itemCount: emergencies.length,
            itemBuilder: (context, i) {
              final e = emergencies[i];
              final urgencyColor = _urgencyColor(e.urgency);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: urgencyColor.withValues(alpha: 0.15),
                    child: Icon(Icons.local_fire_department_outlined, color: urgencyColor),
                  ),
                  title: Text(e.title, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text(e.requestingIdirName, style: Theme.of(context).textTheme.bodySmall),
                  trailing: Chip(
                    label: Text(e.urgency.label),
                    backgroundColor: urgencyColor.withValues(alpha: 0.12),
                    labelStyle: TextStyle(color: urgencyColor, fontSize: 11),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onTap: () => context.push(
                    '/cooperation/$agreementId/emergencies/${e.id}',
                    extra: idirId,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isChairperson
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateEmergencyDialog(
                  idirId: idirId,
                  agreementId: agreementId,
                  onCreated: () => ref.invalidate(emergencyListProvider((idirId, agreementId))),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Financial Tab ─────────────────────────────────────────────────────────────

class _FinancialTab extends ConsumerWidget {
  const _FinancialTab({
    required this.idirId,
    required this.agreementId,
    required this.isChairperson,
  });

  final String idirId;
  final String agreementId;
  final bool isChairperson;

  Color _commitmentStatusColor(CommitmentStatus s) => switch (s) {
        CommitmentStatus.confirmed => AppColors.success,
        CommitmentStatus.authorized => AppColors.primary,
        CommitmentStatus.pending => Colors.amber.shade700,
        CommitmentStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commitmentsAsync = ref.watch(financialCommitmentListProvider((idirId, agreementId)));

    return Scaffold(
      body: commitmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(financialCommitmentListProvider((idirId, agreementId))),
        ),
        data: (commitments) {
          if (commitments.isEmpty) {
            return _EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: 'No financial commitments',
              hint: isChairperson ? 'Tap + to add a commitment' : null,
            );
          }
          return ListView.builder(
            itemCount: commitments.length,
            itemBuilder: (context, i) {
              final c = commitments[i];
              final statusColor = _commitmentStatusColor(c.status);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(Icons.account_balance_wallet_outlined, color: statusColor),
                  ),
                  title: Text(c.purpose, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.contributingIdirName, style: Theme.of(context).textTheme.bodySmall),
                      Text('${c.currency} ${c.amountCommitted.toStringAsFixed(2)} committed',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text(c.status.label),
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: statusColor, fontSize: 10),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isChairperson
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateFinancialCommitmentDialog(
                  idirId: idirId,
                  agreementId: agreementId,
                  onCreated: () => ref.invalidate(financialCommitmentListProvider((idirId, agreementId))),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.hint});
  final IconData icon;
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
