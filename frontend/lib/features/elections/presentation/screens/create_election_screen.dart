import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/providers/active_idir_provider.dart';
import '../providers/elections_provider.dart';

class CreateElectionScreen extends ConsumerStatefulWidget {
  const CreateElectionScreen({super.key, this.idirId});

  final String? idirId;

  @override
  ConsumerState<CreateElectionScreen> createState() => _CreateElectionScreenState();
}

class _CreateElectionScreenState extends ConsumerState<CreateElectionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termMonthsController = TextEditingController(text: '24');
  final _quorumController = TextEditingController(text: '50.0');
  final _disputeHoursController = TextEditingController(text: '48');
  final _committeeInputController = TextEditingController();

  final List<String> _availableRoles = const [
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'AUDITOR',
    'COMMITTEE',
    'OFFICER',
  ];

  final Set<String> _selectedRoles = {'CHAIRPERSON', 'TREASURER', 'SECRETARY'};
  final List<String> _committeeMemberIds = [];

  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);

  DateTime _endDate = DateTime.now().add(const Duration(days: 5));
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  DateTime? _nominationStartDate;
  DateTime? _nominationEndDate;

  String _votingMethod = 'SIMPLE_MAJORITY'; // 'SIMPLE_MAJORITY' or 'RUNOFF'
  String _ballotType = 'SECRET'; // 'SECRET' or 'OPEN'
  bool _requiresGoodStanding = true;
  final int _minTenureDays = 90;

  @override
  void initState() {
    super.initState();
    // Pre-populate with default neutral committee member slot
    _committeeMemberIds.add('neutral-committee-member-1');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _termMonthsController.dispose();
    _quorumController.dispose();
    _disputeHoursController.dispose();
    _committeeInputController.dispose();
    super.dispose();
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );
      if (!mounted) return;
      setState(() {
        _startDate = picked;
        if (time != null) _startTime = time;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _endTime,
      );
      if (!mounted) return;
      setState(() {
        _endDate = picked;
        if (time != null) _endTime = time;
      });
    }
  }

  void _addCommitteeMember() {
    final text = _committeeInputController.text.trim();
    if (text.isNotEmpty && !_committeeMemberIds.contains(text)) {
      setState(() {
        _committeeMemberIds.add(text);
        _committeeInputController.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = ref.read(authNotifierProvider).user;
    if (authUser != null && !authUser.role.canManageElections) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: Only Chairperson and authorized leadership officers can create an election',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final start = _combineDateTime(_startDate, _startTime);
    final end = _combineDateTime(_endDate, _endTime);

    final termMonths = int.tryParse(_termMonthsController.text) ?? 24;
    final quorum = double.tryParse(_quorumController.text) ?? 50.0;
    final disputeHours = int.tryParse(_disputeHoursController.text) ?? 48;

    final idirId = widget.idirId ?? ref.read(activeIdirIdProvider) ?? 'active-idir-id';

    final success = await ref
        .read(electionCreationProvider.notifier)
        .createElection(
          idirId: idirId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          roles: _selectedRoles.toList(),
          startDate: start,
          endDate: end,
          nominationStartDate: _nominationStartDate,
          nominationEndDate: _nominationEndDate,
          termLengthMonths: termMonths,
          votingMethod: _votingMethod,
          ballotType: _ballotType,
          quorumPercentage: quorum,
          minMembershipTenureDays: _minTenureDays,
          requiresGoodStanding: _requiresGoodStanding,
          disputeWindowHours: disputeHours,
          committeeMemberIds: _committeeMemberIds,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leadership election successfully created!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        final err = ref.read(electionCreationProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Failed to create election. Check settings.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(electionCreationProvider);
    final user = ref.watch(authNotifierProvider).user;
    final isAllowed = user?.role.canManageElections ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Leadership Election'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isAllowed) ...[
                Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.amber.shade400),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber.shade800),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Institutional Notice: Only the Chairperson and authorized officers have authority to configure and publish leadership elections.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── 1. Basic Information ─────────────────────────────────────────
              Text('Election Title & Scope', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Election Title *',
                  hintText: 'e.g., 2026 Leadership Committee General Election',
                  prefixIcon: Icon(Icons.how_to_vote_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Bylaw Notes & Statement (Optional)',
                  hintText: 'Summary of constitutional mandate, eligibility, and quorum guidelines',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // ── 2. Contested Leadership Roles ────────────────────────────────
              Text('Contested Leadership Roles *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Select which executive committee positions are open for election:',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableRoles.map((role) {
                  final isSelected = _selectedRoles.contains(role);
                  return FilterChip(
                    label: Text(role),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoles.add(role);
                        } else {
                          if (_selectedRoles.length > 1) {
                            _selectedRoles.remove(role);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('At least one contested role is required'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── 3. Voting Schedule ───────────────────────────────────────────
              Text('Voting Window *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'Start:\n${_startDate.toLocal().toString().split(' ')[0]} ${_startTime.format(context)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        'End:\n${_endDate.toLocal().toString().split(' ')[0]} ${_endTime.format(context)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 4. Voting Method & Ballot Privacy ────────────────────────────
              Text('Voting & Ballot Method *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _votingMethod,
                      decoration: const InputDecoration(
                        labelText: 'Voting Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'SIMPLE_MAJORITY',
                          child: Text('Simple Majority'),
                        ),
                        DropdownMenuItem(
                          value: 'RUNOFF',
                          child: Text('Run-off Voting'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _votingMethod = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _ballotType,
                      decoration: const InputDecoration(
                        labelText: 'Ballot Privacy',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'SECRET',
                          child: Text('Secret Ballot'),
                        ),
                        DropdownMenuItem(
                          value: 'OPEN',
                          child: Text('Open Ballot'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _ballotType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 5. Term Length & Quorum ──────────────────────────────────────
              Text('Term Length & Quorum Rules *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _termMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Term Length (Months) *',
                        hintText: 'e.g. 24',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        if (n == null || n < 1 || n > 120) {
                          return 'Between 1 and 120 months';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quorumController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quorum % *',
                        hintText: '50.0',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n < 1.0 || n > 100.0) {
                          return 'Between 1% and 100%';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _disputeHoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dispute Window (Hours)',
                        hintText: '48',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      title: const Text('Good Standing', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('No unpaid dues', style: TextStyle(fontSize: 11)),
                      value: _requiresGoodStanding,
                      onChanged: (val) => setState(() => _requiresGoodStanding = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 6. Neutral Election Committee ────────────────────────────────
              Text('Neutral Election Committee *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Assign non-candidate active members to oversee integrity and ballot counting:',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _committeeInputController,
                      decoration: const InputDecoration(
                        labelText: 'Committee Member ID / Phone',
                        hintText: 'Enter member ID',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addCommitteeMember(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addCommitteeMember,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _committeeMemberIds.map((id) {
                  return Chip(
                    label: Text(id),
                    avatar: const Icon(Icons.verified_user_outlined, size: 18),
                    onDeleted: () {
                      if (_committeeMemberIds.length > 1) {
                        setState(() => _committeeMemberIds.remove(id));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('At least one committee member is required'),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // ── 7. Submit Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: state.isLoading ? null : _submit,
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    state.isLoading ? 'Configuring Election...' : 'Publish Election Setup',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
