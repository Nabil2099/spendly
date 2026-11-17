import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/auth/presentation/auth_view.dart';
import 'features/budget/data/budget_repository.dart';
import 'features/currency/data/exchange_rate_service.dart';
import 'features/expenses/data/expense_model.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/expenses/presentation/expense_cubit.dart';
import 'features/expenses/presentation/main_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/profile_cubit.dart';

/// Root Spendly application widget.
class SpendlyApp extends StatefulWidget {
  const SpendlyApp({
    super.key,
    required this.isFirebaseConfigured,
    this.authRepository,
    this.expenseRepository,
    this.budgetRepository,
    this.profileRepository,
    this.exchangeRateService,
    this.preferencesService,
    this.showSplash = true,
  });

  final bool isFirebaseConfigured;
  final AuthRepository? authRepository;
  final ExpenseRepository? expenseRepository;
  final BudgetRepository? budgetRepository;
  final ProfileRepository? profileRepository;
  final ExchangeRateService? exchangeRateService;
  final PreferencesService? preferencesService;
  final bool showSplash;

  @override
  State<SpendlyApp> createState() => _SpendlyAppState();
}

class _SpendlyAppState extends State<SpendlyApp> {
  late bool _showingSplash;
  late bool _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _showingSplash = widget.showSplash;
    _hasSeenOnboarding =
        widget.preferencesService?.getHasSeenOnboarding() ?? true;
  }

  void _completeOnboarding() {
    widget.preferencesService?.setHasSeenOnboarding(true);
    setState(() => _hasSeenOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedAuthRepo =
        widget.authRepository ??
        (widget.isFirebaseConfigured ? FirebaseAuthRepository() : null);
    final resolvedExpenseRepo =
        widget.expenseRepository ??
        (widget.isFirebaseConfigured
            ? FirestoreExpenseRepository()
            : _NoopExpenseRepository());
    final resolvedBudgetRepo =
        widget.budgetRepository ??
        (widget.isFirebaseConfigured
            ? FirestoreBudgetRepository()
            : _NoopBudgetRepository());
    final resolvedProfileRepo =
        widget.profileRepository ??
        (widget.isFirebaseConfigured
            ? FirestoreProfileRepository()
            : _NoopProfileRepository());

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ThemeCubit(preferencesService: widget.preferencesService),
        ),
        BlocProvider(
          create: (_) => AuthCubit(
            repository: resolvedAuthRepo,
            isFirebaseConfigured: widget.isFirebaseConfigured,
          ),
        ),
        BlocProvider(
          create: (context) {
            final cubit = ExpenseCubit(
              expenseRepository: resolvedExpenseRepo,
              budgetRepository: resolvedBudgetRepo,
              exchangeRateService:
                  widget.exchangeRateService ?? ExchangeRateService(),
              preferencesService: widget.preferencesService,
            );
            final initialUid = context.read<AuthCubit>().state.user?.uid;
            if (initialUid != null) {
              cubit.bindUser(initialUid);
            }
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) {
            final cubit = ProfileCubit(repository: resolvedProfileRepo);
            final initialUid = context.read<AuthCubit>().state.user?.uid;
            if (initialUid != null) {
              cubit.bindUser(initialUid);
            }
            return cubit;
          },
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'Spendly',
            debugShowCheckedModeBanner: false,
            theme: buildSpendlyTheme(),
            darkTheme: buildSpendlyDarkTheme(),
            themeMode: themeMode,
            home: BlocListener<AuthCubit, AuthState>(
              listenWhen: (prev, curr) => prev.user?.uid != curr.user?.uid,
              listener: (context, state) {
                final uid = state.user?.uid;
                context.read<ExpenseCubit>().bindUser(uid);
                context.read<ProfileCubit>().bindUser(uid);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildRootView(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRootView() {
    if (_showingSplash) {
      return SplashScreen(
        key: const ValueKey('splash'),
        onFinished: () {
          if (mounted) setState(() => _showingSplash = false);
        },
      );
    }

    if (!_hasSeenOnboarding) {
      return OnboardingScreen(
        key: const ValueKey('onboarding'),
        onComplete: _completeOnboarding,
      );
    }

    return BlocBuilder<AuthCubit, AuthState>(
      key: const ValueKey('auth_gate'),
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const MainShell();
          case AuthStatus.unauthenticated:
          case AuthStatus.unconfigured:
            return const AuthView();
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}

class _NoopExpenseRepository implements ExpenseRepository {
  @override
  Stream<List<Expense>> watchExpenses(String uid) => const Stream.empty();

  @override
  Future<void> addExpense(String uid, Expense expense) async {}

  @override
  Future<void> updateExpense(String uid, Expense expense) async {}

  @override
  Future<void> deleteExpense(String uid, String expenseId) async {}
}

class _NoopBudgetRepository implements BudgetRepository {
  @override
  Stream<MonthlyBudget?> watchBudget(String uid, String monthKey) =>
      const Stream.empty();

  @override
  Future<void> setBudget(String uid, String monthKey, int limitMinor) async {}
}

class _NoopProfileRepository implements ProfileRepository {
  @override
  Stream<UserProfile?> watchProfile(String uid) => const Stream.empty();

  @override
  Future<void> saveProfile(UserProfile profile) async {}
}
