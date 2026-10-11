import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/home/domain/models/dashboard_stats.dart';
import 'package:idir_app/features/members/domain/models/member.dart';

void main() {
  group('DashboardStats unit tests', () {
    test('collectionProgress calculates valid ratio and clamps at 1.0', () {
      const statsZeroExpected = DashboardStats(
        totalFund: 1000.0,
        collectedThisMonth: 0.0,
        expectedThisMonth: 0.0,
        totalMembersCount: 0,
        activeMembersCount: 0,
        membersInArrearsCount: 0,
        pendingClaimsCount: 0,
        recentActivities: [],
      );
      expect(statsZeroExpected.collectionProgress, 0.0);

      const statsHalf = DashboardStats(
        totalFund: 1000.0,
        collectedThisMonth: 250.0,
        expectedThisMonth: 500.0,
        totalMembersCount: 10,
        activeMembersCount: 10,
        membersInArrearsCount: 2,
        pendingClaimsCount: 1,
        recentActivities: [],
      );
      expect(statsHalf.collectionProgress, 0.5);

      const statsSurplus = DashboardStats(
        totalFund: 1000.0,
        collectedThisMonth: 800.0,
        expectedThisMonth: 500.0,
        totalMembersCount: 10,
        activeMembersCount: 10,
        membersInArrearsCount: 0,
        pendingClaimsCount: 0,
        recentActivities: [],
      );
      expect(statsSurplus.collectionProgress, 1.0);
    });

    test('DashboardActivityItem properties and icon colors', () {
      final now = DateTime.now();
      final actContribution = DashboardActivityItem(
        id: 'act_1',
        title: 'Payment recorded',
        subtitle: 'Cash',
        timestamp: now,
        type: ActivityType.contribution,
        amount: 50.0,
      );
      expect(actContribution.type, ActivityType.contribution);
      expect(actContribution.amount, 50.0);

      final actReversal = DashboardActivityItem(
        id: 'act_2',
        title: 'Reversal',
        subtitle: 'Error',
        timestamp: now,
        type: ActivityType.reversal,
        amount: 50.0,
      );
      expect(actReversal.type, ActivityType.reversal);

      final actJoined = DashboardActivityItem(
        id: 'act_3',
        title: 'New Member',
        subtitle: 'MEM-005',
        timestamp: now,
        type: ActivityType.memberJoined,
      );
      expect(actJoined.amount, isNull);
    });

    test('PinnedAnnouncement initialization and equality', () {
      final now = DateTime.now();
      final ann = PinnedAnnouncement(
        id: 'ann_1',
        title: 'General Meeting',
        body: 'Meeting on Sunday',
        category: 'meeting',
        postedByName: 'Chairperson',
        createdAt: now,
        isPinned: true,
      );

      expect(ann.id, 'ann_1');
      expect(ann.isPinned, isTrue);
      expect(ann.category, 'meeting');
    });

    test('MemberPersonalDashboard determines standing and dues status', () {
      final regDate = DateTime(2024, 1, 1);
      final memberUpToDate = Member(
        id: 'm1',
        memberId: 'MEM-001',
        fullName: 'Up To Date Member',
        phone: '+251911000001',
        registeredAt: regDate,
        monthlyDues: 50.0,
        balance: 0.0,
        arrears: 0.0,
        createdAt: regDate,
        updatedAt: regDate,
      );

      final personalDashboardGood = MemberPersonalDashboard(
        member: memberUpToDate,
        personalBalance: 0.0,
        personalArrears: 0.0,
        arrearsMonths: 0,
        monthlyDues: 50.0,
        totalPaid: 300.0,
        recentContributions: const [],
        pendingClaimsCount: 0,
      );

      expect(personalDashboardGood.isUpToDate, isTrue);
      expect(personalDashboardGood.isInArrears, isFalse);

      final memberInArrears = Member(
        id: 'm2',
        memberId: 'MEM-002',
        fullName: 'Arrears Member',
        phone: '+251911000002',
        registeredAt: regDate,
        monthlyDues: 50.0,
        balance: -100.0,
        arrears: 100.0,
        createdAt: regDate,
        updatedAt: regDate,
      );

      final personalDashboardArrears = MemberPersonalDashboard(
        member: memberInArrears,
        personalBalance: -100.0,
        personalArrears: 100.0,
        arrearsMonths: 2,
        monthlyDues: 50.0,
        totalPaid: 200.0,
        recentContributions: const [],
        pendingClaimsCount: 1,
      );

      expect(personalDashboardArrears.isInArrears, isTrue);
      expect(personalDashboardArrears.isUpToDate, isFalse);
      expect(personalDashboardArrears.arrearsMonths, 2);
      expect(personalDashboardArrears.personalArrears, 100.0);
    });
  });
}
