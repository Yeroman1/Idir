import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idir_app/core/theme/app_theme.dart';
import 'package:idir_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:idir_app/features/cooperation/presentation/providers/cooperation_provider.dart';

class ProposeCooperationScreen extends ConsumerStatefulWidget {
  const ProposeCooperationScreen({super.key});

  @override
  ConsumerState<ProposeCooperationScreen> createState() => _ProposeCooperationScreenState();
}

class _ProposeCooperationScreenState extends ConsumerState<ProposeCooperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetIdirIdCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  @override
  void dispose() {
    _targetIdirIdCtrl.dispose();
    _purposeCtrl.dispose();
    _descriptionCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  String _getIdirId() {
    final user = ref.read(currentUserProvider);
    if (user == null) return '';
    if (user.memberships.isEmpty) return user.idirId ?? '';
    try {
      return user.memberships.firstWhere((m) => m.isActive).idirId;
    } catch (_) {
      return user.memberships.first.idirId;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final idirId = _getIdirId();
    final durationText = _durationCtrl.text.trim();
    final duration = durationText.isNotEmpty ? int.tryParse(durationText) : null;

    await ref.read(cooperationActionProvider.notifier).proposeCooperation(
          idirId,
          targetIdirId: _targetIdirIdCtrl.text.trim(),
          purpose: _purposeCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          proposedDuration: duration,
        );

    final state = ref.read(cooperationActionProvider);
    if (!mounted) return;

    state.when(
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cooperation proposal sent successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      },
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(cooperationActionProvider);
    final isLoading = actionState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Propose Cooperation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Propose a cross-Idir cooperation agreement with another Idir association.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _targetIdirIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target Idir ID',
                  hintText: 'Enter the ID of the target Idir',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Target Idir ID is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'Brief purpose of the cooperation',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Purpose is required';
                  if (v.trim().length < 5) return 'Purpose must be at least 5 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Detailed description of cooperation goals',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Description is required';
                  if (v.trim().length < 10) return 'Description must be at least 10 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Proposed Duration (months, optional)',
                  hintText: 'e.g. 12',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 120) return 'Duration must be 1–120 months';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Proposal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
