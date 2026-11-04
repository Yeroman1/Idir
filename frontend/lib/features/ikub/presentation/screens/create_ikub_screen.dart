import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/active_idir_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ikub_provider.dart';

class CreateIkubScreen extends ConsumerStatefulWidget {
  const CreateIkubScreen({super.key});

  @override
  ConsumerState<CreateIkubScreen> createState() => _CreateIkubScreenState();
}

class _CreateIkubScreenState extends ConsumerState<CreateIkubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController(text: '1000');
  final _roundsController = TextEditingController(text: '10');

  String _frequency = 'WEEKLY';
  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  int _winnersPerRound = 1;
  String _drawMode = 'DIGITAL_LOTTERY';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _roundsController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final activeIdir = ref.read(currentActiveIdirProvider);
    if (activeIdir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active Idir selected')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final rounds = int.tryParse(_roundsController.text.trim()) ?? 10;

    setState(() => _isLoading = true);

    try {
      await ref.read(activeIkubProvider.notifier).createGroup(
            name: _nameController.text.trim(),
            description: _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : null,
            contributionAmount: amount,
            frequency: _frequency,
            startDate: _startDate,
            totalRounds: rounds,
            winnersPerRound: _winnersPerRound,
            drawMode: _drawMode,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Ikub cycle successfully launched!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create Ikub: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIdir = ref.watch(currentActiveIdirProvider);
    final user = ref.watch(currentUserProvider);
    final effectiveRole = activeIdir?.role ?? user?.role ?? UserRole.member;

    if (!effectiveRole.isChairperson) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Idir Ikub')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Access Restricted: Only the Chairperson of this Idir can configure and launch a new Ikub cycle.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final amount = double.tryParse(_amountController.text) ?? 1000.0;
    final rounds = int.tryParse(_roundsController.text) ?? 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Ikub Cycle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Banner Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined, color: Color(0xFF2E7D32), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Idir Ikub: ${activeIdir?.idirName ?? ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'An Idir can have only 1 active Ikub. Funds are kept strictly separated from funeral assistance reserves.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ikub Cycle Name *',
                hintText: 'e.g. 2026 Community Savings Ikub',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'Please provide a descriptive name (at least 3 chars)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description / Purpose (Optional)',
                hintText: 'e.g. For festival celebration savings or business support',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Contribution Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Contribution Amount Per Round *',
                prefixIcon: Container(
                  width: 54,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ETB',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                suffixText: 'per member',
              ),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) {
                  return 'Please enter a valid amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Frequency
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Collection Frequency *',
                prefixIcon: Icon(Icons.event_repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly (የሳምንት እቁብ)')),
                DropdownMenuItem(value: 'BIWEEKLY', child: Text('Bi-Weekly (የሁለት ሳምንት)')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly (የወር እቁብ)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _frequency = val);
              },
            ),
            const SizedBox(height: 16),

            // Total Rounds
            TextFormField(
              controller: _roundsController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Total Rounds (Cycle Length) *',
                hintText: 'e.g. 10',
                prefixIcon: Icon(Icons.format_list_numbered),
                helperText: 'Auto-generates scheduled rounds for this duration',
              ),
              validator: (v) {
                final val = int.tryParse(v ?? '');
                if (val == null || val <= 1) {
                  return 'Must have at least 2 rounds';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Start Date
            InkWell(
              onTap: _pickStartDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'First Round Start Date *',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(
                  '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Winners per Round
            const Text(
              'Payout Distribution per Draw',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('1 Winner (100% Pot)'),
                    selected: _winnersPerRound == 1,
                    onSelected: (sel) {
                      if (sel) setState(() => _winnersPerRound = 1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('2 Winners (50% Each)'),
                    selected: _winnersPerRound == 2,
                    onSelected: (sel) {
                      if (sel) setState(() => _winnersPerRound = 2);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Draw Mode
            const Text(
              'Chance / Lottery Draw Mode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🎲 Live Digital Draw'),
                    selected: _drawMode == 'DIGITAL_LOTTERY',
                    onSelected: (sel) {
                      if (sel) setState(() => _drawMode = 'DIGITAL_LOTTERY');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('📝 Traditional / Manual'),
                    selected: _drawMode == 'PHYSICAL_RECORDED',
                    onSelected: (sel) {
                      if (sel) setState(() => _drawMode = 'PHYSICAL_RECORDED');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Calculation Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cycle Summary Preview',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Frequency: $_frequency\n'
                    '• Total Duration: $rounds rounds\n'
                    '• Contribution: ${amount.toStringAsFixed(0)} ETB per member per round\n'
                    '• Winners: $_winnersPerRound winner(s) per draw\n'
                    '• Payout Split: ${_winnersPerRound == 1 ? '100% of round pot to single winner' : '$_winnersPerRound winners (equal ${((100 / _winnersPerRound)).toStringAsFixed(0)}% split enforced by backend)'}\n'
                    '• Max Capacity: ${rounds * _winnersPerRound} participants ($rounds rounds × $_winnersPerRound winner(s))\n'
                    '• Draw: ${_drawMode == 'DIGITAL_LOTTERY' ? 'Cryptographically randomized digital lottery' : 'Traditional physical draw'}\n'
                    '• All $rounds rounds will be automatically scheduled upon creation.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isLoading ? 'Configuring Ikub...' : 'Launch Ikub Cycle'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
