import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../utils/auth_error_messages.dart';
import 'create_password_screen.dart';
import 'reset_password_screen.dart';

/// Screen for entering and validating the 6-digit OTP verification code.
/// Upon successful verification, directs to CreatePasswordScreen or ResetPasswordScreen.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  final String email;
  final bool isPasswordReset;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  static const int _otpLength = 6;
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;

  bool _isLoading = false;
  bool _isResending = false;
  int _secondsRemaining = 60;
  Timer? _countdownTimer;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(
      _otpLength,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(
      _otpLength,
      (_) => FocusNode(),
    );
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String get _otpCode => _digitControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _inlineError = null);

    // Support pasting multi-digit code
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _otpLength && i < digits.length; i++) {
        _digitControllers[i].text = digits[i];
      }
      final nextIndex = digits.length < _otpLength ? digits.length : _otpLength - 1;
      _focusNodes[nextIndex].requestFocus();
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    setState(() => _inlineError = null);

    final code = _otpCode;
    if (code.length != _otpLength) {
      setState(() => _inlineError = 'Please enter all 6 digits of the verification code');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (widget.isPasswordReset) {
        await _authService.verifyPasswordResetOtp(
          widget.email,
          code,
        );

        if (!mounted) return;

        showAuthSnackBar(
          context,
          'Code verified! Please create your new password.',
          isError: false,
        );

        // Navigate directly to the password reset screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: widget.email,
            ),
          ),
        );
      } else {
        final registrationToken = await _authService.verifyEmailOtp(
          widget.email,
          code,
        );

        if (!mounted) return;

        showAuthSnackBar(
          context,
          'Email verified! Now set a strong password.',
          isError: false,
        );

        // Navigate directly to the password creation screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreatePasswordScreen(
              email: widget.email,
              registrationToken: registrationToken,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _inlineError = msg);
      showAuthSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _secondsRemaining > 0) return;

    setState(() {
      _isResending = true;
      _inlineError = null;
    });

    try {
      if (widget.isPasswordReset) {
        final res = await _authService.sendPasswordResetOtp(widget.email);
        if (!mounted) return;

        final devOtp = res['devOtp'];
        final message = devOtp != null
            ? 'New code: $devOtp (Sent to ${widget.email})'
            : 'A new verification code was sent to ${widget.email}';

        showAuthSnackBar(
          context,
          message,
          isError: false,
        );
      } else {
        final res = await _authService.sendEmailOtp(widget.email);
        if (!mounted) return;

        final devOtp = res['devOtp'];
        final message = devOtp != null
            ? 'New code: $devOtp (Logged in backend console)'
            : 'A new verification code was sent to ${widget.email}';

        showAuthSnackBar(context, message, isError: false);
      }
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      showAuthSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 44,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verify Your Email',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit verification code sent to:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // 6-digit Split Boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_otpLength, (index) {
                        return SizedBox(
                          width: 48,
                          child: TextFormField(
                            controller: _digitControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            enabled: !_isLoading,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) => _onDigitChanged(index, value),
                            validator: (_) {
                              if (_otpCode.length != _otpLength) {
                                return '';
                              }
                              return null;
                            },
                          ),
                        );
                      }),
                    ),

                    // Inline Error
                    if (_inlineError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _inlineError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Verify Code Button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Text(
                                'Verify Code & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Resend Timer
                    Center(
                      child: _isResending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _secondsRemaining > 0
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Resend code in ${_secondsRemaining}s',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              : TextButton.icon(
                                  onPressed: _resendCode,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Resend verification code'),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
