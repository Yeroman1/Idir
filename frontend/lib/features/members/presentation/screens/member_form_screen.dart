import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/members_repository.dart';
import '../../domain/models/member.dart';
import '../providers/members_provider.dart';

class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({
    super.key,
    this.editMemberId,
  });

  final String? editMemberId;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _memberIdCtrl = TextEditingController();
  final _duesCtrl = TextEditingController(text: '50');
  final _notesCtrl = TextEditingController();

  // Emergency contact
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  String _ecRelationship = 'Spouse';

  // Dependents
  final List<Dependent> _dependents = [];

  MemberStatus _status = MemberStatus.active;
  bool _isLoading = false;
  bool _isInit = false;
  Member? _existingMember;

  static const _relationships = [
    'Spouse',
    'Child',
    'Parent',
    'Brother',
    'Sister',
    'Relative',
    'Friend',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _loadData();
      _isInit = true;
    }
  }

  Future<void> _loadData() async {
    if (widget.editMemberId != null) {
      final repo = ref.read(membersRepositoryProvider);
      final member = await repo.getMemberById(widget.editMemberId!);
      if (member != null && mounted) {
        setState(() {
          _existingMember = member;
          _fullNameCtrl.text = member.fullName;
          _phoneCtrl.text = member.phone;
          _memberIdCtrl.text = member.memberId;
          _duesCtrl.text = member.monthlyDues.toStringAsFixed(0);
          _notesCtrl.text = member.notes;
          _status = member.status;

          if (member.emergencyContact != null) {
            _ecNameCtrl.text = member.emergencyContact!.name;
            _ecPhoneCtrl.text = member.emergencyContact!.phone;
            _ecRelationship = member.emergencyContact!.relationship.isNotEmpty
                ? member.emergencyContact!.relationship
                : 'Spouse';
          }

          _dependents.addAll(member.dependents);
        });
      }
    } else {
      // Add mode: auto-generate next member ID
      final repo = ref.read(membersRepositoryProvider);
      final nextId = await repo.generateNextMemberId();
      if (mounted) {
        setState(() {
          _memberIdCtrl.text = nextId;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _memberIdCtrl.dispose();
    _duesCtrl.dispose();
    _notesCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    super.dispose();
  }

  void _addDependentDialog() {
    final nameCtrl = TextEditingController();
    String rel = 'Child';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Covered Family Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: rel,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => rel = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _dependents.add(
                      Dependent(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        relationship: rel,
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);
    final isEdit = _existingMember != null;
    final now = DateTime.now();

    final emergencyContact = _ecNameCtrl.text.trim().isNotEmpty
        ? EmergencyContact(
            name: _ecNameCtrl.text.trim(),
            phone: _ecPhoneCtrl.text.trim(),
            relationship: _ecRelationship,
          )
        : null;

    final member = Member(
      id: isEdit ? _existingMember!.id : const Uuid().v4(),
      memberId: _memberIdCtrl.text.trim(),
      fullName: _fullNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      registeredAt: isEdit ? _existingMember!.registeredAt : now,
      monthlyDues: double.tryParse(_duesCtrl.text.trim()) ?? 50.0,
      status: _status,
      emergencyContact: emergencyContact,
      dependents: List.from(_dependents),
      totalPaid: isEdit ? _existingMember!.totalPaid : 0.0,
      balance: isEdit ? _existingMember!.balance : 0.0,
      arrears: isEdit ? _existingMember!.arrears : 0.0,
      notes: _notesCtrl.text.trim(),
      createdAt: isEdit ? _existingMember!.createdAt : now,
      updatedAt: now,
    );

    final notifier = ref.read(memberActionNotifierProvider.notifier);
    final success = isEdit
        ? await notifier.updateMember(member)
        : await notifier.createMember(member);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? l10n.memberUpdatedSuccess
                : l10n.memberCreatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.editMemberId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editMember : l10n.addMember),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Basic Info Section ─────────────────────────────────────
              Text('Member Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),

              TextFormField(
                controller: _fullNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.fullNameLabel,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.invalidName : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.invalidPhone : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _memberIdCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.memberIdLabel,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter Member ID'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _duesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.monthlyDuesLabel,
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter dues';
                        if (double.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Status Dropdown
              DropdownButtonFormField<MemberStatus>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: l10n.statusLabel,
                  prefixIcon: const Icon(Icons.info_outline),
                ),
                items: [
                  DropdownMenuItem(
                      value: MemberStatus.active,
                      child: Text(l10n.statusActive)),
                  DropdownMenuItem(
                      value: MemberStatus.suspended,
                      child: Text(l10n.statusSuspended)),
                  DropdownMenuItem(
                      value: MemberStatus.deceased,
                      child: Text(l10n.statusDeceased)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 24),

              // ── Emergency Contact Section ──────────────────────────────
              Text(l10n.emergencyContactTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ecNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.contactNameLabel,
                  prefixIcon: const Icon(Icons.contact_phone_outlined),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ecPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.phoneLabel,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _ecRelationship,
                      decoration: InputDecoration(
                        labelText: l10n.relationshipLabel,
                      ),
                      items: _relationships
                          .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _ecRelationship = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Dependents Section ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${l10n.dependentsTitle} (${_dependents.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  TextButton.icon(
                    onPressed: _addDependentDialog,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addDependent),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_dependents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noDependents,
                      style: const TextStyle(color: Colors.grey)),
                )
              else
                ..._dependents.asMap().entries.map((entry) {
                  final i = entry.key;
                  final dep = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.family_restroom,
                          color: AppColors.primary),
                      title: Text(dep.name),
                      subtitle: Text(dep.relationship),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          setState(() => _dependents.removeAt(i));
                        },
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // ── Notes / Remarks ────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.notesLabel,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.save),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
