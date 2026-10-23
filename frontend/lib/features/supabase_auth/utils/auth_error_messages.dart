import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase [AuthException] codes and raw message payloads into clean,
/// human-readable feedback for end users.
String humanReadableAuthError(AuthException error) {
  final code = error.code?.toLowerCase() ?? '';
  final message = error.message.toLowerCase();

  // User already registered / exists
  if (code == 'user_already_registered' ||
      code == 'user_already_exists' ||
      message.contains('already registered') ||
      message.contains('already exists')) {
    return 'An account with this email already exists. Please sign in instead.';
  }

  // Invalid login credentials
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials') ||
      message.contains('invalid email or password')) {
    return 'Incorrect email or password. Please verify your credentials and try again.';
  }

  // OTP expired
  if (code == 'otp_expired' || message.contains('expired')) {
    return 'The verification code has expired. Please request a new code.';
  }

  // OTP disabled in project
  if (code == 'otp_disabled') {
    return 'Email verification is not enabled in your Supabase project settings.';
  }

  // Invalid / incorrect OTP code
  if (message.contains('token') &&
      (message.contains('invalid') ||
          message.contains('incorrect') ||
          message.contains('expired'))) {
    return 'Invalid verification code. Please check the 6 digits and try again.';
  }

  // Email not yet confirmed
  if (message.contains('email not confirmed')) {
    return 'Your email address has not been verified yet. Please enter the OTP code sent to your email.';
  }

  // Rate limiting / abuse prevention
  if (code == 'over_email_send_rate_limit' ||
      message.contains('rate limit') ||
      message.contains('too many requests')) {
    return 'Too many attempts. Please wait a minute before requesting another code.';
  }

  // Email format validation
  if (message.contains('valid email')) {
    return 'Please enter a valid email address.';
  }

  // Password policy violation
  if (message.contains('weak password') || message.contains('password')) {
    return 'Password does not meet required security standards.';
  }

  return error.message.isNotEmpty
      ? error.message
      : 'Authentication failed. Please check your network connection and try again.';
}

/// Displays a styled Material 3 floating SnackBar with an appropriate status icon.
void showAuthSnackBar(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? colorScheme.onError : colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? colorScheme.onError : colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 4),
      ),
    );
}
