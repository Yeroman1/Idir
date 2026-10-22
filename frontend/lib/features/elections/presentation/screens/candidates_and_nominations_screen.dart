import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/election_model.dart';
import '../../domain/models/nomination_model.dart';
import '../providers/elections_provider.dart';
import 'candidate_profile_screen.dart';

class CandidatesAndNominationsScreen extends ConsumerStatefulWidget {
  const CandidatesAndNominationsScreen({
    super.key,
    required this.idirId,
    required this.election,
  });

  final String idirId;
  final ElectionModel election;

  @override
  ConsumerState<CandidatesAndNominationsScreen> createState() =>
      _CandidatesAndNominationsScreenState();
}

class _CandidatesAndNominationsScreenState
    extends ConsumerState<CandidatesAndNominationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedRoleFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  void _showNominateDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final statementController = TextEditingController();
    final nomineeIdController = TextEditingController();
    bool isSelfNomination = true;
    String selectedRole = widget.election.roles.isNotEmpty
        ? widget.election.roles.first
        : 'CHAIRPERSON';

    final user = ref.read(authNotifierProvider).user;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Nominate Candidate'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Choice: Self vs Other
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Self'),
                            icon: Icon(Icons.person),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Other Member'),
                            icon: Icon(Icons.group),
                          ),
                        ],
                        selected: {isSelfNomination},
                        onSelectionChanged: (val) {
                          setDialogState(() {
                            isSelfNomination = val.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // If other member: membership ID field
                      if (!isSelfNomination) ...[
                        TextFormField(
                          controller: nomineeIdController,
                          decoration: const InputDecoration(
                            labelText: 'Nominee Membership ID *',
                            hintText: 'Enter member UUID or ID',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (!isSelfNomination &&
                                (val == null || val.trim().isEmpty)) {
                              return 'Please enter nominee membership ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Contested Role Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Contested Leadership Role *',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.election.roles.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Short Statement Field
                      TextFormField(
                        controller: statementController,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: isSelfNomination
                              ? 'Your Candidate Statement'
                              : 'Nomination Statement / Endorsement',
                          hintText: isSelfNomination
                              ? 'Explain your vision and goals for this role...'
                              : 'Why is this member the right candidate?',
                          border: const OutlineInputBorder(),
                        ),
                      ),

                      if (isSelfNomination)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'Self-nominations are automatically accepted and placed on the official ballot upon meeting eligibility criteria.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'The nominated member must accept before they appear on the ballot. Unaccepted nominations remain pending.',
                            style: TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                        ),
                    ],
                  ),
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
                      final nomineeId = isSelfNomination
                          ? (user?.memberId.isNotEmpty == true
                              ? user!.memberId
                              : (user?.uid ?? 'current-user-membership-id'))
                          : nomineeIdController.text.trim();

                      final success = await ref
                          .read(nominationActionProvider.notifier)
                          .nominateCandidate(
                            idirId: widget.idirId,
                            electionId: widget.election.id,
                            role: selectedRole,
                            nomineeMembershipId: nomineeId,
                            statement: statementController.text.trim().isNotEmpty
                                ? statementController.text.trim()
                                : null,
                          );

                      nav.pop();

                      if (success) {
                        _refreshLists();
                        final state = ref.read(nominationActionProvider);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              state.successMessage ?? 'Nomination registered!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        final err = ref.read(nominationActionProvider).errorMessage;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(err ?? 'Failed to submit nomination'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Submit Nomination'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAcceptDeclineDialog(
    BuildContext context,
    NominationModel nomination,
    bool isAccepting,
  ) {
    final statementController =
        TextEditingController(text: nomination.statement ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAccepting ? 'Accept Nomination' : 'Decline Nomination'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAccepting
                  ? 'You are accepting the nomination for ${nomination.role}. You will appear on the official election ballot.'
                  : 'Are you sure you want to decline this nomination?',
            ),
            if (isAccepting) ...[
              const SizedBox(height: 12),
              TextField(
                controller: statementController,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Candidate Statement (Optional)',
                  hintText: 'Share your vision for the community...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccepting ? Colors.green : Colors.red,
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await ref
                  .read(nominationActionProvider.notifier)
                  .respondToNomination(
                    idirId: widget.idirId,
                    electionId: widget.election.id,
                    nominationId: nomination.id,
                    action: isAccepting ? 'ACCEPT' : 'DECLINE',
                    statement: isAccepting
                        ? statementController.text.trim()
                        : null,
                  );

              nav.pop();
              if (success) {
                _refreshLists();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      isAccepting
                          ? 'Nomination accepted! You will appear on the ballot.'
                          : 'Nomination declined.',
                    ),
                    backgroundColor: isAccepting ? Colors.green : Colors.grey,
                  ),
                );
              } else {
                final err = ref.read(nominationActionProvider).errorMessage;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Action failed'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              isAccepting ? 'Accept' : 'Decline',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshLists() {
    ref.invalidate(nominationsListProvider(NominationsQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
      ballotOnly: true,
      role: _selectedRoleFilter,
    )));
    ref.invalidate(nominationsListProvider(NominationsQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
      status: 'ALL',
      role: _selectedRoleFilter,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;

    // Check for pending nominations for current user
    final allNominationsAsync = ref.watch(
      nominationsListProvider(NominationsQueryArgs(
        idirId: widget.idirId,
        electionId: widget.election.id,
        status: 'ALL',
      )),
    );

    final pendingForMe = allNominationsAsync.valueOrNull?.where((n) {
      return n.isPending &&
          user != null &&
          (n.nomineeMembershipId == user.memberId ||
              n.nomineeMembershipId == user.uid ||
              n.nomineeName == user.name);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.election.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.how_to_vote), text: 'Official Ballot'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'All Nominations'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLists,
          ),
        ],
      ),
      body: Column(
        children: [
          // If current member has a pending nomination to accept or decline:
          if (pendingForMe != null && pendingForMe.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notification_important, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have been nominated!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You are nominated for ${pendingForMe.first.role} by ${pendingForMe.first.nominatedByName ?? "a fellow member"}. You must accept to appear on the ballot.',
                    style: TextStyle(fontSize: 13, color: Colors.brown.shade800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _showAcceptDeclineDialog(
                          context,
                          pendingForMe.first,
                          false,
                        ),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _showAcceptDeclineDialog(
                          context,
                          pendingForMe.first,
                          true,
                        ),
                        child: const Text('Accept Nomination',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Role Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Roles'),
                  selected: _selectedRoleFilter == null,
                  onSelected: (val) {
                    setState(() {
                      _selectedRoleFilter = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...widget.election.roles.map((r) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r),
                      selected: _selectedRoleFilter == r,
                      onSelected: (val) {
                        setState(() {
                          _selectedRoleFilter = val ? r : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── TAB 1: OFFICIAL BALLOT (Accepted Only) ─────────────────
                _buildBallotTab(theme),

                // ── TAB 2: ALL NOMINATIONS (Pending, Accepted, Declined) ───
                _buildAllNominationsTab(theme),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNominateDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nominate'),
      ),
    );
  }

  Widget _buildBallotTab(ThemeData theme) {
    final ballotQuery = NominationsQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
      ballotOnly: true,
      role: _selectedRoleFilter,
    );

    final ballotAsync = ref.watch(nominationsListProvider(ballotQuery));

    return ballotAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading ballot: $err')),
      data: (candidates) {
        if (candidates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_vote_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No Accepted Candidates Yet',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only accepted nominations appear on the official ballot. Once nominees accept, their candidate profile will display here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: candidates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return _buildCandidateCard(candidate, theme, isBallotView: true);
          },
        );
      },
    );
  }

  Widget _buildAllNominationsTab(ThemeData theme) {
    final allQuery = NominationsQueryArgs(
      idirId: widget.idirId,
      electionId: widget.election.id,
      status: 'ALL',
      role: _selectedRoleFilter,
    );

    final allAsync = ref.watch(nominationsListProvider(allQuery));

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading nominations: $err')),
      data: (nominations) {
        if (nominations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No Nominations Filed',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Members can nominate themselves or fellow active members for open leadership positions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: nominations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final nomination = nominations[index];
            return _buildCandidateCard(nomination, theme, isBallotView: false);
          },
        );
      },
    );
  }

  Widget _buildCandidateCard(
    NominationModel nomination,
    ThemeData theme, {
    required bool isBallotView,
  }) {
    final statusColor = _getStatusColor(nomination.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CandidateProfileScreen(
                idirId: widget.idirId,
                electionId: widget.election.id,
                nominationId: nomination.id,
                initialNomination: nomination,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      (nomination.nomineeName != null && nomination.nomineeName!.isNotEmpty)
                          ? nomination.nomineeName![0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomination.nomineeName ?? 'Candidate',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                nomination.role,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (nomination.nomineeMemberNumber != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '#${nomination.nomineeMemberNumber}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isBallotView) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        nomination.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ],
              ),
              if (nomination.statement != null &&
                  nomination.statement!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          nomination.statement!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                nomination.isSelfNomination
                    ? 'Self-nominated'
                    : 'Nominated by ${nomination.nominatedByName ?? "fellow member"}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
