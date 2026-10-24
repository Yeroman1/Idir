import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/nomination_model.dart';
import '../providers/elections_provider.dart';

class CandidateProfileScreen extends ConsumerStatefulWidget {
  const CandidateProfileScreen({
    super.key,
    required this.idirId,
    required this.electionId,
    required this.nominationId,
    this.initialNomination,
  });

  final String idirId;
  final String electionId;
  final String nominationId;
  final NominationModel? initialNomination;

  @override
  ConsumerState<CandidateProfileScreen> createState() =>
      _CandidateProfileScreenState();
}

class _CandidateProfileScreenState
    extends ConsumerState<CandidateProfileScreen> {
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'DECLINED':
      case 'WITHDRAWN':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showEditStatementDialog(BuildContext context, NominationModel nomination) {
    final controller = TextEditingController(text: nomination.statement ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Candidate Statement'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share your vision, platform, and commitment to the Idir community. (Max 2,000 characters)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Candidate Statement',
                  hintText: 'Enter your statement here...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Statement must be at least 5 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref
                    .read(nominationActionProvider.notifier)
                    .updateStatement(
                      idirId: widget.idirId,
                      electionId: widget.electionId,
                      nominationId: widget.nominationId,
                      statement: controller.text.trim(),
                    );
                nav.pop();
                if (success) {
                  ref.invalidate(candidatePageProvider(CandidatePageQueryArgs(
                    idirId: widget.idirId,
                    electionId: widget.electionId,
                    nominationId: widget.nominationId,
                  )));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Statement updated successfully')),
                  );
                } else {
                  final err = ref.read(nominationActionProvider).errorMessage;
                  messenger.showSnackBar(
                    SnackBar(content: Text(err ?? 'Failed to update statement')),
                  );
                }
              }
            },
            child: const Text('Save Statement'),
          ),
        ],
      ),
    );
  }

  void _confirmWithdrawal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Candidacy?'),
        content: const Text(
          'Are you sure you want to withdraw your candidacy? Your name will be removed from the election ballot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await ref
                  .read(nominationActionProvider.notifier)
                  .withdrawNomination(
                    idirId: widget.idirId,
                    electionId: widget.electionId,
                    nominationId: widget.nominationId,
                  );
              nav.pop();
              if (success) {
                ref.invalidate(candidatePageProvider(CandidatePageQueryArgs(
                  idirId: widget.idirId,
                  electionId: widget.electionId,
                  nominationId: widget.nominationId,
                )));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Candidacy withdrawn')),
                );
              } else {
                final err = ref.read(nominationActionProvider).errorMessage;
                messenger.showSnackBar(
                  SnackBar(content: Text(err ?? 'Failed to withdraw')),
                );
              }
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;

    final queryArgs = CandidatePageQueryArgs(
      idirId: widget.idirId,
      electionId: widget.electionId,
      nominationId: widget.nominationId,
    );

    final candidateAsync = ref.watch(candidatePageProvider(queryArgs));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidate Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(candidatePageProvider(queryArgs)),
          ),
        ],
      ),
      body: candidateAsync.when(
        loading: () => widget.initialNomination != null
            ? _buildContent(
                widget.initialNomination!,
                user?.memberId.isNotEmpty == true ? user!.memberId : user?.uid,
                theme,
              )
            : const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error loading candidate profile: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(candidatePageProvider(queryArgs)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (nomination) => _buildContent(
          nomination,
          user?.memberId.isNotEmpty == true ? user!.memberId : user?.uid,
          theme,
        ),
      ),
    );
  }

  Widget _buildContent(NominationModel nomination, String? currentUserId, ThemeData theme) {
    final statusColor = _getStatusColor(nomination.status);
    final isCandidate = currentUserId != null &&
        (nomination.nomineeMembershipId == currentUserId ||
         nomination.nomineeName == currentUserId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card with Avatar and Basic Info
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      (nomination.nomineeName != null && nomination.nomineeName!.isNotEmpty)
                          ? nomination.nomineeName![0].toUpperCase()
                          : 'C',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    nomination.nomineeName ?? 'Candidate',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      nomination.role,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      nomination.isAccepted ? 'BALLOT CANDIDATE' : nomination.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Short Statement Card
          Card(
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
                      Row(
                        children: [
                          Icon(Icons.format_quote, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Candidate Statement',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (isCandidate && nomination.isAccepted)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit Statement',
                          onPressed: () => _showEditStatementDialog(context, nomination),
                        ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    (nomination.statement != null && nomination.statement!.trim().isNotEmpty)
                        ? nomination.statement!
                        : 'No candidate statement has been submitted yet.',
                    style: TextStyle(
                      fontStyle: (nomination.statement == null || nomination.statement!.isEmpty)
                          ? FontStyle.italic
                          : FontStyle.normal,
                      fontSize: 14,
                      height: 1.4,
                      color: (nomination.statement == null || nomination.statement!.isEmpty)
                          ? Colors.grey.shade600
                          : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nomination Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nomination Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Nominated By',
                    nomination.isSelfNomination
                        ? 'Self-Nomination'
                        : (nomination.nominatedByName ?? 'Fellow Member'),
                  ),
                  if (nomination.nomineeMemberNumber != null)
                    _buildDetailRow('Member Number', nomination.nomineeMemberNumber!),
                  if (nomination.acceptedAt != null)
                    _buildDetailRow(
                      'Accepted Date',
                      nomination.acceptedAt!.toLocal().toString().split(' ')[0],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Candidate Actions (Withdraw / Edit)
          if (isCandidate && nomination.isAccepted) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _confirmWithdrawal(context),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Withdraw from Election'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
