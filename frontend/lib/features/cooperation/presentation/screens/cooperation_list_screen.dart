import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:idir_app/core/models/app_user.dart';
import 'package:idir_app/core/router/app_router.dart';
import 'package:idir_app/core/theme/app_theme.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/cooperation/domain/models/cooperation_models.dart';
import 'package:idir_app/features/cooperation/presentation/providers/cooperation_provider.dart';

class CooperationListScreen extends ConsumerStatefulWidget {
  const CooperationListScreen({super.key});

  @override
  ConsumerState<CooperationListScreen> createState() => _CooperationListScreenState();
}

class _CooperationListScreenState extends ConsumerState<CooperationListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final idirId = _getIdirId();
    final isChairperson = user?.role == UserRole.chairperson;
    final cooperationsAsync = ref.watch(cooperationListProvider(idirId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Idir Cooperation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: isChairperson
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.proposeCooperation),
              icon: const Icon(Icons.add),
              label: const Text('Propose'),
            )
          : null,
      body: cooperationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(cooperationListProvider(idirId)),
        ),
        data: (cooperations) {
          return TabBarView(
            controller: _tabController,
            children: [
              _CooperationTabList(
                cooperations: cooperations,
                idirId: idirId,
                isChairperson: isChairperson,
              ),
              _CooperationTabList(
                cooperations: cooperations
                    .where((c) => c.status == CooperationStatus.active)
                    .toList(),
                idirId: idirId,
                isChairperson: isChairperson,
              ),
              _CooperationTabList(
                cooperations: cooperations
                    .where((c) => c.status == CooperationStatus.pending)
                    .toList(),
                idirId: idirId,
                isChairperson: isChairperson,
              ),
              _CooperationTabList(
                cooperations: cooperations
                    .where((c) =>
                        c.status == CooperationStatus.completed ||
                        c.status == CooperationStatus.cancelled ||
                        c.status == CooperationStatus.rejected)
                    .toList(),
                idirId: idirId,
                isChairperson: isChairperson,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CooperationTabList extends StatelessWidget {
  const _CooperationTabList({
    required this.cooperations,
    required this.idirId,
    required this.isChairperson,
  });

  final List<CooperationAgreement> cooperations;
  final String idirId;
  final bool isChairperson;

  @override
  Widget build(BuildContext context) {
    if (cooperations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No cooperation agreements yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isChairperson) ...[
              const SizedBox(height: 8),
              Text(
                'Tap the + button to propose one',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cooperations.length,
      itemBuilder: (context, index) {
        final c = cooperations[index];
        return _CooperationCard(agreement: c, idirId: idirId);
      },
    );
  }
}

class _CooperationCard extends StatelessWidget {
  const _CooperationCard({required this.agreement, required this.idirId});

  final CooperationAgreement agreement;
  final String idirId;

  Color _statusColor(CooperationStatus status) => switch (status) {
        CooperationStatus.active => AppColors.success,
        CooperationStatus.pending => Colors.amber.shade700,
        CooperationStatus.rejected => AppColors.error,
        CooperationStatus.completed => Colors.grey,
        CooperationStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final partnerName = agreement.idirAId == idirId ? agreement.idirBName : agreement.idirAName;
    final statusColor = _statusColor(agreement.status);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.handshake_outlined, color: AppColors.primary),
        ),
        title: Text(
          partnerName.isNotEmpty ? partnerName : 'Cooperation Agreement',
          style: Theme.of(context).textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              agreement.purpose,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(agreement.status.label),
              backgroundColor: statusColor.withValues(alpha: 0.15),
              labelStyle: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          '/cooperation/${agreement.id}',
          extra: idirId,
        ),
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
            Text(
              'Failed to load cooperations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
