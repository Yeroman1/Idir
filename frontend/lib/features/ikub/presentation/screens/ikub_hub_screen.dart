import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/ikub_models.dart';
import '../providers/ikub_provider.dart';
import 'create_ikub_screen.dart';
import 'live_lottery_draw_screen.dart';

class IkubHubScreen extends ConsumerStatefulWidget {
  const IkubHubScreen({super.key});

  @override
  ConsumerState<IkubHubScreen> createState() => _IkubHubScreenState();
}

class _IkubHubScreenState extends ConsumerState<IkubHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isJoining = false;

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

  Future<void> _oneClickJoin(IkubGroupModel group, String membershipId) async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Enrolling you into this Ikub pool...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );
      await ref.read(activeIkubProvider.notifier).requestToJoin(membershipId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('🎉 Congratulations! You are now enrolled in the Ikub pool!'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to join Ikub: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _showRecordPaymentSheet(
      IkubGroupModel group, IkubRoundModel round, IkubParticipantModel participant) {
    final amountController =
        TextEditingController(text: group.contributionAmount.toStringAsFixed(0));
    final refController = TextEditingController();
    String method = 'CASH';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Record Round ${round.roundNumber} Contribution',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      participant.fullName ?? 'Participant',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(participant.phoneNumber ?? 'Enrolled Member'),
                    trailing: Text(
                      '${group.contributionAmount.toStringAsFixed(0)} ${group.currency}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (ETB)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'TELEBIRR', child: Text('Telebirr')),
                      DropdownMenuItem(value: 'CBE_BIRR', child: Text('CBE Birr')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => method = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt / Transaction Ref (Optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amt = double.tryParse(amountController.text) ?? 0.0;
                            if (amt <= 0) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final sheetNavigator = Navigator.of(ctx);
                            setSheetState(() => isSaving = true);
                            try {
                              await ref.read(activeIkubProvider.notifier).recordContribution(
                                    roundId: round.id,
                                    participantId: participant.id,
                                    amount: amt,
                                    paymentMethod: method,
                                    paymentReference: refController.text.trim().isNotEmpty
                                        ? refController.text.trim()
                                        : null,
                                  );
                              sheetNavigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Contribution recorded!'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm Contribution'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIdir = ref.watch(currentActiveIdirProvider);
    final user = ref.watch(currentUserProvider);
    final effectiveRole = activeIdir?.role ?? user?.role ?? UserRole.member;
    final ikubAsync = ref.watch(activeIkubProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeIdir != null ? '${activeIdir.idirName} Ikub' : 'Idir Ikub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(activeIkubProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ikubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Failed to load Ikub: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.read(activeIkubProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (group) {
          if (group == null) {
            return _buildNoActiveIkubView(effectiveRole);
          }
          return _buildActiveIkubView(group, effectiveRole, user);
        },
      ),
    );
  }

  Widget _buildNoActiveIkubView(UserRole effectiveRole) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 64,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Ikub Running',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'An Idir can run one active rotating savings group at a time. All members are eligible to opt in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 32),
            if (effectiveRole.isChairperson)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateIkubScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Start New Ikub Cycle'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  backgroundColor: const Color(0xFF2E7D32),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Only the Idir Chairperson can launch a new Ikub cycle.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveIkubView(
      IkubGroupModel group, UserRole effectiveRole, AppUser? user) {
    final currentRound = group.currentRound;
    final isOfficer = effectiveRole.isChairperson || effectiveRole.isTreasurer;

    // Check if current user is participant
    final activeIdir = ref.watch(currentActiveIdirProvider);
    final myMembershipId = activeIdir?.id;
    final myParticipant = group.participants.cast<IkubParticipantModel?>().firstWhere(
          (p) => p?.membershipId == myMembershipId,
          orElse: () => null,
        );

    final completedRounds = group.rounds.where((r) => r.isCompleted).length;
    final progress = group.totalRounds > 0 ? (completedRounds / group.totalRounds) : 0.0;

    return Column(
      children: [
        // Top Overview Card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
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
                          group.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          group.frequency,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: Round $completedRounds of ${group.totalRounds}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF2E7D32),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'CONTRIBUTION',
                          value: '${group.contributionAmount.toStringAsFixed(0)} ${group.currency}',
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'EST. POT / ROUND',
                          value: '${group.expectedPotPerRound.toStringAsFixed(0)} ${group.currency}',
                          valueColor: const Color(0xFF2E7D32),
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'PARTICIPANTS',
                          value: '${group.participants.length}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Personal Standing / Enrollment Banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: myParticipant != null
                  ? (myParticipant.hasWonPayout ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9))
                  : const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: myParticipant != null
                    ? (myParticipant.hasWonPayout ? Colors.amber.shade400 : const Color(0xFFA5D6A7))
                    : Colors.deepPurple.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  myParticipant != null
                      ? (myParticipant.hasWonPayout ? Icons.military_tech : Icons.check_circle_outline)
                      : Icons.how_to_reg_outlined,
                  color: myParticipant != null
                      ? (myParticipant.hasWonPayout ? Colors.amber.shade800 : const Color(0xFF2E7D32))
                      : Colors.deepPurple,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        myParticipant != null
                            ? (myParticipant.hasWonPayout
                                ? 'Won Payout Cycle'
                                : 'Active Participant in Draw Pool')
                            : 'Voluntary Idir Ikub',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: myParticipant != null
                              ? (myParticipant.hasWonPayout
                                  ? Colors.amber.shade900
                                  : const Color(0xFF1B5E20))
                              : Colors.deepPurple.shade900,
                        ),
                      ),
                      Text(
                        myParticipant != null
                            ? (myParticipant.hasWonPayout
                                ? 'You have received your pot payout in this cycle.'
                                : 'You are eligible to win upcoming chance draws.')
                            : 'Participation is voluntary. You can join anytime.',
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (myParticipant == null && myMembershipId != null)
                  FilledButton.icon(
                    onPressed: _isJoining ? null : () => _oneClickJoin(group, myMembershipId),
                    icon: _isJoining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.touch_app, size: 18),
                    label: Text(_isJoining ? 'Joining...' : '1-Click Join'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Tabs: Rounds vs Participants
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E7D32),
          indicatorColor: const Color(0xFF2E7D32),
          tabs: [
            Tab(text: 'Rounds (${group.rounds.length})'),
            Tab(text: 'Roster (${group.participants.length})'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Rounds View
              _buildRoundsTab(group, isOfficer),
              // Participants View
              _buildParticipantsTab(group, isOfficer, currentRound),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoundsTab(IkubGroupModel group, bool isOfficer) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.rounds.length,
      itemBuilder: (context, index) {
        final round = group.rounds[index];
        final isCurrent = round.isInProgress;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCurrent
                ? const BorderSide(color: Color(0xFF2E7D32), width: 1.5)
                : BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: round.isCompleted
                  ? const Color(0xFF2E7D32)
                  : (round.isInProgress ? const Color(0xFFE8F5E9) : Colors.grey.shade200),
              child: Text(
                '${round.roundNumber}',
                style: TextStyle(
                  color: round.isCompleted
                      ? Colors.white
                      : (round.isInProgress ? const Color(0xFF2E7D32) : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'Round ${round.roundNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Date: ${round.scheduledDate.year}-${round.scheduledDate.month.toString().padLeft(2, '0')}-${round.scheduledDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (round.recipientName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🏆 Winner: ${round.recipientName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ],
            ),
            trailing: round.isCompleted
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                    ),
                  )
                : (isCurrent && isOfficer
                    ? FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveLotteryDrawScreen(
                                group: group,
                                round: round,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.casino_outlined, size: 16),
                        label: const Text('Draw'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFFFFF3E0) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCurrent ? 'In Progress' : 'Scheduled',
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrent ? Colors.orange.shade800 : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsTab(
      IkubGroupModel group, bool isOfficer, IkubRoundModel? currentRound) {
    if (group.participants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No participants have enrolled yet.\nMembers of this Idir can tap "Join Ikub" above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: group.participants.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = group.participants[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: p.hasWonPayout ? Colors.amber.shade100 : const Color(0xFFE8F5E9),
            child: Text(
              (p.fullName ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                color: p.hasWonPayout ? Colors.amber.shade900 : const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            p.fullName ?? 'Participant',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(p.phoneNumber ?? 'Enrolled Member'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.hasWonPayout)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Won Pot 🏆',
                    style: TextStyle(fontSize: 11, color: Color(0xFF795548), fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'In Draw Pool',
                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                  ),
                ),
              if (isOfficer && currentRound != null && currentRound.isInProgress) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.payment, size: 20, color: Color(0xFF2E7D32)),
                  tooltip: 'Record Payment',
                  onPressed: () => _showRecordPaymentSheet(group, currentRound, p),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, letterSpacing: 0.8, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}