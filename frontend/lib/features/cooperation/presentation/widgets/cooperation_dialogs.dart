import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idir_app/core/theme/app_theme.dart';
import 'package:idir_app/features/cooperation/domain/models/cooperation_models.dart';
import 'package:idir_app/features/cooperation/presentation/providers/cooperation_provider.dart';

// ── 1. Respond to Cooperation Dialog ─────────────────────────────────────────

class RespondToCooperationDialog extends StatefulWidget {
  const RespondToCooperationDialog({super.key, required this.onRespond});

  final void Function(String action, String? reason) onRespond;

  @override
  State<RespondToCooperationDialog> createState() => _RespondToCooperationDialogState();
}

class _RespondToCooperationDialogState extends State<RespondToCooperationDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline Cooperation'),
      content: TextField(
        controller: _reasonController,
        decoration: const InputDecoration(
          labelText: 'Reason for declining (optional)',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRespond('reject', _reasonController.text.trim());
          },
          child: const Text('Decline'),
        ),
      ],
    );
  }
}

// ── 2. End Cooperation Dialog ────────────────────────────────────────────────

class EndCooperationDialog extends StatefulWidget {
  const EndCooperationDialog({super.key, required this.onConfirm});

  final void Function(String reason) onConfirm;

  @override
  State<EndCooperationDialog> createState() => _EndCooperationDialogState();
}

class _EndCooperationDialogState extends State<EndCooperationDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End Cooperation Agreement'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ending this agreement will archive active shared resources and conclude ongoing cross-Idir activities. Past records will be preserved.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for ending *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide a reason' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop();
              widget.onConfirm(_reasonController.text.trim());
            }
          },
          child: const Text('End Cooperation'),
        ),
      ],
    );
  }
}

// ── 3. Create Initiative Dialog ──────────────────────────────────────────────

class CreateInitiativeDialog extends ConsumerStatefulWidget {
  const CreateInitiativeDialog({
    super.key,
    required this.idirId,
    required this.agreementId,
    required this.onCreated,
  });

  final String idirId;
  final String agreementId;
  final VoidCallback onCreated;

  @override
  ConsumerState<CreateInitiativeDialog> createState() => _CreateInitiativeDialogState();
}

class _CreateInitiativeDialogState extends ConsumerState<CreateInitiativeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _objController = TextEditingController();
  InitiativeCategory _category = InitiativeCategory.communitySupport;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _objController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      await ref.read(cooperationActionProvider.notifier).createInitiative(
            widget.idirId,
            widget.agreementId,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            objectives: _objController.text.trim(),
            category: _category.value,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joint Initiative created!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Joint Initiative'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Title must be >= 3 characters' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InitiativeCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: InitiativeCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (val) => val != null ? setState(() => _category = val) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _objController,
                decoration: const InputDecoration(labelText: 'Objectives *', border: OutlineInputBorder()),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().length < 5) ? 'Objectives required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().length < 5) ? 'Description required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
    );
  }
}

// ── 4. Create Announcement Dialog ────────────────────────────────────────────

class CreateAnnouncementDialog extends ConsumerStatefulWidget {
  const CreateAnnouncementDialog({
    super.key,
    required this.idirId,
    required this.agreementId,
    required this.onCreated,
  });

  final String idirId;
  final String agreementId;
  final VoidCallback onCreated;

  @override
  ConsumerState<CreateAnnouncementDialog> createState() => _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends ConsumerState<CreateAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  AnnouncementCrossCategory _category = AnnouncementCrossCategory.general;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      await ref.read(cooperationActionProvider.notifier).createAnnouncement(
            widget.idirId,
            widget.agreementId,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            category: _category.value,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cross-Idir announcement broadcasted!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Publish Cross-Idir Announcement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Title required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AnnouncementCrossCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: AnnouncementCrossCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (val) => val != null ? setState(() => _category = val) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Body / Message *', border: OutlineInputBorder()),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().length < 5) ? 'Message body required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publish'),
        ),
      ],
    );
  }
}

// ── 5. Create Emergency Dialog ───────────────────────────────────────────────

class CreateEmergencyDialog extends ConsumerStatefulWidget {
  const CreateEmergencyDialog({
    super.key,
    required this.idirId,
    required this.agreementId,
    required this.onCreated,
  });

  final String idirId;
  final String agreementId;
  final VoidCallback onCreated;

  @override
  ConsumerState<CreateEmergencyDialog> createState() => _CreateEmergencyDialogState();
}

class _CreateEmergencyDialogState extends ConsumerState<CreateEmergencyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _typeController = TextEditingController(text: 'COMMUNITY_EMERGENCY');
  EmergencyUrgency _urgency = EmergencyUrgency.high;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      await ref.read(cooperationActionProvider.notifier).createEmergency(
            widget.idirId,
            widget.agreementId,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            emergencyType: _typeController.text.trim(),
            urgency: _urgency.value,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency assistance request issued!'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Emergency Request'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Emergency Title *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Title required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EmergencyUrgency>(
                initialValue: _urgency,
                decoration: const InputDecoration(labelText: 'Urgency Level', border: OutlineInputBorder()),
                items: EmergencyUrgency.values.map((u) => DropdownMenuItem(value: u, child: Text(u.label))).toList(),
                onChanged: (val) => val != null ? setState(() => _urgency = val) : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Type of Emergency *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Type required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Situation Details & Needed Assistance *', border: OutlineInputBorder()),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().length < 5) ? 'Details required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Issue Alert'),
        ),
      ],
    );
  }
}

// ── 6. Create Financial Commitment Dialog ────────────────────────────────────

class CreateFinancialCommitmentDialog extends ConsumerStatefulWidget {
  const CreateFinancialCommitmentDialog({
    super.key,
    required this.idirId,
    required this.agreementId,
    required this.onCreated,
  });

  final String idirId;
  final String agreementId;
  final VoidCallback onCreated;

  @override
  ConsumerState<CreateFinancialCommitmentDialog> createState() => _CreateFinancialCommitmentDialogState();
}

class _CreateFinancialCommitmentDialogState extends ConsumerState<CreateFinancialCommitmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _submitting = true);

    try {
      await ref.read(cooperationActionProvider.notifier).createCommitment(
            widget.idirId,
            widget.agreementId,
            amountCommitted: amount,
            purpose: _purposeController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Financial commitment registered. Awaiting leadership authorization.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pledge Financial Support'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Financial commitments remain pending until explicitly authorized by your Idir leadership. Unconfirmed pledges are never treated as paid funds.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (ETB) *', border: OutlineInputBorder()),
                keyboardType: const TextInputTextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final val = double.tryParse(v?.trim() ?? '');
                  return (val == null || val <= 0) ? 'Enter a valid amount > 0' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(labelText: 'Purpose / Allocation *', border: OutlineInputBorder()),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().length < 3) ? 'Purpose required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register Pledge'),
        ),
      ],
    );
  }
}

// Helper typedef
typedef TextInputTextInputType = TextInputType;
