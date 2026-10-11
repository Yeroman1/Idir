import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../data/claims_repository.dart';
import '../../domain/models/claim.dart';
import '../providers/claims_provider.dart';

class SubmitClaimDialog extends ConsumerStatefulWidget {
  const SubmitClaimDialog({super.key, this.preselectedMemberId});

  final String? preselectedMemberId;

  @override
  ConsumerState<SubmitClaimDialog> createState() => _SubmitClaimDialogState();
}

class _SubmitClaimDialogState extends ConsumerState<SubmitClaimDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController(text: '3000');
  final _descCtrl = TextEditingController();

  Member? _selectedMember;
  ClaimType _selectedType = ClaimType.funeral;
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _initDefaults(List<Member> members, AppUser? currentUser) {
    if (_isInit) return;
    _isInit = true;

    if (currentUser?.role == UserRole.member) {
      try {
        _selectedMember = members.firstWhere(
          (m) => m.memberId == currentUser?.memberId || m.id == currentUser?.memberId,
        );
      } catch (_) {
        _selectedMember = members.isNotEmpty ? members.first : null;
      }
    } else if (widget.preselectedMemberId != null) {
      try {
        _selectedMember = members.firstWhere(
          (m) => m.id == widget.preselectedMemberId || m.memberId == widget.preselectedMemberId,
        );
      } catch (_) {
        _selectedMember = members.isNotEmpty ? members.first : null;
      }
    } else if (members.isNotEmpty) {
      _selectedMember = members.first;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMember == null) return;

    if (_selectedMember!.status != MemberStatus.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot submit claim: Member is suspended or inactive.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    final currentUser = ref.read(currentUserProvider);

    setState(() => _isLoading = true);

    try {
      final claimsRepo = ref.read(claimsRepositoryProvider);
      final claimNumber = await claimsRepo.generateNextClaimNumber();
      final now = DateTime.now();

      final claim = Claim(
        id: const Uuid().v4(),
        claimNumber: claimNumber,
        memberId: _selectedMember!.memberId,
        memberName: _selectedMember!.fullName,
        type: _selectedType,
        description: _descCtrl.text.trim(),
        requestedAmount: double.tryParse(_amountCtrl.text.trim()) ?? 3000.0,
        status: ClaimStatus.submitted,
        submittedBy: currentUser?.uid ?? 'unknown',
        submittedByName: currentUser?.name ?? 'Member',
        approvals: const [],
        createdAt: now,
      );

      final success = await ref
          .read(claimActionNotifierProvider.notifier)
          .submitClaim(claim);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('${l10n.claimsTitle}: $claimNumber submitted'),
              backgroundColor: AppColors.success,
            ),
          );
          navigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error submitting claim: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final membersAsync = ref.watch(membersStreamProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isRegularMember = currentUser?.role == UserRole.member;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AlertDialog(
        title: const Text('Error'),
        content: Text('$e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
      data: (members) {
        _initDefaults(members, currentUser);

        final memberHasArrears =
            _selectedMember != null && _selectedMember!.arrears > 0;
        final memberIsInactive =
            _selectedMember != null && _selectedMember!.status != MemberStatus.active;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title & Close ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.post_add,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.submitClaim,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ── Member Selector ───────────────────────────────────
                    Text(
                      l10n.selectMember,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    if (isRegularMember)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          _selectedMember != null
                              ? '${_selectedMember!.fullName} (${_selectedMember!.memberId})'
                              : currentUser?.name ?? 'Current Member',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMember?.id,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: members.map((m) {
                          return DropdownMenuItem<String>(
                            value: m.id,
                            child: Text(
                              '${m.fullName} (${m.memberId})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMember = members.firstWhere((m) => m.id == val);
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 8),

                    // ── Warnings (Inactive / Arrears) ──────────────────────
                    if (memberIsInactive)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.error, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Member is suspended or inactive. Claim submission is blocked.',
                                style: TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (memberHasArrears)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Member has overdue arrears (${_selectedMember!.arrears.toStringAsFixed(0)} ETB). Committee will review standing.',
                                style: const TextStyle(fontSize: 11, color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ── Claim Type Selector ────────────────────────────────
                    const Text(
                      'Claim Type',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ClaimType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ClaimType.funeral,
                          child: Text('Funeral & Condolence Aid'),
                        ),
                        DropdownMenuItem(
                          value: ClaimType.illness,
                          child: Text('Medical / Illness Emergency'),
                        ),
                        DropdownMenuItem(
                          value: ClaimType.other,
                          child: Text('Other Mutual Aid Assistance'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedType = val;
                            if (val == ClaimType.funeral) {
                              _amountCtrl.text = '3000';
                            } else if (val == ClaimType.illness) {
                              _amountCtrl.text = '1500';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Requested Amount ───────────────────────────────────
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${l10n.amountLabel} *',
                        prefixIcon: const Icon(Icons.money),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n.invalidAmount;
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return l10n.invalidAmount;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Circumstances & Notes ──────────────────────────────
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description & Circumstances *',
                        hintText: 'e.g. Bereavement support for dependent father',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please provide circumstances for committee review';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Action Buttons ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isLoading || memberIsInactive) ? null : _handleSubmit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.confirm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
