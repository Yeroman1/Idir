import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/invitations_repository.dart';
import '../../domain/models/invitation_result.dart';
import '../providers/invitations_provider.dart';

/// Formatter that ensures only Ethiopian mobile numbers (9 digits, no leading 0, no non-digits)
/// are entered when the +251 country prefix is already provided.
class EthiopianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;
    if (newText.isEmpty) {
      return newValue;
    }

    // Strip leading '+251' or '251' if pasted
    if (newText.startsWith('+251')) {
      newText = newText.substring(4);
    } else if (newText.startsWith('251') && newText.length > 9) {
      newText = newText.substring(3);
    }

    // Keep ONLY digits (no letters, spaces, hyphens, symbols)
    newText = newText.replaceAll(RegExp(r'\D'), '');

    // Strip leading '0' if pasted or typed (domestic 09.../07... format)
    while (newText.startsWith('0')) {
      newText = newText.substring(1);
    }

    // Strictly limit to 9 digits
    if (newText.length > 9) {
      newText = newText.substring(0, 9);
    }

    int cursorPosition = newValue.selection.end;
    if (cursorPosition > newText.length) {
      cursorPosition = newText.length;
    } else if (cursorPosition < 0) {
      cursorPosition = 0;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

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
  Timer? _debounceTimer;
  bool _isCheckingUser = false;
  Map<String, dynamic>? _userCheckResult;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    _debounceTimer?.cancel();
    final digits = _phoneController.text.trim();

    if (_localError != null) {
      _localError = null;
    }

    if (digits.length == 9) {
      final fullPhone = '+251$digits';
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _checkSingleUser(fullPhone);
      });
    } else {
      if (_userCheckResult != null || _isCheckingUser) {
        _userCheckResult = null;
        _isCheckingUser = false;
      }
    }
    setState(() {});
  }

  Future<void> _checkSingleUser(String phone) async {
    setState(() {
      _isCheckingUser = true;
      _userCheckResult = null;
    });

    try {
      final res = await ref.read(invitationsRepositoryProvider).checkUserRegistration(
            idirId: widget.idirId,
            phone: phone,
          );
      if (mounted) {
        setState(() {
          _isCheckingUser = false;
          _userCheckResult = res;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingUser = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final digits = _phoneController.text.trim();
    if (digits.isEmpty) {
      setState(() {
        _localError = 'Please enter an Ethiopian mobile phone number.';
      });
      return;
    }

    if (digits.length != 9) {
      setState(() {
        _localError = 'Phone number must be exactly 9 digits (e.g. 911223344).';
      });
      return;
    }

    if (!digits.startsWith('9') && !digits.startsWith('7')) {
      setState(() {
        _localError = 'Ethiopian mobile number must start with 9 or 7 (e.g. 911223344).';
      });
      return;
    }

    final fullPhone = '+251$digits';

    if (_userCheckResult != null && _userCheckResult!['exists'] == false) {
      setState(() {
        _localError = 'No user found with phone number "$fullPhone". User must register first.';
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    await ref.read(invitationNotifierProvider.notifier).sendBatch(
          idirId: widget.idirId,
          phoneNumbers: [fullPhone],
          expiresInDays: _expiresInDays,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invitationNotifierProvider);
    final theme = Theme.of(context);
    final result = state.result;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                          'Invite Member',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

              Flexible(
                child: SingleChildScrollView(
                  child: result != null
                      ? _buildResultView(context, result)
                      : _buildFormView(context, state),
                ),
              ),

              const SizedBox(height: 16),
              // Bottom Actions
              Row(
                children: [
                  if (result != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref.read(invitationNotifierProvider.notifier).reset();
                          _phoneController.clear();
                        },
                        child: const Text('Invite Another', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Done', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: state.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: state.isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          state.isLoading ? 'Sending...' : 'Send SMS Invite',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
          'Ethiopian Mobile Number',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 9-digit mobile number. The invitee receives an SMS with a secure personal join link.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          maxLines: 1,
          maxLength: 9,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          inputFormatters: [
            EthiopianPhoneInputFormatter(),
          ],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '+251',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: '911223344',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              letterSpacing: 1.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            counterText: '',
            suffixIcon: _phoneController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    tooltip: 'Clear',
                    splashRadius: 16,
                    onPressed: () {
                      _phoneController.clear();
                    },
                  )
                : null,
          ),
        ),
        if (_isCheckingUser) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Checking registered user...',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ] else if (_userCheckResult != null) ...[
          const SizedBox(height: 8),
          if (_userCheckResult!['exists'] == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _userCheckResult!['isAlreadyMember'] == true
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _userCheckResult!['isAlreadyMember'] == true
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _userCheckResult!['isAlreadyMember'] == true
                        ? Icons.info_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: _userCheckResult!['isAlreadyMember'] == true
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _userCheckResult!['message']?.toString() ??
                          'Registered user: ${((_userCheckResult!['user'] as Map<String, dynamic>?)?['fullName']) ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _userCheckResult!['isAlreadyMember'] == true
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_off_outlined, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _userCheckResult!['message'] ??
                          'No registered user found with this number. User must register first.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _expiresInDays,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Invitation Validity',
            prefixIcon: const Icon(Icons.timer_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 3, child: Text('3 Days', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 7, child: Text('7 Days (Recommended)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 14, child: Text('14 Days', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 30, child: Text('30 Days', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _expiresInDays = val);
          },
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
        if (result.sentCount > 0)
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
                    '${result.sentCount} invitation sent successfully via SMS!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_off_outlined, color: AppColors.error, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Invitations Sent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'The entered phone number does not belong to a registered user. The user must register first before receiving an invitation.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (result.invitations.isNotEmpty) ...[
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
        ],
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
