import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/pin_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/theme_mode_toggle.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Login Controllers ──────────────────────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _loginIdentifierCtrl = TextEditingController(text: '1000 2000 3001');
  final _loginPasswordCtrl = TextEditingController(text: 'Password123!');
  bool _obscureLoginPassword = true;

  // ── Registration Controllers ───────────────────────────────────────────────
  final _regFinFormKey = GlobalKey<FormState>();
  final _regOtpFormKey = GlobalKey<FormState>();
  final _regPasswordFormKey = GlobalKey<FormState>();

  final _regFinCtrl = TextEditingController(text: '1000 2000 3004');
  final _regOtpCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmPasswordCtrl = TextEditingController();

  bool _obscureRegPassword = true;
  bool _obscureRegConfirmPassword = true;

  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _loginIdentifierCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regFinCtrl.dispose();
    _regOtpCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmPasswordCtrl.dispose();
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

  // ── Login Action ───────────────────────────────────────────────────────────
  Future<void> _handlePasswordSignIn() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final identifier = _loginIdentifierCtrl.text.trim();
    final password = _loginPasswordCtrl.text;

    final success = await authNotifier.signInWithPassword(
      identifier: identifier,
      password: password,
    );

    if (success && mounted) {
      final pinState = ref.read(pinNotifierProvider);
      if (!pinState.isSet) {
        context.go(AppRoutes.pinSetup);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  // ── Registration Actions ───────────────────────────────────────────────────
  Future<void> _handleRequestRegistrationOtp() async {
    if (!_regFinFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success = await authNotifier.requestFaydaOtp(_regFinCtrl.text.trim());

    if (success && mounted) {
      _startCooldown(60);
      final authState = ref.read(authNotifierProvider);
      if (authState.mockOtpHint != null) {
        _regOtpCtrl.text = authState.mockOtpHint!;
      } else {
        _regOtpCtrl.clear();
      }
    }
  }

  Future<void> _handleVerifyRegistrationOtp() async {
    if (!_regOtpFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success =
        await authNotifier.verifyFaydaCitizenOtp(_regOtpCtrl.text.trim());

    if (success && mounted) {
      _regPasswordCtrl.clear();
      _regConfirmPasswordCtrl.clear();
    }
  }

  Future<void> _handleRegisterWithPassword() async {
    if (!_regPasswordFormKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    final success =
        await authNotifier.registerWithPassword(_regPasswordCtrl.text);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration completed successfully! Welcome to Idir Connect.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final pinState = ref.read(pinNotifierProvider);
      if (!pinState.isSet) {
        context.go(AppRoutes.pinSetup);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  void _handleResetRegistration() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 0;
      _regOtpCtrl.clear();
      _regPasswordCtrl.clear();
      _regConfirmPasswordCtrl.clear();
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
                        'Instant verification with test Fayda OTP (123456)',
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
                        labelText: 'API Base URL',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'API Key (Optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
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
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    await faydaService.saveConfig(
                      baseUrl: urlCtrl.text.trim(),
                      apiKey: keyCtrl.text.trim().isEmpty ? null : keyCtrl.text.trim(),
                      isSandbox: isSandbox,
                    );
                    if (mounted) {
                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Fayda API settings updated'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Fayda API Settings',
            onPressed: _openApiConfigDialog,
          ),
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            tooltip: 'Language',
            onSelected: (loc) {
              ref.read(localeProvider.notifier).setLocale(loc);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('am'), child: Text('አማርኛ (Amharic)')),
              PopupMenuItem(value: Locale('om'), child: Text('Afaan Oromoo')),
            ],
          ),
          const ThemeModeToggle(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── App Brand Header ─────────────────────────────────────
                  _buildHeader(theme, l10n),
                  const SizedBox(height: 24),

                  // ── Error Banner ─────────────────────────────────────────
                  if (authState.errorMessage != null) ...[
                    _buildErrorBanner(authState.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // ── Mode Selection Tabs ──────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Register (Fayda)'),
                      ],
                      onTap: (_) {
                        ref.read(authNotifierProvider.notifier).clearError();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Tab Views ────────────────────────────────────────────
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSignInView(context, theme, authState),
                        _buildRegisterView(context, theme, authState),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 14, color: AppColors.subtextLight),
                        const SizedBox(width: 6),
                        Text(
                          'Protected by Ethiopian National ID (Fayda) Identity Framework',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.subtextLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance,
            size: 38,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Idir Connect',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'የኢትዮጵያ ማህበራዊ ዋስትና እና እድር መተግበሪያ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    final isNetworkError = message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('online') ||
        message.toLowerCase().contains('connection');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: Password-Based Sign In
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSignInView(
      BuildContext context, ThemeData theme, AuthState authState) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _loginFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_person_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Citizen Sign In',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Enter your Fayda FAN or Phone and password',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Identifier Field
              Text(
                'Fayda ID (FAN) or Phone Number',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _loginIdentifierCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 1000 2000 3001 or +251911...',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your Fayda ID or phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              Text(
                'Password',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _loginPasswordCtrl,
                obscureText: _obscureLoginPassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureLoginPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureLoginPassword = !_obscureLoginPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Day-to-day logins are fast, secure, and validated locally inside your database without external SMS costs.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed:
                      authState.isLoading ? null : _handlePasswordSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () {
                    _tabController.animateTo(1);
                    ref.read(authNotifierProvider.notifier).clearError();
                  },
                  child: const Text(
                    'New citizen? Register with Fayda ID',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: Fayda Verified Registration + Password Creation
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRegisterView(
      BuildContext context, ThemeData theme, AuthState authState) {
    if (authState.isFaydaOtpVerified) {
      return _buildCreatePasswordStep(context, theme, authState);
    }
    if (authState.isOtpSent) {
      return _buildRegistrationOtpStep(context, theme, authState);
    }
    return _buildEnterFaydaIdStep(context, theme, authState);
  }

  /// Step 1: Input Fayda FIN
  Widget _buildEnterFaydaIdStep(
      BuildContext context, ThemeData theme, AuthState authState) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.grey.shade300,
          ),
        ),
        child: Form(
          key: _regFinFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 1: Fayda Verification',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'One-time identity verification via National ID',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'Fayda Identification Number (FAN) *',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regFinCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _FaydaInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '1000 2000 3004',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your 12-digit Fayda ID';
                  }
                  final clean = FaydaService.normalizeFin(val);
                  if (clean.length != 12) {
                    return 'Fayda ID must be exactly 12 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Fayda will send a one-time verification SMS OTP to your registered phone to confirm your citizen identity.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: authState.isLoading
                      ? null
                      : _handleRequestRegistrationOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify Citizen Identity',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: One-time Fayda OTP verification
  Widget _buildRegistrationOtpStep(
      BuildContext context, ThemeData theme, AuthState authState) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.grey.shade300,
          ),
        ),
        child: Form(
          key: _regOtpFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 2: Enter Fayda OTP',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sent to ${authState.maskedPhone ?? "registered phone"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Change ID',
                    onPressed: _handleResetRegistration,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (authState.mockOtpHint != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        'Sandbox Test OTP: ${authState.mockOtpHint}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Text(
                '6-Digit OTP Code *',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regOtpCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '••••••',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length != 6) {
                    return 'Enter the complete 6-digit code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: authState.isLoading
                      ? null
                      : _handleVerifyRegistrationOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm OTP & Continue',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 3: Local Password Creation
  Widget _buildCreatePasswordStep(
      BuildContext context, ThemeData theme, AuthState authState) {
    final citizen = authState.verifiedCitizen;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.4),
          ),
        ),
        child: Form(
          key: _regPasswordFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verified Citizen Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppColors.success, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            citizen?.fullName ?? 'Verified Citizen',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            'FAN: ${authState.faydaId ?? ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Step 3: Create Secure Password',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a password for this cultural app. Your verified details and hashed password will be stored in your database for fast, daily logins.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              Text(
                'New Password (minimum 6 characters) *',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regPasswordCtrl,
                obscureText: _obscureRegPassword,
                decoration: InputDecoration(
                  hintText: 'Enter new password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureRegPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureRegPassword = !_obscureRegPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Confirm Password Field
              Text(
                'Confirm Password *',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regConfirmPasswordCtrl,
                obscureText: _obscureRegConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Re-enter your password',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureRegConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureRegConfirmPassword =
                            !_obscureRegConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val != _regPasswordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: authState.isLoading
                      ? null
                      : _handleRegisterWithPassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Register & Complete Setup',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: _handleResetRegistration,
                  child: const Text('Cancel & Start Over'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
