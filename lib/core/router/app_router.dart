import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/auth/presentation/auth_view.dart';
import '../../features/expenses/data/expense_model.dart';
import '../../features/expenses/presentation/dashboard_screen.dart';
import '../../features/expenses/presentation/expense_form_screen.dart';
import '../../features/expenses/presentation/main_shell.dart';
import '../../features/expenses/presentation/transactions_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String transactions = '/transactions';
  static const String expenseNew = '/expense/new';
  static const String expenseEdit = '/expense/edit';
  static const String profile = '/profile';
}

/// Bridges [AuthCubit], splash, and onboarding state into [GoRouter] redirects.
class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier({
    required this._authCubit,
    required bool showSplash,
    required this._hasSeenOnboarding,
  }) : _showingSplash = showSplash {
    _authSub = _authCubit.stream.listen((_) => notifyListeners());
  }

  final AuthCubit _authCubit;
  late final StreamSubscription<AuthState> _authSub;
  bool _showingSplash;
  bool _hasSeenOnboarding;

  bool get showingSplash => _showingSplash;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  AuthStatus get authStatus => _authCubit.state.status;

  void finishSplash() {
    if (!_showingSplash) return;
    _showingSplash = false;
    notifyListeners();
  }

  void completeOnboarding() {
    if (_hasSeenOnboarding) return;
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter({
  required AppRouterNotifier notifier,
  required VoidCallback onOnboardingComplete,
}) {
  return GoRouter(
    initialLocation: notifier.showingSplash
        ? AppRoutes.splash
        : AppRoutes.dashboard,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (notifier.showingSplash) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (!notifier.hasSeenOnboarding) {
        return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      final authStatus = notifier.authStatus;
      final isAuthed = authStatus == AuthStatus.authenticated;

      if (!isAuthed) {
        return loc == AppRoutes.auth ? null : AppRoutes.auth;
      }

      if (loc == AppRoutes.splash ||
          loc == AppRoutes.onboarding ||
          loc == AppRoutes.auth) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) =>
            SplashScreen(onFinished: notifier.finishSplash),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onComplete: () {
            onOnboardingComplete();
            notifier.completeOnboarding();
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthView(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => DashboardScreen(
                  onOpenTransactions: () => context.go(AppRoutes.transactions),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.expenseNew,
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const ExpenseFormScreen()),
      ),
      GoRoute(
        path: AppRoutes.expenseEdit,
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: ExpenseFormScreen(existing: state.extra as Expense?),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}

CustomTransitionPage<void> _slideUpPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
