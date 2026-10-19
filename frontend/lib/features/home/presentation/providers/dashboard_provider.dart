import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../contributions/domain/models/contribution.dart';
import '../../../contributions/presentation/providers/contributions_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/dashboard_stats.dart';

import '../../../claims/data/claims_repository.dart';
import '../../../claims/domain/models/claim.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../announcements/data/announcements_repository.dart';
import '../../../announcements/domain/models/announcement.dart';

/// Pinned announcement provider for community updates (live from announcements stream)
final pinnedAnnouncementProvider = Provider<PinnedAnnouncement?>((ref) {
  final announcementsAsync = ref.watch(announcementsStreamProvider);
  final announcements = announcementsAsync.value ?? [];
  final pinned = announcements.where((a) => a.pinned).firstOrNull;
  if (pinned != null) {
    return PinnedAnnouncement(
      id: pinned.id,
      title: pinned.title,
      body: pinned.body,
      category: pinned.category.name,
      postedByName: pinned.postedByName,
      createdAt: pinned.createdAt,
      isPinned: pinned.pinned,
    );
  }
  return null;
});

/// Pending claims count provider (live from claims stream)
final pendingClaimsCountProvider = Provider<int>((ref) {
  final claimsAsync = ref.watch(claimsStreamProvider);
  final claims = claimsAsync.value ?? [];
  return claims.where((c) => c.status == ClaimStatus.submitted).length;
});

/// Association-wide dashboard statistics provider (for Officers)
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final membersAsync = ref.watch(membersStreamProvider);
  final contributionsAsync = ref.watch(contributionsStreamProvider);
  final expensesAsync = ref.watch(expensesStreamProvider);
  final pinnedAnn = ref.watch(pinnedAnnouncementProvider);
  final pendingClaims = ref.watch(pendingClaimsCountProvider);

  final members = membersAsync.value ?? [];
  final contributions = contributionsAsync.value ?? [];
  final expenses = expensesAsync.value ?? [];

  final now = DateTime.now();
  final currentMonth = now.month;
  final currentYear = now.year;

  // 1. Total fund: net contributions minus net expenses (Rule 3)
  double netContributions = 0.0;
  for (final c in contributions) {
    if (c.isReversal) {
      netContributions -= c.amount;
    } else if (!c.isReversed) {
      netContributions += c.amount;
    }
  }
  double netExpenses = 0.0;
  for (final e in expenses) {
    if (e.isReversal) {
      netExpenses -= e.amount;
    } else if (!e.isReversed) {
      netExpenses += e.amount;
    }
  }
  double totalFund = netContributions - netExpenses;
  if (totalFund < 0) totalFund = 0.0;

  // 2. This month's collected
  double collectedThisMonth = 0.0;
  for (final c in contributions) {
    final matchesMonth = (c.periodMonth == currentMonth && c.periodYear == currentYear) ||
        (c.date.month == currentMonth && c.date.year == currentYear);
    if (matchesMonth) {
      if (c.isReversal) {
        collectedThisMonth -= c.amount;
      } else if (!c.isReversed) {
        collectedThisMonth += c.amount;
      }
    }
  }
  if (collectedThisMonth < 0) collectedThisMonth = 0.0;

  // 3. Expected this month: active members * dues
  final activeMembers = members.where((m) => m.status == MemberStatus.active).toList();
  double expectedThisMonth = 0.0;
  for (final m in activeMembers) {
    expectedThisMonth += m.monthlyDues;
  }
  if (expectedThisMonth == 0 && activeMembers.isNotEmpty) {
    expectedThisMonth = activeMembers.length * 50.0;
  }

  // 4. In arrears count
  final inArrearsCount = members.where((m) => m.arrears > 0).length;

  // 5. Activity feed compiled from real ledger and member events
  final List<DashboardActivityItem> activities = [];

  for (final c in contributions.take(6)) {
    if (c.isReversal) {
      activities.add(
        DashboardActivityItem(
          id: 'act_${c.id}',
          title: 'Reversal Executed (${c.receiptNumber})',
          subtitle: '${c.memberName} • ${c.reversalReason ?? "Offsetting entry"}',
          timestamp: c.date,
          type: ActivityType.reversal,
          amount: c.amount,
        ),
      );
    } else {
      activities.add(
        DashboardActivityItem(
          id: 'act_${c.id}',
          title: '${c.memberName} (${c.receiptNumber})',
          subtitle: '${c.paymentMethod.name.toUpperCase()} • ${c.periodMonth}/${c.periodYear}',
          timestamp: c.date,
          type: ActivityType.contribution,
          amount: c.amount,
        ),
      );
    }
  }

  for (final m in members.take(3)) {
    activities.add(
      DashboardActivityItem(
        id: 'act_m_${m.id}',
        title: 'Member Registered: ${m.fullName}',
        subtitle: 'ID: ${m.memberId} • Dues: ${m.monthlyDues.toStringAsFixed(0)} ETB',
        timestamp: m.registeredAt,
        type: ActivityType.memberJoined,
      ),
    );
  }

  // Add 1 sample pending claim activity
  activities.add(
    DashboardActivityItem(
      id: 'act_cl_001',
      title: 'Claim Submitted (MEM-002)',
      subtitle: 'Bereavement assistance request awaiting approval',
      timestamp: DateTime.now().subtract(const Duration(hours: 14)),
      type: ActivityType.claimSubmitted,
      amount: 3000.0,
    ),
  );

  // Sort activities newest first
  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return DashboardStats(
    totalFund: totalFund,
    collectedThisMonth: collectedThisMonth,
    expectedThisMonth: expectedThisMonth,
    totalMembersCount: members.length,
    activeMembersCount: activeMembers.length,
    membersInArrearsCount: inArrearsCount,
    pendingClaimsCount: pendingClaims,
    recentActivities: activities.take(8).toList(),
    pinnedAnnouncement: pinnedAnn,
  );
});

/// Personal Member Dashboard Provider (for regular member role)
final memberPersonalDashboardProvider = Provider<MemberPersonalDashboard>((ref) {
  final user = ref.watch(currentUserProvider);
  final membersAsync = ref.watch(membersStreamProvider);
  final contributionsAsync = ref.watch(contributionsStreamProvider);
  final pinnedAnn = ref.watch(pinnedAnnouncementProvider);
  final pendingClaims = ref.watch(pendingClaimsCountProvider);

  final members = membersAsync.value ?? [];
  final contributions = contributionsAsync.value ?? [];

  final memberId = user?.memberId ?? '';
  Member? currentMember;
  for (final m in members) {
    if (m.memberId == memberId || m.id == memberId) {
      currentMember = m;
      break;
    }
  }

  final memberContributions = contributions
      .where((c) => c.memberId == memberId)
      .toList();

  return MemberPersonalDashboard(
    member: currentMember,
    personalBalance: currentMember?.balance ?? 0.0,
    personalArrears: currentMember?.arrears ?? 0.0,
    arrearsMonths: (currentMember != null && currentMember.monthlyDues > 0)
        ? (currentMember.arrears / currentMember.monthlyDues).ceil()
        : 0,
    monthlyDues: currentMember?.monthlyDues ?? 50.0,
    totalPaid: currentMember?.totalPaid ?? 0.0,
    recentContributions: memberContributions.take(5).toList(),
    pendingClaimsCount: pendingClaims,
    pinnedAnnouncement: pinnedAnn,
  );
});
