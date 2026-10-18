import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/pin_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/secure_pin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/theme_mode_toggle.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

enum PinMode { unlock, setup, change }

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({
    super.key,
    this.mode = PinMode.unlock,
  });

  final PinMode mode;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _firstEnteredPin = ''; // Used in setup mode confirmation step
  bool _isConfirming = false;
  String? _errorMessage;
  late final AnimationController _shakeController;

  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String key) {
    if (_enteredPin.length >= _pinLength) return;
    HapticFeedback.lightImpact();

    setState(() {
      _enteredPin += key;
      _errorMessage = null;
    });

    if (_enteredPin.length == _pinLength) {
      _onPinComplete(_enteredPin);
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  void _onClear() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _onPinComplete(String pin) async {
    final l10n = AppLocalizations.of(context);
    final pinNotifier = ref.read(pinNotifierProvider.notifier);

    switch (widget.mode) {
      case PinMode.unlock:
        final result = await pinNotifier.unlock(pin);
        if (!mounted) return;

        if (result == PinVerificationResult.success) {
          HapticFeedback.mediumImpact();
          context.go(AppRoutes.home);
        } else if (result == PinVerificationResult.lockedOut) {
          _triggerShake();
          setState(() {
            _enteredPin = '';
            _errorMessage = l10n.pinTooManyAttempts;
          });
        } else {
          _triggerShake();
          final remaining = ref.read(pinNotifierProvider).remainingAttempts;
          setState(() {
            _enteredPin = '';
            _errorMessage = '${l10n.pinIncorrect} ($remaining ${remaining == 1 ? "attempt left" : "attempts left"})';
          });
        }
        break;

      case PinMode.setup:
      case PinMode.change:
        if (!_isConfirming) {
          setState(() {
            _firstEnteredPin = pin;
            _enteredPin = '';
            _isConfirming = true;
          });
        } else {
          if (pin == _firstEnteredPin) {
            await pinNotifier.setupPin(pin);
            if (!mounted) return;
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.mode == PinMode.change
                    ? l10n.pinChangedSuccess
                    : l10n.pinSetSuccess),
                backgroundColor: AppColors.success,
              ),
            );
            context.go(AppRoutes.home);
          } else {
            _triggerShake();
            setState(() {
              _enteredPin = '';
              _errorMessage = l10n.pinMismatch;
            });
          }
        }
        break;
    }
  }

  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
  }

  Future<void> _onForgotPin() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pinState = ref.watch(pinNotifierProvider);

    String title;
    String subtitle;

    if (widget.mode == PinMode.unlock) {
      title = l10n.pinTitle;
      subtitle = l10n.pinSubtitle;
    } else {
      if (_isConfirming) {
        title = l10n.pinConfirmTitle;
        subtitle = l10n.pinConfirmSubtitle;
      } else {
        title = l10n.pinSetupTitle;
        subtitle = l10n.pinSetupSubtitle;
      }
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        leading: (widget.mode == PinMode.setup && _isConfirming)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isConfirming = false;
                    _enteredPin = '';
                    _firstEnteredPin = '';
                    _errorMessage = null;
                  });
                },
              )
            : (widget.mode == PinMode.change)
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  )
                : null,
        actions: [
          const ThemeModeToggle(),
          if (widget.mode == PinMode.setup && !_isConfirming)
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.skipForNow),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Icon Lock badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Header text
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 4 Dots Indicator
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final offset =
                    (_shakeController.value > 0 && _shakeController.value < 1.0)
                        ? (12.0 *
                            (1.0 - _shakeController.value) *
                            (0.5 - ((_shakeController.value * 6) % 1.0)))
                        : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final isFilled = i < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: isFilled ? 18 : 14,
                        height: isFilled ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_errorMessage != null
                                  ? AppColors.error
                                  : AppColors.primary)
                              : Colors.transparent,
                          border: Border.all(
                            color: _errorMessage != null
                                ? AppColors.error
                                : (isFilled
                                    ? AppColors.primary
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3)),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),

            // Error Message
            const SizedBox(height: 16),
            SizedBox(
              height: 24,
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : (pinState.isLockedOut
                      ? Text(
                          l10n.pinTooManyAttempts,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : null),
            ),

            const Spacer(flex: 2),

            // Numeric Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  _buildKeypadBottomRow(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Forgot PIN / Sign in option
            if (widget.mode == PinMode.unlock)
              TextButton(
                onPressed: _onForgotPin,
                child: Text(
                  l10n.forgotPin,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKeypadBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Clear
        SizedBox(
          width: 72,
          height: 72,
          child: TextButton(
            onPressed: _onClear,
            style: TextButton.styleFrom(
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.clear, color: Colors.grey, size: 24),
          ),
        ),
        // 0
        _buildKey('0'),
        // Backspace
        SizedBox(
          width: 72,
          height: 72,
          child: TextButton(
            onPressed: _onBackspace,
            style: TextButton.styleFrom(
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.backspace_outlined,
                color: Colors.grey, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String label) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onKeyPress(label),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
