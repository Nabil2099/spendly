import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/expenses/presentation/expense_cubit.dart';
import 'features/profile/presentation/profile_cubit.dart';

/// Root Spendly application widget wired via `get_it` and `go_router`.
class SpendlyApp extends StatefulWidget {
  const SpendlyApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  State<SpendlyApp> createState() => _SpendlyAppState();
}

class _SpendlyAppState extends State<SpendlyApp> {
  late final ThemeCubit _themeCubit;
  late final AuthCubit _authCubit;
  late final ExpenseCubit _expenseCubit;
  late final ProfileCubit _profileCubit;
  late final AppRouterNotifier _routerNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _themeCubit = getIt<ThemeCubit>();
    _authCubit = getIt<AuthCubit>();
    _expenseCubit = getIt<ExpenseCubit>();
    _profileCubit = getIt<ProfileCubit>();

    final initialUid = _authCubit.state.user?.uid;
    if (initialUid != null) {
      _expenseCubit.bindUser(initialUid);
      _profileCubit.bindUser(initialUid);
    }

    final prefs = getIt.isRegistered<PreferencesService>()
        ? getIt<PreferencesService>()
        : null;
    final hasSeenOnboarding = prefs?.getHasSeenOnboarding() ?? true;

    _routerNotifier = AppRouterNotifier(
      authCubit: _authCubit,
      showSplash: widget.showSplash,
      hasSeenOnboarding: hasSeenOnboarding,
    );

    _router = createAppRouter(
      notifier: _routerNotifier,
      onOnboardingComplete: () => prefs?.setHasSeenOnboarding(true),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _routerNotifier.dispose();
    _themeCubit.close();
    _authCubit.close();
    _expenseCubit.close();
    _profileCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _themeCubit),
        BlocProvider.value(value: _authCubit),
        BlocProvider.value(value: _expenseCubit),
        BlocProvider.value(value: _profileCubit),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) => prev.user?.uid != curr.user?.uid,
        listener: (context, state) {
          final uid = state.user?.uid;
          _expenseCubit.bindUser(uid);
          _profileCubit.bindUser(uid);
        },
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Spendly',
              debugShowCheckedModeBanner: false,
              theme: buildSpendlyTheme(),
              darkTheme: buildSpendlyDarkTheme(),
              themeMode: themeMode,
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
