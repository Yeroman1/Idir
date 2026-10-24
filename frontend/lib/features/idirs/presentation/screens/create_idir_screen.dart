import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/idir_creation_provider.dart';

class CreateIdirScreen extends ConsumerStatefulWidget {
  const CreateIdirScreen({super.key});

  @override
  ConsumerState<CreateIdirScreen> createState() => _CreateIdirScreenState();
}

class _CreateIdirScreenState extends ConsumerState<CreateIdirScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _communityController = TextEditingController();
  final _locationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();

  String _frequency = 'MONTHLY';

  @override
  void dispose() {
    _nameController.dispose();
    _communityController.dispose();
    _locationController.dispose();
    _purposeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final success =
        await ref.read(createIdirNotifierProvider.notifier).submit(
              name: _nameController.text.trim(),
              community: _communityController.text.trim(),
              location: _locationController.text.trim(),
              purpose: _purposeController.text.trim(),
              contributionAmount: amount,
              contributionFrequency: _frequency,
            );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Idir draft created successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Navigate to dashboard where the Idir with DRAFT badge is displayed
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(createIdirNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Idir'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: SafeArea(
        child: user != null
            ? _buildCreateForm(context, theme, user, state)
            : _buildUnverifiedNotice(context, theme),
      ),
    );
  }

  /// Shown when user is not authenticated
  Widget _buildUnverifiedNotice(BuildContext context, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gpp_bad_outlined,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Authentication Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please sign in or create an account to establish and register a new community Idir.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 20, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Text(
                    'Status: Not Signed In',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.login),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In to Continue'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.go(AppRoutes.home),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Return to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when user is authenticated
  Widget _buildCreateForm(
    BuildContext context,
    ThemeData theme,
    AppUser? user,
    CreateIdirState state,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verified banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppColors.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verified Account (${user?.name.isNotEmpty == true ? user!.name : "Authenticated Member"})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Name
            Text(
              'Idir Name *',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Bole Medhanealem Community Idir',
                prefixIcon: const Icon(Icons.groups_outlined),
                errorText: state.fieldErrors['name'],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 2) {
                  return 'Idir name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Community
            Text(
              'Community *',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _communityController,
              decoration: InputDecoration(
                hintText: 'e.g. Bole Subcity, Kebele 03',
                prefixIcon: const Icon(Icons.location_city_outlined),
                errorText: state.fieldErrors['community'],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 2) {
                  return 'Community must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Location
            Text(
              'Location *',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'e.g. Addis Ababa',
                prefixIcon: const Icon(Icons.place_outlined),
                errorText: state.fieldErrors['location'],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 2) {
                  return 'Location must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Purpose
            Text(
              'Purpose *',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _purposeController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the mutual aid, funeral coverage, and social goals...',
                alignLabelWithHint: true,
                errorText: state.fieldErrors['purpose'],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().length < 5) {
                  return 'Purpose must be at least 5 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Contribution Amount
            Text(
              'Contribution Amount (ETB) *',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'e.g. 250.00',
                prefixIcon: const Icon(Icons.attach_money),
                errorText: state.fieldErrors['contributionAmount'],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Contribution amount is required';
                }
                final num = double.tryParse(val.trim());
                if (num == null || num <= 0) {
                  return 'Contribution amount must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Contribution Frequency
            Text(
              'Contribution Frequency *',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _frequency = val);
                }
              },
            ),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: state.isLoading ? null : _submitForm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save as Draft Idir',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
