import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../domain/models/leadership_events_model.dart';
import '../providers/elections_provider.dart';

class LeadershipEventsScreen extends ConsumerStatefulWidget {
  const LeadershipEventsScreen({
    super.key,
    required this.idirId,
  });

  final String idirId;

  @override
  ConsumerState<LeadershipEventsScreen> createState() => _LeadershipEventsScreenState();
}

class _LeadershipEventsScreenState extends ConsumerState<LeadershipEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers
  final _reasonController = TextEditingController();
  final _thresholdController = TextEditingController(text: '66.7');
  final _quorumController = TextEditingController(text: '50.0');
  final _durationDaysController = TextEditingController(text: '7');
  final _appointeeIdController = TextEditingController();
  final _interimReasonController = TextEditingController();
  final _termMonthsController = TextEditingController(text: '6');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    _thresholdController.dispose();
    _quorumController.dispose();
    _durationDaysController.dispose();
    _appointeeIdController.dispose();
    _interimReasonController.dispose();
    _termMonthsController.dispose();
    super.dispose();
  }

  IconData _getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'CHAIRPERSON':
        return Icons.account_balance;
      case 'TREASURER':
        return Icons.account_balance_wallet;
      case 'SECRETARY':
        return Icons.edit_note;
      case 'AUDITOR':
        return Icons.fact_check;
      default:
        return Icons.person;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OCCUPIED':
        return Colors.green;
      case 'INTERIM':
        return Colors.orange;
      case 'VACANT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showInitiateNoConfidenceDialog(String targetRole, String? targetMembershipId, String? officerName) {
    if (targetMembershipId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot initiate no-confidence on a vacant role')),
      );
      return;
    }

    _reasonController.clear();
    double selectedThreshold = 66.7;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text('Motion of No-Confidence: $targetRole', style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Initiating a formal vote to vacate the leadership seat held by ${officerName ?? 'Sitting Officer'}.',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text('Required Threshold to Remove:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<double>(
                  initialValue: selectedThreshold,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 66.7, child: Text('Two-Thirds Supermajority (66.7%)')),
                    DropdownMenuItem(value: 50.0, child: Text('Simple Majority (50.0%)')),
                    DropdownMenuItem(value: 75.0, child: Text('Three-Fourths Majority (75.0%)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedThreshold = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Grounds & Evidence (min 10 characters):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe reasons (e.g. governance breach, lack of audits)...',
                    border: OutlineInputBorder(),
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final reason = _reasonController.text.trim();
                if (reason.length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grounds must be at least 10 characters')),
                  );
                  return;
                }

                Navigator.of(ctx).pop();

                final scaffold = ScaffoldMessenger.of(context);
                final success = await ref
                    .read(leadershipEventsActionProvider.notifier)
                    .initiateNoConfidence(
                      idirId: widget.idirId,
                      targetMembershipId: targetMembershipId,
                      targetRole: targetRole,
                      reason: reason,
                      thresholdPercentage: selectedThreshold,
                    );

                if (!mounted) return;

                if (success) {
                  ref.invalidate(leadershipVacanciesProvider(widget.idirId));
                  ref.invalidate(noConfidenceVotesProvider(widget.idirId));
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('No-confidence motion initiated for $targetRole!'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                } else {
                  final err = ref.read(leadershipEventsActionProvider).errorMessage;
                  scaffold.showSnackBar(
                    SnackBar(content: Text(err ?? 'Failed to initiate motion'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Initiate Motion', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointInterimDialog(String vacantRole) {
    _appointeeIdController.clear();
    _interimReasonController.clear();
    int termMonths = 6;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Appoint Interim $vacantRole'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select an active member to serve as temporary interim $vacantRole until a by-election is held.',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                const Text('Appointee Membership UUID:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _appointeeIdController,
                  decoration: const InputDecoration(
                    hintText: 'Enter member UUID...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Interim Term Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: termMonths,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('3 Months')),
                    DropdownMenuItem(value: 6, child: Text('6 Months (Recommended)')),
                    DropdownMenuItem(value: 12, child: Text('12 Months')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => termMonths = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Appointment Rationale:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _interimReasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Emergency interim leadership coverage...',
                    border: OutlineInputBorder(),
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () async {
                final appointeeId = _appointeeIdController.text.trim();
                if (appointeeId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please specify appointee membership ID')),
                  );
                  return;
                }

                Navigator.of(ctx).pop();

                final scaffold = ScaffoldMessenger.of(context);
                final success = await ref
                    .read(leadershipEventsActionProvider.notifier)
                    .appointTemporaryOfficer(
                      idirId: widget.idirId,
                      vacantRole: vacantRole,
                      appointeeMembershipId: appointeeId,
                      reason: _interimReasonController.text.trim(),
                      termMonths: termMonths,
                    );

                if (!mounted) return;

                if (success) {
                  ref.invalidate(leadershipVacanciesProvider(widget.idirId));
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('Interim officer appointed for $vacantRole!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  final err = ref.read(leadershipEventsActionProvider).errorMessage;
                  scaffold.showSnackBar(
                    SnackBar(content: Text(err ?? 'Failed to appoint interim officer'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Appoint Interim', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleByElectionDialog(String vacantRole) {
    final committeeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Schedule By-Election for $vacantRole'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initiates an expedited special election to permanently elect a new $vacantRole.',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            const Text('Committee Member IDs (comma-separated UUIDs):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: committeeController,
              decoration: const InputDecoration(
                hintText: 'e.g. member-uuid-1, member-uuid-2',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            onPressed: () async {
              final raw = committeeController.text.trim();
              final committeeIds = raw
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

              if (committeeIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide at least one committee member ID')),
                );
                return;
              }

              Navigator.of(ctx).pop();

              final now = DateTime.now();
              final endDate = now.add(const Duration(days: 14));

              final success = await ref
                  .read(leadershipEventsActionProvider.notifier)
                  .createByElection(
                    idirId: widget.idirId,
                    vacantRole: vacantRole,
                    startDate: now,
                    endDate: endDate,
                    committeeMemberIds: committeeIds,
                  );

              if (!mounted) return;

              if (success) {
                ref.invalidate(leadershipVacanciesProvider(widget.idirId));
                ref.invalidate(electionsListProvider(widget.idirId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('By-election scheduled for $vacantRole!'),
                    backgroundColor: Colors.purple,
                  ),
                );
              } else {
                final err = ref.read(leadershipEventsActionProvider).errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? 'Failed to schedule by-election'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Schedule By-Election', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isOfficer = user?.role.canManageElections ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leadership Governance & Vacancies'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance), text: 'Vacancies & Roles'),
            Tab(icon: Icon(Icons.how_to_vote), text: 'No-Confidence Votes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVacanciesTab(isOfficer, theme),
          _buildNoConfidenceTab(theme),
        ],
      ),
    );
  }

  Widget _buildVacanciesTab(bool isOfficer, ThemeData theme) {
    final vacanciesAsync = ref.watch(leadershipVacanciesProvider(widget.idirId));

    return vacanciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading vacancies: $err')),
      data: (vacancies) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leadershipVacanciesProvider(widget.idirId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header description
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.blue.shade800, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Institutional bylaws define 4 core leadership roles. If an officer is vacated by no-confidence, resignation, or expiry, interim appointments or by-elections can restore leadership.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ...vacancies.map((vacancy) => _buildVacancyCard(vacancy, isOfficer, theme)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVacancyCard(LeadershipVacancyModel vacancy, bool isOfficer, ThemeData theme) {
    final statusColor = _getStatusColor(vacancy.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(_getRoleIcon(vacancy.role), color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vacancy.role, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        vacancy.isOccupied
                            ? 'Occupied by ${vacancy.holderName ?? 'Officer'}'
                            : (vacancy.isInterim
                                ? 'Interim Coverage: ${vacancy.holderName ?? 'Appointee'}'
                                : 'Role is Currently Vacant'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    vacancy.status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            if (vacancy.isOccupied || vacancy.isInterim) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Member No: ${vacancy.holderMemberNumber ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                  if (vacancy.termEndDate != null)
                    Text('Term ends: ${vacancy.termEndDate!.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade800),
                    onPressed: () => _showInitiateNoConfidenceDialog(
                      vacancy.role,
                      vacancy.holderMembershipId,
                      vacancy.holderName,
                    ),
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('No-Confidence Motion', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ] else ...[
              // Vacant role options
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.report_problem_outlined, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Governance seat requires immediate appointment or by-election to maintain operations.',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (isOfficer)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAppointInterimDialog(vacancy.role),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Temporary Appointment', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                      onPressed: () => _showScheduleByElectionDialog(vacancy.role),
                      icon: const Icon(Icons.how_to_reg, size: 16),
                      label: const Text('Schedule By-Election', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoConfidenceTab(ThemeData theme) {
    final votesAsync = ref.watch(noConfidenceVotesProvider(widget.idirId));
    final actionState = ref.watch(leadershipEventsActionProvider);

    return votesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading votes: $err')),
      data: (votes) {
        if (votes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, size: 64, color: Colors.green.shade400),
                const SizedBox(height: 12),
                const Text('No Active No-Confidence Motions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('All leadership seats are in good standing.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(noConfidenceVotesProvider(widget.idirId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: votes.length,
            itemBuilder: (context, index) {
              final vote = votes[index];
              return _buildNoConfidenceVoteCard(vote, actionState.isLoading, theme);
            },
          ),
        );
      },
    );
  }

  Widget _buildNoConfidenceVoteCard(NoConfidenceVoteModel vote, bool isLoading, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: vote.isActive ? Colors.orange.shade300 : Colors.grey.shade300),
      ),
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
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('No-Confidence: ${vote.targetRole}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: vote.isPassed
                        ? Colors.red.shade100
                        : (vote.isActive ? Colors.orange.shade100 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vote.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: vote.isPassed ? Colors.red.shade900 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Target: ${vote.targetName ?? 'Officer'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Grounds: "${vote.reason}"', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const Divider(height: 18),

            // Progress stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Votes: ${vote.totalVotesCast} / ${vote.totalEligibleMembers} eligible', style: const TextStyle(fontSize: 11)),
                Text('Turnout: ${vote.turnoutPercentage.toStringAsFixed(1)}% (Quorum: ${vote.quorumPercentage}%)',
                    style: TextStyle(fontSize: 11, color: vote.quorumReached ? Colors.green : Colors.red)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: vote.totalEligibleMembers > 0 ? (vote.totalVotesCast / vote.totalEligibleMembers).clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(vote.quorumReached ? Colors.green : Colors.orange),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Support to Remove: ${vote.supportVotes} (${vote.supportPercentage.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                Text('Threshold: ${vote.thresholdPercentage}%', style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 14),

            // Voting action buttons
            if (vote.isActive) ...[
              if (!vote.hasVoted) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final success = await ref
                                    .read(leadershipEventsActionProvider.notifier)
                                    .castNoConfidenceVote(
                                      idirId: widget.idirId,
                                      voteId: vote.id,
                                      choice: 'SUPPORT',
                                    );
                                if (!mounted) return;
                                if (success) {
                                  ref.invalidate(noConfidenceVotesProvider(widget.idirId));
                                }
                              },
                        icon: const Icon(Icons.thumb_down, size: 16, color: Colors.white),
                        label: const Text('Vote to Remove', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final success = await ref
                                    .read(leadershipEventsActionProvider.notifier)
                                    .castNoConfidenceVote(
                                      idirId: widget.idirId,
                                      voteId: vote.id,
                                      choice: 'OPPOSE',
                                    );
                                if (!mounted) return;
                                if (success) {
                                  ref.invalidate(noConfidenceVotesProvider(widget.idirId));
                                }
                              },
                        icon: const Icon(Icons.thumb_up, size: 16, color: Colors.white),
                        label: const Text('Vote to Retain', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text('Your ballot has been securely cast on this motion.', style: TextStyle(fontSize: 12, color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Conclude & Tally button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final success = await ref
                              .read(leadershipEventsActionProvider.notifier)
                              .resolveNoConfidenceVote(
                                idirId: widget.idirId,
                                voteId: vote.id,
                                force: true,
                              );
                          if (!mounted) return;
                          if (success) {
                            ref.invalidate(noConfidenceVotesProvider(widget.idirId));
                            ref.invalidate(leadershipVacanciesProvider(widget.idirId));
                          }
                        },
                  icon: const Icon(Icons.calculate, size: 16),
                  label: const Text('Conclude & Tally Motion', style: TextStyle(fontSize: 11)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: vote.isPassed ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vote.isPassed
                      ? 'Official Outcome: Motion Passed. Officer was removed and role vacated.'
                      : 'Official Outcome: Motion Failed. Officer retained in office.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: vote.isPassed ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
