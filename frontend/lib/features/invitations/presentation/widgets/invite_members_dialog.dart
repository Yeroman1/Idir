import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/invitation_result.dart';
import '../providers/invitations_provider.dart';

class InviteMembersDialog extends ConsumerStatefulWidget {
  const InviteMembersDialog({
    super.key,
    required this.idirId,
    required this.idirName,
  });

  final String idirId;
  final String idirName;

  @override
  ConsumerState<InviteMembersDialog> createState() => _InviteMembersDialogState();
}

class _InviteMembersDialogState extends ConsumerState<InviteMembersDialog> {
  final _phoneController = TextEditingController();
  int _expiresInDays = 7;
  String? _localError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  List<String> _parsePhoneNumbers(String text) {
    return text
        .split(RegExp(r'[\n,;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final rawPhones = _parsePhoneNumbers(_phoneController.text);
    if (rawPhones.isEmpty) {
      setState(() {
        _localError = 'Please enter at least one Ethiopian mobile phone number.';
      });
      return;
    }

    if (rawPhones.length > 50) {
      setState(() {
        _localError = 'A maximum of 50 phone numbers can be invited at once.';
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    await ref.read(invitationNotifierProvider.notifier).sendBatch(
          idirId: widget.idirId,
          phoneNumbers: rawPhones,
          expiresInDays: _expiresInDays,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invitationNotifierProvider);
    final theme = Theme.of(context);
    final result = state.result;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Members',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.idirName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: result != null
                      ? _buildResultView(context, result)
                      : _buildFormView(context, state),
                ),
              ),

              const SizedBox(height: 16),
              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (result != null) ...[
                    OutlinedButton(
                      onPressed: () {
                        ref.read(invitationNotifierProvider.notifier).reset();
                        _phoneController.clear();
                      },
                      child: const Text('Invite More'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Done'),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: state.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(state.isLoading ? 'Sending...' : 'Send SMS Invitations'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context, InvitationState state) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter Ethiopian Mobile Numbers',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Separate multiple phone numbers with commas or line breaks (e.g. 0911223344, 0712345678). Each invitee receives an SMS with a secure personal join link.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '0911223344, 0922334455\n0712345678',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Icon(Icons.phone_android_outlined),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Invitation Validity',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            DropdownButton<int>(
              value: _expiresInDays,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 3, child: Text('3 Days')),
                DropdownMenuItem(value: 7, child: Text('7 Days (Recommended)')),
                DropdownMenuItem(value: 14, child: Text('14 Days')),
                DropdownMenuItem(value: 30, child: Text('30 Days')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _expiresInDays = val);
              },
            ),
          ],
        ),
        if (_localError != null) ...[
          const SizedBox(height: 12),
          Text(
            _localError!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultView(BuildContext context, BatchInvitationResult result) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${result.sentCount} invitation(s) sent successfully via SMS!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Generated Joining Links:',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...result.invitations.map((inv) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.link, color: AppColors.primary, size: 20),
                title: Text(
                  inv.phoneNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  inv.inviteUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Invite Link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inv.inviteUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Link for ${inv.phoneNumber} copied to clipboard!'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            )),
        if (result.skipped.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Skipped Numbers (${result.skipped.length}):',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 6),
          ...result.skipped.map((skip) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      skip.phoneNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '— ${skip.reason}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
