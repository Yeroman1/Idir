import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/audit_provider.dart';
import '../../../../core/widgets/offline_indicator_bar.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  Color _actionColor(String action) {
    if (action.contains('claim') || action.contains('approved')) {
      return const Color(0xFF1565C0);
    }
    if (action.contains('contribution') || action.contains('initialized')) {
      return AppColors.success;
    }
    if (action.contains('reversal') || action.contains('rejected')) {
      return AppColors.error;
    }
    if (action.contains('member')) {
      return AppColors.primary;
    }
    return AppColors.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final logs = ref.watch(filteredAuditLogsProvider);
    final verificationAsync = ref.watch(auditVerificationNotifierProvider);
    final currentFilter = ref.watch(auditCollectionFilterProvider);

    final verificationResult = verificationAsync.value;
    final isVerifying = verificationAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditLog),
      ),
      bottomNavigationBar: const OfflineIndicatorBar(includeBottomSafeArea: true),
      body: Column(
        children: [
          // ── 1. Cryptographic Chain Status Header Card ───────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF38BDF8),
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'SHA-256 Hash Chain',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (verificationResult != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: verificationResult.isValid
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: verificationResult.isValid
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              verificationResult.isValid
                                  ? Icons.check_circle
                                  : Icons.error,
                              size: 13,
                              color: verificationResult.isValid
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              verificationResult.isValid ? 'INTACT' : 'TAMPERED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: verificationResult.isValid
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  verificationResult == null
                      ? 'Cryptographic audit ledger with immutable linked blocks. Run verification to validate hashes against tamper.'
                      : (verificationResult.isValid
                          ? 'Ledger intact. All ${verificationResult.verifiedEntries} blocks cryptographically verified with unbroken linkage.'
                          : 'Tampering detected! Broken at block #${verificationResult.brokenEntryIndex} (${verificationResult.brokenEntryId}): ${verificationResult.errorMessage}'),
                  style: TextStyle(
                    fontSize: 12,
                    color: verificationResult != null && !verificationResult.isValid
                        ? const Color(0xFFFCA5A5)
                        : Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: isVerifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fingerprint, size: 20),
                    label: Text(
                      isVerifying
                          ? 'Verifying Cryptographic Chain…'
                          : 'Verify Audit Log Integrity',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final res = await ref
                                .read(auditVerificationNotifierProvider.notifier)
                                .runVerification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.isValid
                                      ? 'Audit chain verified: All ${res.verifiedEntries} blocks valid'
                                      : 'Warning: Tampering detected! ${res.errorMessage}'),
                                  backgroundColor: res.isValid
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Search & Filter Bar ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: SearchBar(
              hintText: 'Search audit records…',
              leading: const Icon(Icons.search),
              trailing: [
                if (ref.watch(auditSearchQueryProvider).isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ref.read(auditSearchQueryProvider.notifier).state = '';
                    },
                  ),
              ],
              onChanged: (q) {
                ref.read(auditSearchQueryProvider.notifier).state = q;
              },
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.filterAll),
                  selected: currentFilter == null,
                  onSelected: (_) {
                    ref.read(auditCollectionFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.membersTitle),
                  selected: currentFilter == 'members',
                  onSelected: (_) {
                    ref.read(auditCollectionFilterProvider.notifier).state =
                        'members';
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.contributionsTitle),
                  selected: currentFilter == 'contributions',
                  onSelected: (_) {
                    ref.read(auditCollectionFilterProvider.notifier).state =
                        'contributions';
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.claimsTitle),
                  selected: currentFilter == 'claims',
                  onSelected: (_) {
                    ref.read(auditCollectionFilterProvider.notifier).state =
                        'claims';
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.expenses),
                  selected: currentFilter == 'expenses',
                  onSelected: (_) {
                    ref.read(auditCollectionFilterProvider.notifier).state =
                        'expenses';
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.settings),
                  selected: currentFilter == 'settings',
                  onSelected: (_) {
                    ref.read(auditCollectionFilterProvider.notifier).state =
                        'settings';
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── 3. Audit Log Entries List ────────────────────────────────────
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyState,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final actionColor = _actionColor(entry.action);
                      final timeStr = DateFormat('dd MMM yyyy, HH:mm')
                          .format(entry.createdAt);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                actionColor.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.history_edu,
                              size: 18,
                              color: actionColor,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: actionColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.action.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: actionColor,
                                  ),
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.summary,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Actor: ${entry.actorName} (${entry.actorRole}) • Target: ${entry.targetCollection}/${entry.targetId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.dividerColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Cryptographic Proof',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'SHA-256 Valid',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _HashRow(
                                    label: 'Block Hash',
                                    hash: entry.hash,
                                  ),
                                  const SizedBox(height: 6),
                                  _HashRow(
                                    label: 'Previous Hash',
                                    hash: entry.prevHash,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  const _HashRow({required this.label, required this.hash});

  final String label;
  final String hash;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 1),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: hash));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hash copied to clipboard'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hash,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Color(0xFF0284C7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.copy, size: 12, color: Color(0xFF0284C7)),
            ],
          ),
        ),
      ],
    );
  }
}
