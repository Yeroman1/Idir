import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/ikub_models.dart';
import '../providers/ikub_provider.dart';

class LiveLotteryDrawScreen extends ConsumerStatefulWidget {
  const LiveLotteryDrawScreen({
    super.key,
    required this.group,
    required this.round,
  });

  final IkubGroupModel group;
  final IkubRoundModel round;

  @override
  ConsumerState<LiveLotteryDrawScreen> createState() =>
      _LiveLotteryDrawScreenState();
}

class _LiveLotteryDrawScreenState extends ConsumerState<LiveLotteryDrawScreen>
    with SingleTickerProviderStateMixin {
  bool _isSpinning = false;
  String _displayName = 'Ready for Draw';
  IkubParticipantModel? _drawnWinner;
  String? _selectedManualWinnerId;
  Timer? _spinTimer;

  late final List<IkubParticipantModel> _eligibleParticipants;

  @override
  void initState() {
    super.initState();
    _eligibleParticipants = widget.group.participants
        .where((p) => p.status == 'ACTIVE' && !p.hasWonPayout)
        .toList();

    final pendingWinnerId = widget.round.recipientParticipantId;
    final isAlreadyPaid = widget.round.payouts.any((p) => p.recipientParticipantId == pendingWinnerId);
    if (pendingWinnerId != null && !isAlreadyPaid) {
      final existingWinner = widget.group.participants.cast<IkubParticipantModel?>().firstWhere(
            (p) => p?.id == pendingWinnerId,
            orElse: () => null,
          );
      if (existingWinner != null) {
        _drawnWinner = existingWinner;
        _displayName = existingWinner.fullName ?? 'Drawn Winner';
      }
    } else if (_eligibleParticipants.isNotEmpty) {
      _displayName = _eligibleParticipants.first.fullName ?? 'Participant 1';
    }
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  void _triggerDraw({bool isRedraw = false, String? redrawReason}) async {
    if (_eligibleParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible participants remain to draw')),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _drawnWinner = null;
    });

    final random = Random();
    int spinTicks = 0;
    const totalTicks = 25;

    // Fast cycling animation through participant names
    _spinTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      spinTicks++;
      setState(() {
        final idx = random.nextInt(_eligibleParticipants.length);
        _displayName = _eligibleParticipants[idx].fullName ?? 'Participant';
      });

      if (spinTicks >= totalTicks) {
        timer.cancel();
      }
    });

    try {
      final result = await ref.read(activeIkubProvider.notifier).drawLottery(
            widget.round.id,
            manualWinnerId: widget.group.drawMode == 'PHYSICAL_RECORDED'
                ? _selectedManualWinnerId
                : null,
            isRedraw: isRedraw ? true : null,
            redrawReason: redrawReason,
          );

      // Wait for spin timer to complete if it hasn't
      if (spinTicks < totalTicks) {
        await Future.delayed(Duration(milliseconds: (totalTicks - spinTicks) * 100));
      }

      final winnerMap = result['winner'] as Map<String, dynamic>?;
      final winnerId = winnerMap?['id'] as String?;
      final winnerName = winnerMap?['fullName'] as String? ?? 'Winner';

      final found = _eligibleParticipants.firstWhere(
        (p) => p.id == winnerId,
        orElse: () => _eligibleParticipants.first,
      );

      if (mounted) {
        setState(() {
          _isSpinning = false;
          _drawnWinner = found;
          _displayName = winnerName;
        });

        _showWinnerCelebrationDialog(winnerName, found);
      }
    } catch (e) {
      _spinTimer?.cancel();
      if (mounted) {
        setState(() => _isSpinning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lottery draw error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _promptRedrawDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audited Redraw'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A winner is already recorded for this round. Conducting a redraw requires documenting an audited reason for Idir records.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Redraw Reason *',
                hintText: 'e.g. Drawn member declined or unreachable',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason must be at least 5 characters')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              _triggerDraw(isRedraw: true, redrawReason: reason);
            },
            child: const Text('Confirm Redraw'),
          ),
        ],
      ),
    );
  }

  void _showWinnerCelebrationDialog(String name, IkubParticipantModel winner) {
    final potAmount = widget.group.expectedPotPerWinner;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Text('🎉 🎊 🥳', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text(
                'Congratulations!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Won Round ${widget.round.roundNumber} Pot: ${potAmount.toStringAsFixed(0)} ETB',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The winning member has been recorded. You can now disburse the payout.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showDisbursePayoutSheet(winner);
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Disburse Payout'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            ),
          ],
        );
      },
    );
  }

  void _showDisbursePayoutSheet(IkubParticipantModel winner) {
    final amountController = TextEditingController(
      text: widget.group.expectedPotPerWinner.toStringAsFixed(0),
    );
    final refController = TextEditingController();
    String paymentMethod = 'CASH';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Disburse Round ${widget.round.roundNumber} Payout',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2E7D32),
                      child: Text(
                        (winner.fullName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(winner.fullName ?? 'Participant'),
                    subtitle: Text(winner.phoneNumber ?? 'Enrolled Member'),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payout Amount (ETB)',
                      prefixText: 'ETB ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Method
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash in Hand')),
                      DropdownMenuItem(value: 'TELEBIRR', child: Text('Telebirr')),
                      DropdownMenuItem(value: 'CBE_BIRR', child: Text('CBE Birr')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Reference
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Reference / Receipt # (Optional)',
                      hintText: 'e.g. TXN987654321',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amt = double.tryParse(amountController.text) ?? 0.0;
                            if (amt <= 0) return;

                            final messenger = ScaffoldMessenger.of(context);
                            final router = GoRouter.of(context);
                            final sheetNavigator = Navigator.of(sheetContext);

                            setSheetState(() => isSaving = true);
                            try {
                              await ref.read(activeIkubProvider.notifier).recordPayout(
                                    roundId: widget.round.id,
                                    recipientParticipantId: winner.id,
                                    amount: amt,
                                    paymentMethod: paymentMethod,
                                    paymentReference: refController.text.trim().isNotEmpty
                                        ? refController.text.trim()
                                        : null,
                                  );

                              if (!mounted) return;
                              sheetNavigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Payout recorded successfully!'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                              router.pop(); // return to Ikub hub
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to record payout: $e'),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm & Complete Round'),
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
    final potAmount = widget.group.expectedPotPerRound;

    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${widget.round.roundNumber} Draw'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Round Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Cycle: ${widget.group.name}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pot Display Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL POT TO WIN',
                      style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${potAmount.toStringAsFixed(0)} ETB',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_eligibleParticipants.length} eligible participants in draw pool',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Animated Wheel / Drum Frame
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSpinning
                      ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                      : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _isSpinning
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: _isSpinning ? const Color(0xFF81C784) : const Color(0xFFA5D6A7),
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSpinning ? Icons.cached : Icons.stars_rounded,
                    size: 38,
                    color: _isSpinning ? Colors.amberAccent : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _isSpinning ? Colors.white : const Color(0xFF1B5E20),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSpinning
                        ? 'Spinning chance lottery...'
                        : (_drawnWinner != null
                            ? '🎉 Winner Selected!'
                            : 'Tap below to draw winner'),
                    style: TextStyle(
                      fontSize: 13,
                      color: _isSpinning ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Manual Winner Selection (If draw mode is physical)
            if (widget.group.drawMode == 'PHYSICAL_RECORDED') ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedManualWinnerId,
                decoration: const InputDecoration(
                  labelText: 'Select Physically Drawn Member *',
                  prefixIcon: Icon(Icons.how_to_reg),
                ),
                items: _eligibleParticipants
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.fullName ?? "Participant"} (${p.phoneNumber ?? ""})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedManualWinnerId = val;
                    if (val != null) {
                      final m = _eligibleParticipants.firstWhere((p) => p.id == val);
                      _displayName = m.fullName ?? 'Selected Member';
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons: If a winner has been drawn and not yet paid out, offer Disburse Payout or Audited Redraw
            if (_drawnWinner != null &&
                !widget.round.payouts.any((p) => p.recipientParticipantId == _drawnWinner!.id)) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _showDisbursePayoutSheet(_drawnWinner!),
                  icon: const Icon(Icons.payments_outlined, size: 22),
                  label: Text(
                    'Disburse Payout (${widget.group.expectedPotPerWinner.toStringAsFixed(0)} ETB)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isSpinning ? null : _promptRedrawDialog,
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: const Text('Audited Redraw...'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ] else ...[
              // Standard Draw Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSpinning ? null : () => _triggerDraw(),
                  icon: _isSpinning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.casino_outlined, size: 24),
                  label: Text(
                    _isSpinning
                        ? 'Drawing Chance...'
                        : (widget.group.drawMode == 'PHYSICAL_RECORDED'
                            ? 'Confirm Drawn Winner'
                            : 'Roll & Draw Winner'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Eligible Pool Preview List
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Eligible Pool (${_eligibleParticipants.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _eligibleParticipants.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _eligibleParticipants[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      (p.fullName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(p.fullName ?? 'Participant', style: const TextStyle(fontSize: 14)),
                  subtitle: Text(p.phoneNumber ?? 'Enrolled Member', style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Eligible',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
