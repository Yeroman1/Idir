import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/pin_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/fayda_service.dart';
import '../providers/auth_provider.dart';

/// Formatter to group 12 digits as `XXXX XXXX XXXX`
class _FaydaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _finFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _finCtrl = TextEditingController(text: '1000 2000 3001');
  final _otpCtrl = TextEditingController();

  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _finCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      }
    });
  }

  void _selectDemoAccount(String rawFin) {
    setState(() {
      _finCtrl.text = FaydaService.formatFin(rawFin);
    });
    ref.read(authNotifierProvider.notifier).clearError();
  }

  Future<void> _handleRequestOtp() async {
    if (!_finFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.requestFaydaOtp(_finCtrl.text.trim());

    if (success && mounted) {
      _startCooldown(60);
      final authState = ref.read(authNotifierProvider);
      if (authState.mockOtpHint != null) {
        // Pre-fill or make easy in test mode
        _otpCtrl.text = authState.mockOtpHint!;
      } else {
        _otpCtrl.clear();
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.verifyFaydaOtp(_otpCtrl.text.trim());

    if (success && mounted) {
      final pinState = ref.read(pinNotifierProvider);
      if (!pinState.isSet) {
        context.go(AppRoutes.pinSetup);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  void _handleChangeId() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 0;
      _otpCtrl.clear();
    });
    ref.read(authNotifierProvider.notifier).resetOtpFlow();
  }

  Future<void> _openApiConfigDialog() async {
    final faydaService = ref.read(faydaServiceProvider);
    final config = await faydaService.getConfig();

    if (!mounted) return;

    final urlCtrl = TextEditingController(text: config.baseUrl);
    final keyCtrl = TextEditingController(text: config.apiKey ?? '');
    bool isSandbox = config.isSandbox;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Fayda API Settings', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure endpoint connectivity for Ethiopian National ID (Fayda) API authentication.',
                      style: TextStyle(fontSize: 13, color: AppColors.subtextLight),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sandbox / Test Mode',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                        'Instant offline verification with test Fayda OTP (123456)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isSandbox,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) {
                        setDialogState(() {
                          isSandbox = val;
                          urlCtrl.text = isSandbox
                              ? FaydaService.defaultSandboxBaseUrl
                              : FaydaService.defaultLiveBaseUrl;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fayda API Base URL',
                        hintText: 'https://api.fayda.et/v1/auth',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: keyCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Authorization Key (Optional)',
                        hintText: 'Bearer token or client secret',
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(dialogCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    await faydaService.saveConfig(
                      baseUrl: urlCtrl.text.trim(),
                      apiKey: keyCtrl.text.trim(),
                      isSandbox: isSandbox,
                    );
                    if (mounted) {
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Fayda API configuration updated.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      setState(() {});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Fayda API Configuration',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openApiConfigDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ethiopian National Flag Stripe Accent ─────────────────────
              Center(
                child: Container(
                  width: 90,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF078930), // Ethiopian Green
                        Color(0xFFFCDD09), // Ethiopian Yellow
                        Color(0xFFDA121A), // Ethiopian Red
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Fayda Official Emblem / Header ───────────────────────────
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF14532D), // Deep Green
                        Color(0xFF1A6B5A), // Idir Teal
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A6B5A).withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4821A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Fayda & Idir Branding ────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ፋይዳ • FAYDA',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF078930),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'NIDP API',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ethiopian National ID Authentication',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.idirName} • የኢትዮጵያ ማህበራዊ ዋስትና መተግበሪያ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.subtextLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Active Step: Step 1 (Fayda ID) or Step 2 (OTP) ─────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: authState.isOtpSent
                    ? _buildOtpStepView(context, authState)
                    : _buildFinStepView(context, authState),
              ),

              const SizedBox(height: 28),

              // ── Quick Role Selection for Demo & Evaluation ─────────────────
              if (!authState.isOtpSent) _buildDemoRolesSection(context),

              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: AppColors.subtextLight),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-End Encrypted via Fayda e-KYC Protocol',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.subtextLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 1: Input Fayda Identification Number (12 digits)
  Widget _buildFinStepView(BuildContext context, AuthState authState) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('step_fin'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _finFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Fayda Identification Number (FIN)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'ያስገቡ የ12 አኃዝ ብሔራዊ መታወቂያ ቁጥርዎን። የማረጋገጫ ኮድ (OTP) ወደ ተመዘገበው ስልክዎ ይላካል።',
              style: TextStyle(fontSize: 12, color: AppColors.subtextLight),
            ),
            const SizedBox(height: 16),

            // FIN Input Field
            TextFormField(
              controller: _finCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [_FaydaInputFormatter()],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleRequestOtp(),
              style: const TextStyle(
                fontSize: 18,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '1000 2000 3001',
                prefixIcon: const Icon(Icons.fingerprint_rounded),
                suffixIcon: _finCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _finCtrl.clear()),
                      )
                    : null,
                helperText: '12-digit Ethiopian National ID',
              ),
              validator: (v) {
                final clean = FaydaService.normalizeFin(v ?? '');
                if (clean.isEmpty) {
                  return 'Please enter your Fayda ID.';
                }
                if (clean.length != 12) {
                  return 'Fayda ID must be exactly 12 digits (${clean.length}/12).';
                }
                return null;
              },
            ),

            // Error banner
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildErrorBanner(authState.errorMessage!),
            ],

            const SizedBox(height: 20),

            // Request OTP Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: authState.isLoading ? null : _handleRequestOtp,
                icon: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sms_outlined, size: 20),
                label: Text(
                  authState.isLoading
                      ? 'Contacting Fayda API…'
                      : 'Request Fayda OTP • ኮድ ላክ',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2: Enter SMS OTP sent by Fayda
  Widget _buildOtpStepView(BuildContext context, AuthState authState) {
    final theme = Theme.of(context);
    final finDisplay = FaydaService.formatFin(authState.faydaId ?? _finCtrl.text);

    return Container(
      key: const ValueKey('step_otp'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _otpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_read_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verify Fayda OTP',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _handleChangeId,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Change ID', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Masked phone & ID confirmation box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Fayda FIN: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        finDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_android, size: 14, color: AppColors.subtextLight),
                      const SizedBox(width: 4),
                      Text(
                        'Code dispatched to ${authState.maskedPhone ?? "+251 9• ••• ••••"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.subtextLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (authState.mockOtpHint != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  _otpCtrl.text = authState.mockOtpHint!;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4821A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD4821A).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.developer_mode,
                          size: 16, color: Color(0xFFD4821A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sandbox Test Code: ${authState.mockOtpHint} (Tap to autofill)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E5C0D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // OTP Input
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleVerifyOtp(),
              style: const TextStyle(
                fontSize: 26,
                letterSpacing: 10.0,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '••••••',
                prefixIcon: Icon(Icons.security_rounded),
                helperText: 'Enter 6-digit SMS OTP',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 4) {
                  return 'Please enter the 6-digit OTP code.';
                }
                return null;
              },
            ),

            // Error banner
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildErrorBanner(authState.errorMessage!),
            ],

            const SizedBox(height: 20),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: authState.isLoading ? null : _handleVerifyOtp,
                icon: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user_rounded, size: 20),
                label: Text(
                  authState.isLoading
                      ? 'Verifying with Fayda API…'
                      : 'Verify & Authenticate • አረጋግጥ',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Resend link
            Center(
              child: _secondsRemaining > 0
                  ? Text(
                      'Resend code in ${_secondsRemaining}s',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.subtextLight,
                      ),
                    )
                  : TextButton.icon(
                      onPressed: authState.isLoading ? null : _handleRequestOtp,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Resend Fayda OTP'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Pre-configured demo Fayda IDs for seamless testing of leadership and member roles
  Widget _buildDemoRolesSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Fayda Test Citizens / Demo Accounts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap any registered Ethiopian National ID to populate and test its assigned role:',
            style: TextStyle(fontSize: 11, color: AppColors.subtextLight),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.gavel, size: 16, color: AppColors.primary),
                label: Text('${l10n.roleChairperson} (Abebe)'),
                onPressed: () => _selectDemoAccount('1000 2000 3001'),
              ),
              ActionChip(
                avatar: const Icon(Icons.payments_outlined, size: 16, color: AppColors.secondary),
                label: Text('${l10n.roleTreasurer} (Chaltu)'),
                onPressed: () => _selectDemoAccount('1000 2000 3002'),
              ),
              ActionChip(
                avatar: const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF1565C0)),
                label: Text('${l10n.roleAuditor} (Dawit)'),
                onPressed: () => _selectDemoAccount('1000 2000 3003'),
              ),
              ActionChip(
                avatar: const Icon(Icons.person, size: 16, color: Color(0xFF4E7D6B)),
                label: Text('${l10n.roleMember} (Fatima)'),
                onPressed: () => _selectDemoAccount('1000 2000 3004'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
