import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../contributions/domain/models/contribution.dart';
import '../../../members/domain/models/member.dart';

enum ActivityType {
  contribution,
  reversal,
  memberJoined,
  claimSubmitted,
  announcement,
}

class DashboardActivityItem extends Equatable {
  const DashboardActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    this.amount,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final ActivityType type;
  final double? amount;

  IconData get icon {
    switch (type) {
      case ActivityType.contribution:
        return Icons.arrow_downward;
      case ActivityType.reversal:
        return Icons.undo;
      case ActivityType.memberJoined:
        return Icons.person_add_outlined;
      case ActivityType.claimSubmitted:
        return Icons.assignment_late_outlined;
      case ActivityType.announcement:
        return Icons.campaign_outlined;
    }
  }

  Color get iconColor {
    switch (type) {
      case ActivityType.contribution:
        return const Color(0xFF2E7D32); // Green
      case ActivityType.reversal:
        return const Color(0xFFC62828); // Red
      case ActivityType.memberJoined:
        return const Color(0xFF1A6B5A); // Deep Teal
      case ActivityType.claimSubmitted:
        return const Color(0xFFD4821A); // Amber
      case ActivityType.announcement:
        return const Color(0xFF1565C0); // Blue
    }
  }

  @override
  List<Object?> get props => [id, title, subtitle, timestamp, type, amount];
}

class PinnedAnnouncement extends Equatable {
  const PinnedAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.postedByName,
    required this.createdAt,
    this.isPinned = true,
  });

  final String id;
  final String title;
  final String body;
  final String category; // 'meeting', 'funeral', 'reminder', 'general'
  final String postedByName;
  final DateTime createdAt;
  final bool isPinned;

  @override
  List<Object?> get props => [id, title, body, category, postedByName, createdAt, isPinned];
}

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalFund,
    required this.collectedThisMonth,
    required this.expectedThisMonth,
    required this.totalMembersCount,
    required this.activeMembersCount,
    required this.membersInArrearsCount,
    required this.pendingClaimsCount,
    required this.recentActivities,
    this.pinnedAnnouncement,
  });

  final double totalFund;
  final double collectedThisMonth;
  final double expectedThisMonth;
  final int totalMembersCount;
  final int activeMembersCount;
  final int membersInArrearsCount;
  final int pendingClaimsCount;
  final List<DashboardActivityItem> recentActivities;
  final PinnedAnnouncement? pinnedAnnouncement;

  double get collectionProgress {
    if (expectedThisMonth <= 0) return 0.0;
    final ratio = collectedThisMonth / expectedThisMonth;
    return ratio > 1.0 ? 1.0 : (ratio < 0.0 ? 0.0 : ratio);
  }

  @override
  List<Object?> get props => [
        totalFund,
        collectedThisMonth,
        expectedThisMonth,
        totalMembersCount,
        activeMembersCount,
        membersInArrearsCount,
        pendingClaimsCount,
        recentActivities,
        pinnedAnnouncement,
      ];
}

class MemberPersonalDashboard extends Equatable {
  const MemberPersonalDashboard({
    this.member,
    required this.personalBalance,
    required this.personalArrears,
    required this.arrearsMonths,
    required this.monthlyDues,
    required this.totalPaid,
    required this.recentContributions,
    required this.pendingClaimsCount,
    this.pinnedAnnouncement,
  });

  final Member? member;
  final double personalBalance;
  final double personalArrears;
  final int arrearsMonths;
  final double monthlyDues;
  final double totalPaid;
  final List<Contribution> recentContributions;
  final int pendingClaimsCount;
  final PinnedAnnouncement? pinnedAnnouncement;

  bool get isInArrears => personalArrears > 0;
  bool get isUpToDate => personalArrears <= 0;

  @override
  List<Object?> get props => [
        member,
        personalBalance,
        personalArrears,
        arrearsMonths,
        monthlyDues,
        totalPaid,
        recentContributions,
        pendingClaimsCount,
        pinnedAnnouncement,
      ];
}
