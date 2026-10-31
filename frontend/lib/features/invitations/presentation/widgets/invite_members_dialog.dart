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

enum InviteMode { email, phone }

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
  final _emailController = TextEditingController();
  InviteMode _inviteMode = InviteMode.email;
  int _expiresInDays = 7;
  String? _localError;
  Timer? _debounceTimer;
  bool _isCheckingUser = false;
  Map<String, dynamic>? _userCheckResult;

  static final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _emailController.removeListener(_onEmailChanged);
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    _debounceTimer?.cancel();
    final email = _emailController.text.trim();

    if (_localError != null) {
      _localError = null;
    }

    if (_emailRegex.hasMatch(email)) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _checkUser(email: email);
      });
    } else {
      if (_userCheckResult != null || _isCheckingUser) {
        _userCheckResult = null;
        _isCheckingUser = false;
      }
    }
    setState(() {});
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
        _checkUser(phone: fullPhone);
      });
    } else {
      if (_userCheckResult != null || _isCheckingUser) {
        _userCheckResult = null;
        _isCheckingUser = false;
      }
    }
    setState(() {});
  }

  Future<void> _checkUser({String? phone, String? email}) async {
    setState(() {
      _isCheckingUser = true;
      _userCheckResult = null;
    });

    try {
      final res = await ref.read(invitationsRepositoryProvider).checkUserRegistration(
            idirId: widget.idirId,
            phone: phone,
            email: email,
          );
      if (mounted) {
        setState(() {
          _isCheckingUser = false;
          _userCheckResult = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUser = false;
          _userCheckResult = {
            'exists': false,
            'message': 'Error checking user: ${e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "")}',
          };
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _localError = null);

    if (_inviteMode == InviteMode.email) {
      final email = _emailController.text.trim().toLowerCase();
      if (email.isEmpty) {
        setState(() {
          _localError = 'Please enter an email address.';
        });
        return;
      }

      if (!_emailRegex.hasMatch(email)) {
        setState(() {
          _localError = 'Please enter a valid email address (e.g. name@example.com).';
        });
        return;
      }

      if (_userCheckResult != null && _userCheckResult!['isAlreadyMember'] == true) {
        setState(() {
          _localError = 'This user is already an active member of this Idir.';
        });
        return;
      }

      // Block sending if user is not registered
      if (_userCheckResult != null && _userCheckResult!['exists'] == false) {
        setState(() {
          _localError = _userCheckResult!['message']?.toString() ??
              'No registered user found with this email. They must register on Idir first.';
        });
        return;
      }

      // If user check hasn't completed yet, run it now
      if (_userCheckResult == null && !_isCheckingUser) {
        await _checkUser(email: email);
        if (_userCheckResult != null && _userCheckResult!['exists'] != true) {
          setState(() {
            _localError = _userCheckResult!['message']?.toString() ??
                'No registered user found with this email. They must register on Idir first.';
          });
          return;
        }
      }

      await ref.read(invitationNotifierProvider.notifier).sendBatch(
            idirId: widget.idirId,
            emails: [email],
            expiresInDays: _expiresInDays,
          );
    } else {
      String rawDigits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (rawDigits.startsWith('251') && rawDigits.length > 9) {
        rawDigits = rawDigits.substring(3);
      }
      while (rawDigits.startsWith('0')) {
        rawDigits = rawDigits.substring(1);
      }

      if (rawDigits.isEmpty) {
        setState(() {
          _localError = 'Please enter an Ethiopian mobile phone number.';
        });
        return;
      }

      if (rawDigits.length != 9) {
        setState(() {
          _localError = 'Phone number must be exactly 9 digits (e.g. 911223344 or 0911223344).';
        });
        return;
      }

      if (!rawDigits.startsWith('9') && !rawDigits.startsWith('7')) {
        setState(() {
          _localError = 'Ethiopian mobile number must start with 9 or 7 (e.g. 911223344 or 0911223344).';
        });
        return;
      }

      final fullPhone = '+251$rawDigits';

      if (_userCheckResult != null && _userCheckResult!['isAlreadyMember'] == true) {
        setState(() {
          _localError = 'This user is already an active member of this Idir.';
        });
        return;
      }

      // Block sending if user is not registered
      if (_userCheckResult != null && _userCheckResult!['exists'] == false) {
        setState(() {
          _localError = _userCheckResult!['message']?.toString() ??
              'No registered user found with this phone number. They must register on Idir first.';
        });
        return;
      }

      // If user check hasn't completed yet, run it now
      if (_userCheckResult == null && !_isCheckingUser) {
        await _checkUser(phone: fullPhone);
        if (_userCheckResult != null && _userCheckResult!['exists'] != true) {
          setState(() {
            _localError = _userCheckResult!['message']?.toString() ??
                'No registered user found with this phone number. They must register on Idir first.';
          });
          return;
        }
      }

      await ref.read(invitationNotifierProvider.notifier).sendBatch(
            idirId: widget.idirId,
            phoneNumbers: [fullPhone],
            expiresInDays: _expiresInDays,
          );
    }
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
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
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
                          _emailController.clear();
                          setState(() {
                            _localError = null;
                            _userCheckResult = null;
                          });
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
                          state.isLoading ? 'Sending...' : 'Send Invite',
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
        // Mode Selector: Email vs Phone
        SegmentedButton<InviteMode>(
          segments: const [
            ButtonSegment(
              value: InviteMode.email,
              label: Text('Email'),
              icon: Icon(Icons.email_outlined, size: 18),
            ),
            ButtonSegment(
              value: InviteMode.phone,
              label: Text('Phone'),
              icon: Icon(Icons.phone_android_outlined, size: 18),
            ),
          ],
          selected: {_inviteMode},
          onSelectionChanged: (newSelection) {
            setState(() {
              _inviteMode = newSelection.first;
              _localError = null;
              _userCheckResult = null;
            });
          },
        ),
        const SizedBox(height: 16),

        if (_inviteMode == InviteMode.email) ...[
          Text(
            'Invitee Email Address',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the email address of the person you want to invite. They must be a registered Idir user. The invitation will appear in their Idir app.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            maxLines: 1,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
              hintText: 'e.g. member@example.com',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              suffixIcon: _emailController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      tooltip: 'Clear',
                      splashRadius: 16,
                      onPressed: () {
                        _emailController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ] else ...[
          Text(
            'Ethiopian Mobile Number',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the 9-digit mobile number. The user must be registered on Idir. The invitation will appear in their Idir app.',
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
        ],

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
                'Checking user...',
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
                          'User: ${((_userCheckResult!['user'] as Map<String, dynamic>?)?['fullName']) ?? ''}',
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
                          'No registered user found. The user must register on Idir first.',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result.sentCount} invitation sent successfully!',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'The recipient can accept or reject this invitation directly within the Idir application upon logging in.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ],
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
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Invitations Sent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _inviteMode == InviteMode.email
                            ? 'The invitation could not be sent. Please verify the email address.'
                            : 'The entered phone number does not belong to a registered user. The user must register first before receiving an invitation.',
                        style: const TextStyle(fontSize: 11),
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
            'Generated Invitation Links:',
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
                  leading: Icon(
                    _inviteMode == InviteMode.email ? Icons.email_outlined : Icons.link,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    inv.target,
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
                          content: Text('Link for ${inv.target} copied to clipboard!'),
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
            'Skipped (${result.skipped.length}):',
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
                      skip.target,
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
