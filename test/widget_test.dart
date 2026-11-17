import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/app.dart';
import 'package:spendly/core/di/service_locator.dart';
import 'package:spendly/features/auth/data/auth_repository.dart';
import 'package:spendly/features/auth/presentation/auth_cubit.dart';
import 'package:spendly/features/auth/presentation/auth_view.dart';
import 'package:spendly/features/onboarding/presentation/onboarding_screen.dart';
import 'package:spendly/features/onboarding/presentation/splash_screen.dart';
import 'package:spendly/features/profile/data/profile_repository.dart';
import 'package:spendly/l10n/app_localizations.dart';

import 'expense_cubit_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._user);

  final AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<void> register(String email, String password) async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      Stream.value(UserProfile(uid: uid, name: 'Yami'));

  @override
  Future<void> saveProfile(UserProfile profile) async {}
}

void main() {
  testWidgets('SpendlyApp renders Dashboard and switches to Transactions', (
    tester,
  ) async {
    final expenseRepo = FakeExpenseRepository();
    final budgetRepo = FakeBudgetRepository();
    addTearDown(() async {
      await expenseRepo.dispose();
      await budgetRepo.dispose();
    });

    await setupServiceLocator(
      isFirebaseConfigured: true,
      authRepository: FakeAuthRepository(
        const AppUser(uid: 'u1', email: 'student@spendly.app'),
      ),
      expenseRepository: expenseRepo,
      budgetRepository: budgetRepo,
      profileRepository: FakeProfileRepository(),
    );

    await tester.pumpWidget(const SpendlyApp(showSplash: false));
    await tester.pumpAndSettle();

    expect(find.text('Spendly'), findsOneWidget);
    expect(find.text('Total Spending'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsNothing);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Search transactions...'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('AI Spending Brief'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('History'), findsNothing);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Category Breakdown'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Spendi AI'), findsOneWidget);
    expect(find.text('Stats'), findsNothing);
  });

  testWidgets(
    'AuthView shows Confirm Password in register mode and validates match',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) => AuthCubit(
              repository: FakeAuthRepository(null),
              isFirebaseConfigured: true,
            ),
            child: const AuthView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm Password'), findsNothing);

      await tester.tap(find.text('New to Spendly? Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Password'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@spendly.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'different',
      );
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    },
  );

  testWidgets(
    'AuthView shows Confirm Password in register mode and validates match',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) => AuthCubit(
              repository: FakeAuthRepository(null),
              isFirebaseConfigured: true,
            ),
            child: const AuthView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm Password'), findsNothing);

      await tester.tap(find.text('New to Spendly? Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Password'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@spendly.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'different',
      );
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    },
  );

  testWidgets('SplashScreen invokes onFinished after delay', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onFinished: () => finished = true)),
    );

    expect(find.text('Spendly'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(finished, isTrue);
  });

  testWidgets('OnboardingScreen navigates through slides and completes', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () => completed = true)),
    );

    expect(find.text('Track Daily Expenses'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Stay Within Budget'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Clear Spending Insights'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
