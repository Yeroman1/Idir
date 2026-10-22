import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/models/election_model.dart';
import '../providers/elections_provider.dart';

class ElectionsDashboardScreen extends ConsumerWidget {
  const ElectionsDashboardScreen({super.key, this.idirId = 'active-idir-id'});

  final String idirId;

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'VOTING':
        return Colors.green;
      case 'NOMINATING':
        return Colors.blue;
      case 'TALLYING':
      case 'DISPUTED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.purple;
      case 'CANCELLED':
        return Colors.red;
      case 'DRAFT':
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;
    final canCreate = user?.role.canManageElections ?? true;
    final electionsAsync = ref.watch(electionsListProvider(idirId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leadership Elections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(electionsListProvider(idirId)),
          ),
        ],
      ),
      body: electionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Error loading elections: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(electionsListProvider(idirId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (elections) {
          if (elections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.how_to_vote_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Elections Scheduled',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Elections for Chairperson, Treasurer, and executive committee roles will appear here once setup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (canCreate) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.createElection),
                        icon: const Icon(Icons.add),
                        label: const Text('Setup New Election'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: elections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final election = elections[index];
              final statusColor = _getStatusColor(election.status);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              election.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              election.status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (election.description != null && election.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          election.description!,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: election.roles.map((r) {
                          return Chip(
                            label: Text(r, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.how_to_vote, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${election.ballotType} · ${election.votingMethod.replaceAll('_', ' ')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          Text(
                            'Quorum: ${election.quorumPercentage.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.createElection),
              icon: const Icon(Icons.add),
              label: const Text('New Election'),
            )
          : null,
    );
  }
}
