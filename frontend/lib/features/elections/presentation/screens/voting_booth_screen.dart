import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/election_model.dart';
import '../../domain/models/nomination_model.dart';
import '../../domain/models/vote_receipt_model.dart';
import '../providers/elections_provider.dart';
import 'candidate_profile_screen.dart';

class VotingBoothScreen extends ConsumerStatefulWidget {
  const VotingBoothScreen({
    super.key,
    required this.idirId,
    required this.election,
  });

  final String idirId;
  final ElectionModel election;

  @override
  ConsumerState<VotingBoothScreen> createState() => _VotingBoothScreenState();
}

class _VotingBoothScreenState extends ConsumerState<VotingBoothScreen> {
  final Map<String, String> _selectedCandidatePerRole = {};

  void _showReceiptDialog(BuildContext context, VoteReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Ballot Cast Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your vote for ${receipt.role} has been securely and permanently recorded.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cryptographic Receipt Hash (Proof of Vote):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    receipt.receiptTokenHash ?? receipt.id,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              receipt.isSecret
                  ? '🔒 Anonymity Protected: Stored separately from candidate choices. This receipt proves you voted without disclosing who you voted for.'
                  : '🌐 Open Ballot: Stored according to open election transparency guidelines.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: receipt.receiptTokenHash ?? receipt.id,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt token copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Token'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirmAndCastVote({
    required String role,
    required String candidateNominationId,
    required String candidateName,
    required bool isSecret,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Vote for $role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are casting your ballot for:'),
            const SizedBox(height: 8),
            Text(
              candidateName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSecret ? Colors.teal.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSecret ? Colors.teal.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                isSecret
                    ? '🔒 Secret Ballot: Your choice is decoupled from your identity to ensure absolute voting secrecy. Double-voting is prevented via secure vote receipts.'
                    : '🌐 Open Ballot: Your vote will be recorded as part of the transparent public ballot.',
                style: TextStyle(
                  fontSize: 12,
                  color: isSecret ? Colors.teal.shade900 : Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ This action is final. You may only vote once per role in this election.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.of(ctx).pop();

              final success = await ref
                  .read(votingActionProvider.notifier)
                  .castVote(
                    idirId: widget.idirId,
                    electionId: widget.election.id,
                    role: role,
                    candidateNominationId: candidateNominationId,
                  );

              if (!mounted) return;

              if (success) {
                // Refresh voting status and ballot
                ref.invalidate(votingStatusProvider(VotingQueryArgs(
                  idirId: widget.idirId,
                  electionId: widget.election.id,
                )));

                final receipt = ref.read(votingActionProvider).lastReceipt;
                if (receipt != null) {
                  _showReceiptDialog(context, receipt);
                }
              } else {
                final err = ref.read(votingActionProvider).errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Failed to cast ballot'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm & Vote', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;
    final isFaydaVerified = user?.isFaydaVerified ?? false;

    final votingQuery = VotingQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
    );

    final statusAsync = ref.watch(votingStatusProvider(votingQuery));
    final candidatesAsync = ref.watch(nominationsListProvider(NominationsQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
      ballotOnly: true, // Acceptance criteria: only accepted candidates appear on the ballot
    )));

    final isSecret = widget.election.ballotType.toUpperCase() == 'SECRET';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Official Voting Booth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(votingStatusProvider(votingQuery));
              ref.invalidate(nominationsListProvider(NominationsQueryArgs(
                idirId: widget.idirId,
                electionId: widget.election.id,
                ballotOnly: true,
              )));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Election Header Banner
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.election.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isSecret ? Colors.teal : Colors.blue).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (isSecret ? Colors.teal : Colors.blue).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSecret ? Icons.lock : Icons.public,
                                size: 12,
                                color: isSecret ? Colors.teal : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSecret ? 'SECRET BALLOT' : 'OPEN BALLOT',
                                style: TextStyle(
                                  color: isSecret ? Colors.teal : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSecret
                          ? '🔒 Ballots and vote receipts are stored separately. Your choice is private and mathematically decoupled from your member record.'
                          : '🌐 Open Ballot: Voter names and choices are recorded as part of the public election record.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quorum requirement: ${widget.election.quorumPercentage.toStringAsFixed(0)}% of active members',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Fayda Verification Gate Banner
            if (!isFaydaVerified) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 1.5),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fayda Digital Identity Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'National election standards require verified Fayda Digital ID login before casting a ballot. Voting is currently disabled.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status Progress Bar
            statusAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (status) {
                final total = status.roles.length;
                final voted = status.votedRoles.length;
                final progress = total > 0 ? voted / total : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Ballot Progress',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$voted of $total roles voted',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: voted == total ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Contested Roles Sections
            candidatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading ballot candidates: $err'),
              ),
              data: (candidates) {
                return statusAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (status) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.election.roles.map((role) {
                        final hasVoted = status.hasVotedForRole(role);
                        final receipt = status.getReceiptForRole(role);
                        final candidatesForRole =
                            candidates.where((c) => c.role == role).toList();

                        return _buildRoleSection(
                          context: context,
                          role: role,
                          hasVoted: hasVoted,
                          receipt: receipt,
                          candidates: candidatesForRole,
                          isFaydaVerified: isFaydaVerified,
                          isSecret: isSecret,
                          theme: theme,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSection({
    required BuildContext context,
    required String role,
    required bool hasVoted,
    required VoteReceiptModel? receipt,
    required List<NominationModel> candidates,
    required bool isFaydaVerified,
    required bool isSecret,
    required ThemeData theme,
  }) {
    final selectedCandidateId = _selectedCandidatePerRole[role];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasVoted ? Icons.check_circle : Icons.how_to_vote,
                      color: hasVoted ? Colors.green : theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      role,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hasVoted ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasVoted ? 'VOTE RECORDED' : 'PENDING VOTE',
                    style: TextStyle(
                      color: hasVoted ? Colors.green : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            if (hasVoted) ...[
              // Already voted state with proof of receipt token
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified, size: 18, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          'Your vote is counted and safely stored',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (receipt?.receiptTokenHash != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Verification Hash: ${receipt!.receiptTokenHash!.substring(0, 16)}...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Candidate options to vote
              if (candidates.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No candidates are officially on the ballot for this role yet.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              ] else ...[
                ...candidates.map((c) {
                  final isSelected = selectedCandidateId == c.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: isFaydaVerified
                          ? () {
                              setState(() {
                                _selectedCandidatePerRole[role] = c.id;
                              });
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.nomineeName ?? 'Candidate',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (c.statement != null && c.statement!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      c.statement!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 20),
                              tooltip: 'View Candidate Profile',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CandidateProfileScreen(
                                      idirId: widget.idirId,
                                      electionId: widget.election.id,
                                      nominationId: c.id,
                                      initialNomination: c,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // Cast Vote Button for this role
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: (isFaydaVerified && selectedCandidateId != null)
                      ? () {
                          final selectedCandidate = candidates
                              .firstWhere((c) => c.id == selectedCandidateId);
                          _confirmAndCastVote(
                            role: role,
                            candidateNominationId: selectedCandidateId,
                            candidateName: selectedCandidate.nomineeName ?? 'Selected Candidate',
                            isSecret: isSecret,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.how_to_vote, color: Colors.white, size: 18),
                  label: Text(
                    'Cast Vote for $role',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
