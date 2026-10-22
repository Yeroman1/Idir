import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../domain/models/election_model.dart';
import '../../domain/models/election_results_model.dart';
import '../providers/elections_provider.dart';

class ElectionResultsScreen extends ConsumerStatefulWidget {
  const ElectionResultsScreen({
    super.key,
    required this.idirId,
    required this.election,
  });

  final String idirId;
  final ElectionModel election;

  @override
  ConsumerState<ElectionResultsScreen> createState() => _ElectionResultsScreenState();
}

class _ElectionResultsScreenState extends ConsumerState<ElectionResultsScreen> {
  final _disputeReasonController = TextEditingController();
  final _resolutionController = TextEditingController();

  @override
  void dispose() {
    _disputeReasonController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  void _showFileDisputeDialog() {
    _disputeReasonController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.report_problem_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('File Election Dispute'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit a formal complaint to the neutral Election Committee. Your dispute must contain specific factual evidence or concerns.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _disputeReasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe the grounds for dispute (minimum 10 characters)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              final reason = _disputeReasonController.text.trim();
              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dispute reason must be at least 10 characters')),
                );
                return;
              }

              Navigator.of(ctx).pop();

              final success = await ref
                  .read(resultsActionProvider.notifier)
                  .fileDispute(
                    idirId: widget.idirId,
                    electionId: widget.election.id,
                    reason: reason,
                  );

              if (!mounted) return;

              if (success) {
                ref.invalidate(electionResultsProvider(ResultsQueryArgs(
                  idirId: widget.idirId,
                  electionId: widget.election.id,
                )));
                ref.invalidate(electionDisputesProvider(ResultsQueryArgs(
                  idirId: widget.idirId,
                  electionId: widget.election.id,
                )));

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dispute filed successfully and submitted to committee.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                final err = ref.read(resultsActionProvider).errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Failed to file dispute'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Submit Dispute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResolveDisputeDialog(BuildContext context, ElectionDisputeModel dispute) {
    _resolutionController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review & Adjudicate Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filer: ${dispute.filerName ?? 'Idir Member'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Complaint: ${dispute.reason}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: _resolutionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter formal committee resolution / findings...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              final resolution = _resolutionController.text.trim();
              if (resolution.isEmpty) return;

              Navigator.of(ctx).pop();
              await _adjudicateDispute('DISMISS', dispute.id, resolution);
            },
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final resolution = _resolutionController.text.trim();
              if (resolution.isEmpty) return;

              Navigator.of(ctx).pop();
              await _adjudicateDispute('RESOLVE', dispute.id, resolution);
            },
            child: const Text('Resolve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _adjudicateDispute(String action, String disputeId, String resolution) async {
    final success = await ref
        .read(resultsActionProvider.notifier)
        .resolveDispute(
          idirId: widget.idirId,
          electionId: widget.election.id,
          disputeId: disputeId,
          action: action,
          resolution: resolution,
        );

    if (!mounted) return;

    if (success) {
      ref.invalidate(electionResultsProvider(ResultsQueryArgs(
        idirId: widget.idirId,
        electionId: widget.election.id,
      )));
      ref.invalidate(electionDisputesProvider(ResultsQueryArgs(
        idirId: widget.idirId,
        electionId: widget.election.id,
      )));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispute marked as $action!'), backgroundColor: Colors.green),
      );
    } else {
      final err = ref.read(resultsActionProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Failed to update dispute'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCertifyDialog(ElectionResultsModel results) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.verified, color: Colors.purple, size: 48),
        title: const Text('Certify Election & Transfer Leadership'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Official Certification Constitution Notice:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upon certification, leadership roles will be permanently updated in the Idir registry. Previous officers for contested roles will be retired to regular members.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...results.roles.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${r.role}: ${r.winnerName ?? 'Elected Winner'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            onPressed: () async {
              Navigator.of(ctx).pop();

              final success = await ref
                  .read(resultsActionProvider.notifier)
                  .certifyElection(
                    idirId: widget.idirId,
                    electionId: widget.election.id,
                  );

              if (!mounted) return;

              if (success) {
                ref.invalidate(electionResultsProvider(ResultsQueryArgs(
                  idirId: widget.idirId,
                  electionId: widget.election.id,
                )));

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Election certified! Leadership roles have been transferred.'),
                    backgroundColor: Colors.purple,
                  ),
                );
              } else {
                final err = ref.read(resultsActionProvider).errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Failed to certify election'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm Certification', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTriggerRunoffDialog(String role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Trigger Run-Off for $role'),
        content: Text(
          'A tie was detected for the position of $role. Initiating a run-off will clear previous ballots for this role and reopen voting for 48 hours for the tied candidates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              Navigator.of(ctx).pop();

              final success = await ref
                  .read(resultsActionProvider.notifier)
                  .triggerRunoff(
                    idirId: widget.idirId,
                    electionId: widget.election.id,
                    role: role,
                  );

              if (!mounted) return;

              if (success) {
                ref.invalidate(electionResultsProvider(ResultsQueryArgs(
                  idirId: widget.idirId,
                  electionId: widget.election.id,
                )));

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Run-off election initiated for $role!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                final err = ref.read(resultsActionProvider).errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Failed to trigger run-off'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Start Run-Off', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;
    final isOfficerOrCommittee = user?.role.canManageElections ?? true;

    final queryArgs = ResultsQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
    );

    final resultsAsync = ref.watch(electionResultsProvider(queryArgs));
    final disputesAsync = ref.watch(electionDisputesProvider(queryArgs));
    final isActionLoading = ref.watch(resultsActionProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Election Results & Disputes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Results',
            onPressed: () {
              ref.invalidate(electionResultsProvider(queryArgs));
              ref.invalidate(electionDisputesProvider(queryArgs));
            },
          ),
        ],
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load results: $err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(electionResultsProvider(queryArgs)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (results) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Card
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
                            Expanded(
                              child: Text(
                                results.electionTitle,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: results.isCertified
                                    ? Colors.purple.shade100
                                    : (results.quorumReached ? Colors.green.shade100 : Colors.red.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                results.isCertified
                                    ? 'CERTIFIED'
                                    : (results.quorumReached ? results.status : 'QUORUM FAILED'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: results.isCertified
                                      ? Colors.purple.shade900
                                      : (results.quorumReached ? Colors.green.shade900 : Colors.red.shade900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Method: ${results.votingMethod.replaceAll('_', ' ')} · Ballot: ${results.ballotType}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quorum Status Card
                _buildQuorumCard(context, results),
                const SizedBox(height: 16),

                // Dispute Window Banner
                _buildDisputeWindowBanner(context, results),
                const SizedBox(height: 16),

                // Per-Role Results
                Text(
                  'Contested Roles & Ballots',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (results.roles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.how_to_vote, size: 36, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('No votes have been tallied yet.'),
                            if (isOfficerOrCommittee) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: isActionLoading
                                    ? null
                                    : () async {
                                        await ref
                                            .read(resultsActionProvider.notifier)
                                            .tallyVotes(
                                              idirId: widget.idirId,
                                              electionId: widget.election.id,
                                              force: true,
                                            );
                                        ref.invalidate(electionResultsProvider(queryArgs));
                                      },
                                  icon: const Icon(Icons.calculate),
                                  label: const Text('Tally Votes Now'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...results.roles.map((r) => _buildRoleCard(context, r, isOfficerOrCommittee)),

                const SizedBox(height: 16),

                // Disputes Section
                _buildDisputesSection(context, disputesAsync, isOfficerOrCommittee),

                const SizedBox(height: 24),

                // Certification Button
                if (isOfficerOrCommittee && !results.isCertified) ...[
                  Card(
                    color: results.canCertify ? Colors.purple.shade50 : Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: results.canCertify ? Colors.purple.shade300 : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                results.canCertify ? Icons.verified : Icons.lock_outline,
                                color: results.canCertify ? Colors.purple : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                results.canCertify
                                    ? 'Ready for Official Certification'
                                    : 'Certification Pending Requirements',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: results.canCertify ? Colors.purple.shade900 : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            results.canCertify
                                ? 'Quorum is met, all roles have clear winners, and no open disputes exist. Certifying will officially transfer leadership roles.'
                                : 'All roles must have clear winners, quorum must be met, and all disputes must be resolved before leadership roles can transfer.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: (results.canCertify && !isActionLoading)
                                ? () => _showCertifyDialog(results)
                                : null,
                            icon: const Icon(Icons.how_to_reg, size: 20),
                            label: const Text(
                              'Certify Results & Handover Leadership Roles',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (results.isCertified) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Certified Official Leadership Handover Complete',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Leadership roles have taken full institutional effect.',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuorumCard(BuildContext context, ElectionResultsModel results) {
    final reached = results.quorumReached;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: reached ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: reached ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.shield_outlined : Icons.warning_amber_rounded,
                color: reached ? Colors.green.shade800 : Colors.red.shade800,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reached ? 'Quorum Verified & Met' : 'Quorum Not Met (Election Invalid)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: reached ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Voter Turnout: ${results.turnoutPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Required Quorum: ${results.quorumPercentage.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (results.turnoutPercentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade300,
              color: reached ? Colors.green : Colors.red,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${results.uniqueVotersCount} unique votes cast out of ${results.totalEligibleMembers} eligible active members.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeWindowBanner(BuildContext context, ElectionResultsModel results) {
    if (results.isCertified) return const SizedBox.shrink();

    final isOpen = results.isDisputeWindowOpen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOpen ? Colors.orange.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOpen ? Colors.orange.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: isOpen ? Colors.orange.shade800 : Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen
                    ? 'Dispute Window Active (${results.hoursRemaining.toStringAsFixed(1)}h remaining)'
                    : 'Dispute Window Closed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOpen ? Colors.orange.shade900 : Colors.grey.shade800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isOpen
                      ? 'Preliminary results are published. Members may file objections.'
                      : 'Dispute filing period has elapsed.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (isOpen)
            TextButton.icon(
              onPressed: () => _showFileDisputeDialog(),
              icon: const Icon(Icons.add_comment_outlined, size: 16),
              label: const Text('File Dispute', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, RoleResultModel role, bool isOfficer) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  role.role,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${role.totalVotesCast} total votes',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(height: 16),

            // Winner badge or Tie Banner
            if (role.isTie) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.balance, color: Colors.orange, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tie detected! Run-off or tie-breaker required.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                      ),
                    ),
                    if (isOfficer)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: () => _showTriggerRunoffDialog(role.role),
                        child: const Text('Run-Off', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else if (role.hasWinner) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Elected Winner', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          Text(
                            role.winnerName ?? 'Candidate',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${role.votesReceived} votes',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Candidate progress bars
            ...role.candidates.map((c) {
              final isTop = !role.isTie && c.nominationId == role.winnerNominationId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c.nomineeName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          '${c.votes} votes (${c.percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                            color: isTop ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (c.percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isTop ? Colors.green : Colors.blue.shade400,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputesSection(
    BuildContext context,
    AsyncValue<List<ElectionDisputeModel>> disputesAsync,
    bool isOfficer,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Election Disputes & Objections',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        disputesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          error: (err, _) => Text('Failed to load disputes: $err', style: const TextStyle(color: Colors.red)),
          data: (disputes) {
            if (disputes.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No election disputes have been filed.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: disputes.map((d) {
                Color chipColor;
                switch (d.status) {
                  case 'RESOLVED':
                    chipColor = Colors.green;
                    break;
                  case 'DISMISSED':
                    chipColor = Colors.grey;
                    break;
                  case 'PENDING':
                  default:
                    chipColor = Colors.orange;
                    break;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              d.filerName ?? 'Idir Member',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                d.status,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chipColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(d.reason, style: const TextStyle(fontSize: 12)),
                        if (d.resolution != null && d.resolution!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Resolution: ${d.resolution!}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        if (isOfficer && d.isPending) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _showResolveDisputeDialog(context, d),
                              icon: const Icon(Icons.gavel, size: 14),
                              label: const Text('Adjudicate', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
