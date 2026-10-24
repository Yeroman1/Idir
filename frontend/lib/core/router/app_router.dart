import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/account_screen.dart';
import '../../features/supabase_auth/screens/login_screen.dart';
import '../../features/supabase_auth/screens/create_password_screen.dart';
import '../../features/supabase_auth/screens/home_screen.dart' as supabase_auth;
import '../../features/supabase_auth/screens/otp_verification_screen.dart';
import '../../features/supabase_auth/screens/registration_screen.dart';
import '../../features/auth/presentation/screens/pin_screen.dart';
import '../../features/audit/presentation/screens/audit_log_screen.dart';
import '../../features/announcements/presentation/screens/announcements_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/members/presentation/screens/member_detail_screen.dart';
import '../../features/members/presentation/screens/member_form_screen.dart';
import '../../features/idirs/presentation/screens/create_idir_screen.dart';
import '../../features/invitations/presentation/screens/public_invitation_screen.dart';
import '../../features/elections/presentation/screens/create_election_screen.dart';
import '../../features/elections/presentation/screens/elections_dashboard_screen.dart';
import '../models/app_user.dart';
import '../providers/pin_provider.dart';
import '../widgets/access_denied_screen.dart';
import 'shell_route.dart';

export 'shell_route.dart';

/// Listenable that notifies GoRouter whenever auth or PIN state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
    ref.listen(pinNotifierProvider, (_, __) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  return _RouterRefreshNotifier(ref);
});

/// Global router provider with institutional role guards and PIN lock enforcement.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final pin = ref.read(pinNotifierProvider);

      if (auth.isLoading || pin.isLoading) {
        return null;
      }

      final loc = state.matchedLocation;
      final isAuthenticated = auth.isAuthenticated;

      // ── 1. Unauthenticated users must stay on Login ────────────────────
      if (!isAuthenticated) {
        if (loc == AppRoutes.login ||
            loc.startsWith(AppRoutes.invitation) ||
            _isAuthRoute(loc)) {
          return null;
        }
        return AppRoutes.login;
      }

      // ── 2. Authenticated user attempting to visit Login ────────────────
      if (loc == AppRoutes.login || loc == '/supabase-login') {
        if (pin.isSet && !pin.isUnlocked) {
          return AppRoutes.pin;
        }
        return AppRoutes.home;
      }

      // ── 3. PIN Lock enforcement ────────────────────────────────────────
      if (pin.isSet && !pin.isUnlocked) {
        return loc == AppRoutes.pin ? null : AppRoutes.pin;
      }

      // If unlocked, don't stay on lock screen
      if (loc == AppRoutes.pin && pin.isUnlocked) {
        return AppRoutes.home;
      }

      // ── 4. Role-Based Role Guards ─────────────────────────────────────
      final user = auth.user!;
      if (loc == AppRoutes.auditLog && !user.role.canViewAuditLog) {
        return AppRoutes.accessDenied;
      }
      if (loc == AppRoutes.settings && !user.role.canChangeSettings) {
        return AppRoutes.accessDenied;
      }
      if ((loc == AppRoutes.reports || loc == AppRoutes.expenses) &&
          !user.role.canViewAllFinances) {
        return AppRoutes.accessDenied;
      }
      if ((loc.startsWith('${AppRoutes.members}/add') ||
              loc.startsWith('${AppRoutes.members}/edit')) &&
          !user.role.canManageMembers) {
        return AppRoutes.accessDenied;
      }
      if (loc == AppRoutes.createElection && !user.role.canManageElections) {
        return AppRoutes.accessDenied;
      }

      return null;
    },
    routes: [
      // ── Auth & Security ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/supabase-login',
        redirect: (_, __) => AppRoutes.login,
      ),
      GoRoute(
        path: AppRoutes.pin,
        name: 'pin',
        builder: (_, __) => const PinScreen(mode: PinMode.unlock),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        name: 'pinSetup',
        builder: (_, __) => const PinScreen(mode: PinMode.setup),
      ),
      GoRoute(
        path: AppRoutes.pinChange,
        name: 'pinChange',
        builder: (_, __) => const PinScreen(mode: PinMode.change),
      ),
      GoRoute(
        path: AppRoutes.accessDenied,
        name: 'accessDenied',
        builder: (_, __) => const AccessDeniedScreen(),
      ),
      GoRoute(
        path: AppRoutes.account,
        name: 'account',
        builder: (_, __) => const AccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.invitation,
        name: 'invitation',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return PublicInvitationScreen(token: token);
        },
      ),

      // ── Members Detail & Management Subroutes ──────────────────────────
      GoRoute(
        path: '${AppRoutes.members}/detail/:id',
        name: 'memberDetail',
        builder: (context, state) => MemberDetailScreen(
          memberId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.members}/add',
        name: 'addMember',
        builder: (_, __) => const MemberFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.members}/edit/:id',
        name: 'editMember',
        builder: (context, state) => MemberFormScreen(
          editMemberId: state.pathParameters['id'],
        ),
      ),

      // ── Feature Subroutes ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.announcements,
        name: 'announcements',
        builder: (_, __) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.expenses,
        name: 'expenses',
        builder: (_, __) => const ExpensesScreen(),
      ),
      GoRoute(
        path: AppRoutes.auditLog,
        name: 'auditLog',
        builder: (_, __) => const AuditLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createIdir,
        name: 'createIdir',
        builder: (_, __) => const CreateIdirScreen(),
      ),
      GoRoute(
        path: AppRoutes.elections,
        name: 'elections',
        builder: (_, __) => const ElectionsDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.createElection,
        name: 'createElection',
        builder: (_, __) => const CreateElectionScreen(),
      ),

      // ── Supabase Email Auth Routes ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.supabaseRegister,
        name: 'supabaseRegister',
        builder: (_, __) => const RegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.supabaseVerifyOtp,
        name: 'supabaseVerifyOtp',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.supabaseCreatePassword,
        name: 'supabaseCreatePassword',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final token = state.uri.queryParameters['token'] ?? '';
          return CreatePasswordScreen(email: email, registrationToken: token);
        },
      ),
      GoRoute(
        path: AppRoutes.supabaseHome,
        name: 'supabaseHome',
        builder: (_, __) => const supabase_auth.HomeScreen(),
      ),

      // ── Shell (Bottom Navigation Tabs) ──────────────────────────────────
      mainShellRoute,
    ],
    errorBuilder: (context, state) => _ErrorScreen(state.error),
  );
});

bool _isAuthRoute(String loc) {
  return loc == AppRoutes.login ||
      loc == '/supabase-login' ||
      loc == AppRoutes.supabaseRegister ||
      loc.startsWith(AppRoutes.supabaseVerifyOtp) ||
      loc.startsWith(AppRoutes.supabaseCreatePassword) ||
      loc == AppRoutes.supabaseHome;
}

// ─── Error screen ─────────────────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen(this.error);
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Text(
          error?.toString() ?? 'Unknown error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Route path constants — single source of truth.
abstract final class AppRoutes {
  static const login = '/login';
  static const pin = '/pin';
  static const pinSetup = '/pin-setup';
  static const pinChange = '/pin-change';
  static const accessDenied = '/access-denied';
  static const account = '/account';

  // Supabase Auth routes
  static const supabaseLogin = '/login';
  static const supabaseRegister = '/supabase-register';
  static const supabaseVerifyOtp = '/supabase-verify-otp';
  static const supabaseCreatePassword = '/supabase-create-password';
  static const supabaseHome = '/supabase-home';

  // Bottom navigation tabs
  static const home = '/home';
  static const members = '/members';
  static const membersAdd = '/members/add';
  static const contributions = '/contributions';
  static const claims = '/claims';
  static const more = '/more';

  // Feature pages
  static const createIdir = '/create-idir';
  static const invitation = '/invitation';
  static const announcements = '/announcements';
  static const reports = '/reports';
  static const expenses = '/expenses';
  static const auditLog = '/audit-log';
  static const settings = '/settings';
  static const elections = '/elections';
  static const createElection = '/elections/create';
}
