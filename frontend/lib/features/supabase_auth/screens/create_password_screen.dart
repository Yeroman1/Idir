import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../utils/auth_error_messages.dart';

/// Screen where the verified user completes their profile registration and sets a strong password.
class CreatePasswordScreen extends ConsumerStatefulWidget {
  const CreatePasswordScreen({
    super.key,
    required this.email,
    required this.registrationToken,
  });

  final String email;
  final String registrationToken;

  @override
  ConsumerState<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

// Alias for semantic clarity
typedef CreateProfileScreen = CreatePasswordScreen;

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Profile controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+251');
  final _addressController = TextEditingController();
  DateTime? _dateOfBirth;

  // Security controllers
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _dobError;

  // Real-time password criteria
  bool get _hasMinLength => _authService.hasMinLength(_passwordController.text);
  bool get _hasUpper => _authService.hasUppercase(_passwordController.text);
  bool get _hasLower => _authService.hasLowercase(_passwordController.text);
  bool get _hasDigit => _authService.hasDigit(_passwordController.text);
  bool get _hasSpecial => _authService.hasSpecialChar(_passwordController.text);

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onFieldChanged);
    _confirmPasswordController.removeListener(_onFieldChanged);
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    // Default to 20 years ago so adult selection is convenient
    final initial = _dateOfBirth ?? DateTime(now.year - 20, now.month, now.day);
    final firstAllowed = DateTime(1900);
    final lastAllowed = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      helpText: 'SELECT DATE OF BIRTH (18+ YEARS)',
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _validateDob();
      });
    }
  }

  bool _validateDob() {
    if (_dateOfBirth == null) {
      setState(() => _dobError = 'Date of birth is required');
      return false;
    }
    final now = DateTime.now();
    if (_dateOfBirth!.isAfter(now)) {
      setState(() => _dobError = 'Date of birth cannot be in the future');
      return false;
    }
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    if (age < 18) {
      setState(() => _dobError = 'You must be at least 18 years old to register (Current age: $age)');
      return false;
    }

    setState(() => _dobError = null);
    return true;
  }

  Future<void> _handleCompleteRegistration() async {
    if (_isLoading) return;

    final isFormValid = _formKey.currentState!.validate();
    final isDobValid = _validateDob();

    if (!isFormValid || !isDobValid) {
      showAuthSnackBar(
        context,
        'Please correct the errors in the form before submitting.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _authService.completeRegistration(
        email: widget.email,
        registrationToken: widget.registrationToken,
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;

      // Save authenticated session in Riverpod auth provider and API client
      await ref.read(authNotifierProvider.notifier).setSessionFromAuthResponse(res);

      if (!mounted) return;

      showAuthSnackBar(
        context,
        'Profile created successfully! Welcome to Idir Connect.',
        isError: false,
      );

      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      showAuthSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Member Profile'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Verified Email Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EMAIL VERIFIED VIA OTP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.email,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Personal Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'First Name *',
                        hintText: 'e.g. Abebe',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) return 'First name is required';
                        if (val.length < 2 || val.length > 50) {
                          return 'First name must be between 2 and 50 characters';
                        }
                        if (!_authService.isValidName(val)) {
                          return 'Letters only (spaces and hyphens allowed)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Middle Name
                    TextFormField(
                      controller: _middleNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Middle Name (Father\'s Name) *',
                        hintText: 'e.g. Kebede',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) return 'Middle name is required';
                        if (val.length < 2 || val.length > 50) {
                          return 'Middle name must be between 2 and 50 characters';
                        }
                        if (!_authService.isValidName(val)) {
                          return 'Letters only (spaces and hyphens allowed)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Last Name (Grandfather\'s Name) *',
                        hintText: 'e.g. Bekele',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) return 'Last name is required';
                        if (val.length < 2 || val.length > 50) {
                          return 'Last name must be between 2 and 50 characters';
                        }
                        if (!_authService.isValidName(val)) {
                          return 'Letters only (spaces and hyphens allowed)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Contact & Demographics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(13),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Phone Number (Ethiopian Format) *',
                        hintText: '+251911223344 or +251711223344',
                        helperText: 'Must be exactly 13 characters starting with +2519 or +2517',
                        prefixIcon: const Icon(Icons.phone_android_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) return 'Phone number is required';
                        if (val.length != 13) {
                          return 'Phone number must be exactly 13 characters (e.g. +251911223344)';
                        }
                        if (!_authService.isValidEthiopianPhone(val)) {
                          return 'Format must start with +2519 or +2517 followed by 8 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Residential Address *',
                        hintText: 'e.g. Bole Subcity, Woreda 03, House 456, Addis Ababa',
                        prefixIcon: const Icon(Icons.home_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) return 'Address is required';
                        if (val.length < 3 || val.length > 150) {
                          return 'Address must be between 3 and 150 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Date of Birth Field
                    InkWell(
                      onTap: _isLoading ? null : () => _selectDateOfBirth(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _dobError != null
                                ? colorScheme.error
                                : colorScheme.outline,
                            width: _dobError != null ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: _dobError != null
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date of Birth *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _dobError != null
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _dateOfBirth != null
                                        ? _formatDate(_dateOfBirth!)
                                        : 'Tap to select date of birth (18+ years required)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: _dateOfBirth != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: _dateOfBirth != null
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_dobError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 6),
                        child: Text(
                          _dobError!,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    Text(
                      'Account Security',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Password (Minimum 12 Characters) *',
                        hintText: 'Enter strong password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        final pwd = value ?? '';
                        if (pwd.isEmpty) {
                          return 'Password is required';
                        }
                        if (!_authService.isPasswordStrong(pwd)) {
                          return 'Password must satisfy all criteria below (12+ characters)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Dynamic Checklist
                    _PasswordCriteriaChecklist(
                      hasMinLength: _hasMinLength,
                      hasUpper: _hasUpper,
                      hasLower: _hasLower,
                      hasDigit: _hasDigit,
                      hasSpecial: _hasSpecial,
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _handleCompleteRegistration(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        hintText: 'Re-enter your password exactly',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleCompleteRegistration,
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
                                'Complete Registration & Create Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class _PasswordCriteriaChecklist extends StatelessWidget {
  const _PasswordCriteriaChecklist({
    required this.hasMinLength,
    required this.hasUpper,
    required this.hasLower,
    required this.hasDigit,
    required this.hasSpecial,
  });

  final bool hasMinLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasDigit;
  final bool hasSpecial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Password Requirements (Enforced)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _CriterionItem(
              label: 'Minimum 12 characters',
              isSatisfied: hasMinLength,
            ),
            _CriterionItem(
              label: 'At least 1 uppercase letter (A-Z)',
              isSatisfied: hasUpper,
            ),
            _CriterionItem(
              label: 'At least 1 lowercase letter (a-z)',
              isSatisfied: hasLower,
            ),
            _CriterionItem(
              label: 'At least 1 number (0-9)',
              isSatisfied: hasDigit,
            ),
            _CriterionItem(
              label: 'At least 1 special character (!@#\$%^&*...)',
              isSatisfied: hasSpecial,
            ),
          ],
        ),
      ),
    );
  }
}

class _CriterionItem extends StatelessWidget {
  const _CriterionItem({
    required this.label,
    required this.isSatisfied,
  });

  final String label;
  final bool isSatisfied;

  @override
  Widget build(BuildContext context) {
    const successColor = Color(0xFF2E7D32);
    const failureColor = Color(0xFFC62828);
    final color = isSatisfied ? successColor : failureColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
