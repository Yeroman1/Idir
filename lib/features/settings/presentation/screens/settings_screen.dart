import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/pin_provider.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_indicator_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─── Settings Providers ────────────────────────────────────────────────────────

final _monthlyDuesProvider =
    StateNotifierProvider<_MonthlyDuesNotifier, double>((ref) {
  return _MonthlyDuesNotifier();
});

class _MonthlyDuesNotifier extends StateNotifier<double> {
  _MonthlyDuesNotifier() : super(AppConstants.defaultMonthlyDues) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('monthly_dues') ?? AppConstants.defaultMonthlyDues;
  }

  Future<void> setDues(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_dues', value);
    state = value;
  }
}

final _associationNameProvider =
    StateNotifierProvider<_AssociationNameNotifier, String>((ref) {
  return _AssociationNameNotifier();
});

class _AssociationNameNotifier extends StateNotifier<String> {
  _AssociationNameNotifier() : super('Tinsae Mutual Aid Association') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('association_name') ??
        'Tinsae Mutual Aid Association';
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('association_name', name);
    state = name;
  }
}

// ─── Settings Screen ───────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _duesController = TextEditingController();
  final _nameController = TextEditingController();

  bool _smsAlertsEnabled = true;
  bool _claimAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    final dues = ref.read(_monthlyDuesProvider);
    final assocName = ref.read(_associationNameProvider);
    _duesController.text = dues.toStringAsFixed(0);
    _nameController.text = assocName;
  }

  @override
  void dispose() {
    _duesController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showChangeDuesDialog() {
    final currentDues = ref.read(_monthlyDuesProvider);
    _duesController.text = currentDues.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payments_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Edit Monthly Dues'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sets the standard baseline monthly dues rate for all members in the iddir ledger.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _duesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (ETB)',
                prefixText: 'ETB ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_duesController.text);
              if (val != null && val > 0) {
                ref.read(_monthlyDuesProvider.notifier).setDues(val);
                Navigator.pop(ctx);
                _showSnack('Default monthly dues updated to ETB ${val.toStringAsFixed(0)}');
              } else {
                _showSnack('Please enter a valid amount', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangeNameDialog() {
    final current = ref.read(_associationNameProvider);
    _nameController.text = current;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.business_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Edit Association Name'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Displayed on official PDF reports, certificates, and app headers.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Association Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _nameController.text.trim();
              if (text.isNotEmpty) {
                ref.read(_associationNameProvider.notifier).setName(text);
                Navigator.pop(ctx);
                _showSnack('Association name updated to "$text"');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBylawsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Rule 3 Mutual Aid Bylaws'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tinsae Mutual Aid Institutional Constitution',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '1. Multi-Officer Authorization Principle:\n'
                'No bereavement benefit or emergency claim may be disbursed without concurring authorization from both Chairperson (ሰብሳቢ) and Treasurer (ገንዘብ ያዥ).\n\n'
                '2. Rule 3 Solvency Equation:\n'
                'The Reserve Fund balance is perpetually verified as:\n'
                'Closing Balance = Opening Reserve + Dues Collected - Claims Disbursed - Verified Operating Expenses.\n\n'
                '3. Grace Period & Default Rules:\n'
                'Members enjoy a 30-day grace window. Failure to contribute for 3 consecutive months places the member in defaulting status, suspending claim eligibility until arrears are settled.\n\n'
                '4. Immutable Audit Trail:\n'
                'Every receipt issued, claim decision, and setting adjustment is recorded immutably in the association audit log.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Reset Application'),
          ],
        ),
        content: const Text(
          'This will clear local cache and preferences, then sign you out. '
          'Cloud records remain safely preserved. Continue?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await ref.read(authNotifierProvider.notifier).signOut();
              if (ctx.mounted) {
                ctx.go(AppRoutes.login);
              }
            },
            child: const Text('Reset & Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final pinState = ref.watch(pinNotifierProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final monthlyDues = ref.watch(_monthlyDuesProvider);
    final assocName = ref.watch(_associationNameProvider);
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Section: Association Configuration ────────────────────────────
          const _SectionHeader(
            icon: Icons.business_outlined,
            label: 'Association & Bylaws',
            color: AppColors.primary,
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: _iconBox(Icons.groups_outlined, AppColors.primary),
                title: const Text(
                  'Association Name',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  assocName,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: _showChangeNameDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _iconBox(Icons.payments_outlined, AppColors.secondary),
                title: const Text(
                  'Default Monthly Dues',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'ETB ${monthlyDues.toStringAsFixed(0)} per member / month',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: _showChangeDuesDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              const _InfoTile(
                label: 'Required Claim Approvals',
                value: '2 approvals (Chairperson + Treasurer required)',
                icon: Icons.how_to_vote_outlined,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _iconBox(Icons.gavel_outlined, AppColors.primary),
                title: const Text(
                  'Rule 3 Mutual Aid Constitution',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Review traditional reserve fund & signatory rules',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showBylawsDialog,
              ),
            ],
          ),

          // ── Section: Offline & Cloud Synchronization ──────────────────────
          const _SectionHeader(
            icon: Icons.cloud_sync_outlined,
            label: 'Offline & Cloud Sync',
            color: AppColors.secondary,
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: _iconBox(
                  syncState.isOffline
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  syncState.isOffline ? AppColors.warning : AppColors.success,
                ),
                title: Text(
                  syncState.isOffline ? 'Offline Mode Active' : 'Cloud Synchronized',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  syncState.pendingCount > 0
                      ? '${syncState.pendingCount} offline changes pending cloud sync'
                      : 'All records backed up to cloud ledger',
                  style: TextStyle(
                    fontSize: 12,
                    color: syncState.pendingCount > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
                trailing: TextButton.icon(
                  icon: syncState.isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(syncState.isSyncing ? 'Syncing…' : 'Sync Now'),
                  onPressed: syncState.isSyncing
                      ? null
                      : () async {
                          await ref.read(syncProvider.notifier).triggerSync();
                          _showSnack('All offline changes synchronized!');
                        },
                ),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: _iconBox(Icons.wifi_off_outlined, AppColors.secondary),
                title: const Text(
                  'Simulate Field Offline Mode',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Buffer contributions and claims locally without internet',
                  style: TextStyle(fontSize: 12),
                ),
                value: syncState.isOfflineSimulated,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  ref.read(syncProvider.notifier).toggleOffline();
                  _showSnack(
                    val
                        ? 'Offline field mode enabled. Changes queued locally.'
                        : 'Reconnected! Cloud sync triggered.',
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _iconBox(Icons.analytics_outlined, AppColors.info),
                title: const Text(
                  'Sync Diagnostics & Queue Manager',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'View ${syncState.pendingCount} queued records and cloud status',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showOfflineSyncModal(context),
              ),
            ],
          ),

          // ── Section: Security ─────────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.security_outlined,
            label: 'Security & PIN',
            color: AppColors.info,
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: _iconBox(Icons.lock_outline, AppColors.info),
                title: Text(
                  pinState.isSet ? l10n.changePin : l10n.pinSetupTitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  pinState.isSet
                      ? '4-Digit PIN lock is active'
                      : 'PIN lock is disabled — tap to enable',
                  style: TextStyle(
                    fontSize: 12,
                    color: pinState.isSet
                        ? AppColors.success
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push(
                    pinState.isSet ? AppRoutes.pinChange : AppRoutes.pinSetup,
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              const _InfoTile(
                label: 'Session Inactivity Lock',
                value: '2 minutes of inactivity forces PIN re-entry',
                icon: Icons.timer_outlined,
              ),
              const Divider(height: 1, indent: 56),
              const _InfoTile(
                label: 'Maximum PIN Attempts',
                value: '5 consecutive failed attempts causes lockout',
                icon: Icons.pin_outlined,
              ),
            ],
          ),

          // ── Section: Appearance & Theme ───────────────────────────────────
          const _SectionHeader(
            icon: Icons.palette_outlined,
            label: 'Visual Theme & Appearance',
            color: Color(0xFF6366F1),
          ),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Theme Mode',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose how the Idir app interface appears',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeOptionCard(
                            title: 'System',
                            subtitle: 'Adaptive',
                            icon: Icons.brightness_auto,
                            isSelected: themeMode == ThemeMode.system,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setMode(ThemeMode.system),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeOptionCard(
                            title: 'Light',
                            subtitle: 'Emerald',
                            icon: Icons.light_mode,
                            isSelected: themeMode == ThemeMode.light,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeOptionCard(
                            title: 'Dark',
                            subtitle: 'Obsidian',
                            icon: Icons.dark_mode,
                            isSelected: themeMode == ThemeMode.dark,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setMode(ThemeMode.dark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Section: App Preferences & Language ───────────────────────────
          const _SectionHeader(
            icon: Icons.tune_outlined,
            label: 'Language & Notifications',
            color: AppColors.warning,
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: _iconBox(Icons.language_outlined, AppColors.warning),
                title: const Text(
                  'Language / ቋንቋ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _localeName(locale),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: DropdownButton<Locale>(
                  value: locale,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: Locale('am'),
                      child: Text('አማርኛ (Amharic)'),
                    ),
                    DropdownMenuItem(
                      value: Locale('om'),
                      child: Text('Afaan Oromoo'),
                    ),
                  ],
                  onChanged: (loc) {
                    if (loc != null) {
                      ref.read(localeProvider.notifier).setLocale(loc);
                    }
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: _iconBox(Icons.sms_outlined, AppColors.warning),
                title: const Text(
                  'SMS Receipt Reminders',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Simulate automatic SMS confirmation on dues receipt recording',
                  style: TextStyle(fontSize: 12),
                ),
                value: _smsAlertsEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _smsAlertsEnabled = val);
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: _iconBox(Icons.notifications_active_outlined, AppColors.warning),
                title: const Text(
                  'Claim Status Updates',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Notify officers upon claim submission or approval',
                  style: TextStyle(fontSize: 12),
                ),
                value: _claimAlertsEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _claimAlertsEnabled = val);
                },
              ),
            ],
          ),

          // ── Section: User Management ──────────────────────────────────────
          const _SectionHeader(
            icon: Icons.manage_accounts_outlined,
            label: 'User & Permissions',
            color: AppColors.primary,
          ),
          _SettingsCard(
            children: [
              _InfoTile(
                label: 'Signed In As',
                value: user?.name ?? '—',
                icon: Icons.person_outline,
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                label: 'Current Institutional Role',
                value: _roleLabel(user?.role, l10n),
                icon: Icons.badge_outlined,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _iconBox(Icons.people_alt_outlined, AppColors.primary),
                title: const Text(
                  'Role Permissions Matrix',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Inspect permissions for Chairperson, Treasurer, Auditor & Member',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRolePermissionsSheet(context, l10n),
              ),
            ],
          ),

          // ── Section: Danger Zone ──────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.warning_amber_outlined,
            label: 'Data & Maintenance',
            color: AppColors.error,
          ),
          _SettingsCard(
            children: [
              ListTile(
                leading: _iconBox(Icons.refresh, AppColors.error),
                title: const Text(
                  'Reset Local App State',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                subtitle: const Text(
                  'Clear local preferences, cache, and sign out',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showResetDialog(context),
              ),
            ],
          ),

          // ── Version Info ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 34,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  assocName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Idir Management System • Version 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Compliant with Ethiopian Mutual-Aid Bylaws Rule 3',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _roleLabel(UserRole? role, AppLocalizations l10n) {
    return switch (role) {
      UserRole.chairperson => l10n.roleChairperson,
      UserRole.treasurer => l10n.roleTreasurer,
      UserRole.auditor => l10n.roleAuditor,
      _ => l10n.roleMember,
    };
  }

  String _localeName(Locale? locale) => switch (locale?.languageCode) {
        'am' => 'አማርኛ (Amharic)',
        'om' => 'Afaan Oromoo',
        _ => 'English',
      };

  void _showRolePermissionsSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Institutional Role Matrix',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Powers and access limits defined by association bylaws',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  _RolePermissionsCard(
                    role: l10n.roleChairperson,
                    icon: Icons.star,
                    color: AppColors.primary,
                    permissions: const [
                      'Manage members (add/edit/delete/status)',
                      'Approve or reject bereavement & emergency claims',
                      'View all financial data and fiscal reports',
                      'Inspect immutable audit logs',
                      'Post community announcements',
                      'Modify association configuration and bylaws',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RolePermissionsCard(
                    role: l10n.roleTreasurer,
                    icon: Icons.account_balance,
                    color: AppColors.secondary,
                    permissions: const [
                      'Record monthly dues contributions & issue receipts',
                      'Record authorized operating expenses',
                      'Approve or reject submitted claims',
                      'Record claim financial payouts',
                      'Manage members roster',
                      'View all financial sheets and arrears register',
                      'Post community announcements',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RolePermissionsCard(
                    role: l10n.roleAuditor,
                    icon: Icons.policy,
                    color: const Color(0xFF1565C0),
                    permissions: const [
                      'Full view-only inspection of all financial books',
                      'Inspect immutable audit logs & transaction history',
                      'Verify Rule 3 Reserve Fund solvency equation',
                      'Cannot create, edit, or reverse financial entries',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RolePermissionsCard(
                    role: l10n.roleMember,
                    icon: Icons.person,
                    color: const Color(0xFF4E7D6B),
                    permissions: const [
                      'View personal contribution history and receipts',
                      'View personal standing (Good Standing / Arrears / Prepaid)',
                      'Submit bereavement & emergency claims',
                      'Read community announcements',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme Option Card ─────────────────────────────────────────────────────────

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _RolePermissionsCard extends StatelessWidget {
  const _RolePermissionsCard({
    required this.role,
    required this.icon,
    required this.color,
    required this.permissions,
  });

  final String role;
  final IconData icon;
  final Color color;
  final List<String> permissions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                role,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...permissions.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 15, color: color.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
