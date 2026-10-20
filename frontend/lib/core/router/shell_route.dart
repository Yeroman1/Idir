import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/members/presentation/screens/members_screen.dart';
import '../../features/contributions/presentation/screens/contributions_screen.dart';
import '../../features/claims/presentation/screens/claims_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../providers/sync_status_provider.dart';
import '../widgets/offline_indicator_bar.dart';
import 'app_router.dart';

/// Bottom-nav shell wrapping the 5 main tabs.
final mainShellRoute = ShellRoute(
  builder: (context, state, child) => _ScaffoldWithBottomNav(child: child),
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.members,
      name: 'members',
      builder: (_, __) => const MembersScreen(),
    ),
    GoRoute(
      path: AppRoutes.contributions,
      name: 'contributions',
      builder: (_, __) => const ContributionsScreen(),
    ),
    GoRoute(
      path: AppRoutes.claims,
      name: 'claims',
      builder: (_, __) => const ClaimsScreen(),
    ),
    GoRoute(
      path: AppRoutes.more,
      name: 'more',
      builder: (_, __) => const MoreScreen(),
    ),
  ],
);

class _ScaffoldWithBottomNav extends ConsumerStatefulWidget {
  const _ScaffoldWithBottomNav({required this.child});
  final Widget child;

  @override
  ConsumerState<_ScaffoldWithBottomNav> createState() =>
      _ScaffoldWithBottomNavState();
}

class _ScaffoldWithBottomNavState extends ConsumerState<_ScaffoldWithBottomNav>
    with WidgetsBindingObserver {
  Timer? _periodicSyncTimer;

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.members,
    AppRoutes.contributions,
    AppRoutes.claims,
    AppRoutes.more,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial background sync on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSync();
    });

    // Periodic auto-sync every 15s to keep all screens in live sync with Supabase
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _triggerSync();
    });
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User switched back to phone after editing Supabase in browser: sync immediately!
      _triggerSync();
    }
  }

  void _triggerSync() {
    if (!mounted) return;
    ref.read(syncProvider.notifier).triggerSync();
    ref.read(authNotifierProvider.notifier).refreshCurrentUser();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final idx = _currentIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineIndicatorBar(),
          NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) {
              context.go(_tabs[i]);
              _triggerSync();
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: l10n.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: l10n.navMembers,
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: l10n.navContributions,
              ),
              NavigationDestination(
                icon: const Icon(Icons.assignment_outlined),
                selectedIcon: const Icon(Icons.assignment),
                label: l10n.navClaims,
              ),
              NavigationDestination(
                icon: const Icon(Icons.more_horiz),
                selectedIcon: const Icon(Icons.more_horiz),
                label: l10n.navMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
