import 'package:get_it/get_it.dart';

import '../../features/ai_advisor/data/gemini_chat_service.dart';
import '../../features/ai_advisor/presentation/ai_chat_cubit.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/budget/data/budget_repository.dart';
import '../../features/currency/data/exchange_rate_service.dart';
import '../../features/expenses/data/expense_model.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../features/expenses/presentation/expense_cubit.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/profile_cubit.dart';
import '../services/preferences_service.dart';
import '../theme/theme_cubit.dart';

final GetIt getIt = GetIt.instance;

/// Registers services, repositories, and Cubits in [getIt].
Future<void> setupServiceLocator({
  required bool isFirebaseConfigured,
  PreferencesService? preferencesService,
  AuthRepository? authRepository,
  ExpenseRepository? expenseRepository,
  BudgetRepository? budgetRepository,
  ProfileRepository? profileRepository,
  ExchangeRateService? exchangeRateService,
  GeminiChatService? geminiChatService,
}) async {
  await getIt.reset();

  if (preferencesService != null) {
    getIt.registerSingleton<PreferencesService>(preferencesService);
  }

  getIt.registerLazySingleton<ExchangeRateService>(
    () => exchangeRateService ?? ExchangeRateService(),
  );

  getIt.registerLazySingleton<GeminiChatService>(
    () => geminiChatService ?? HttpGeminiChatService(),
  );

  if (authRepository != null) {
    getIt.registerSingleton<AuthRepository>(authRepository);
  } else if (isFirebaseConfigured) {
    getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository());
  }

  getIt.registerLazySingleton<ExpenseRepository>(
    () =>
        expenseRepository ??
        (isFirebaseConfigured
            ? FirestoreExpenseRepository()
            : _NoopExpenseRepository()),
  );

  getIt.registerLazySingleton<BudgetRepository>(
    () =>
        budgetRepository ??
        (isFirebaseConfigured
            ? FirestoreBudgetRepository()
            : _NoopBudgetRepository()),
  );

  getIt.registerLazySingleton<ProfileRepository>(
    () =>
        profileRepository ??
        (isFirebaseConfigured
            ? FirestoreProfileRepository()
            : _NoopProfileRepository()),
  );

  getIt.registerFactory<ThemeCubit>(
    () => ThemeCubit(
      preferencesService: getIt.isRegistered<PreferencesService>()
          ? getIt<PreferencesService>()
          : null,
    ),
  );

  getIt.registerFactory<AuthCubit>(
    () => AuthCubit(
      repository: getIt.isRegistered<AuthRepository>()
          ? getIt<AuthRepository>()
          : null,
      isFirebaseConfigured: isFirebaseConfigured,
    ),
  );

  getIt.registerFactory<ExpenseCubit>(
    () => ExpenseCubit(
      expenseRepository: getIt<ExpenseRepository>(),
      budgetRepository: getIt<BudgetRepository>(),
      exchangeRateService: getIt<ExchangeRateService>(),
      preferencesService: getIt.isRegistered<PreferencesService>()
          ? getIt<PreferencesService>()
          : null,
    ),
  );

  getIt.registerFactory<ProfileCubit>(
    () => ProfileCubit(repository: getIt<ProfileRepository>()),
  );

  getIt.registerFactory<AiChatCubit>(
    () => AiChatCubit(service: getIt<GeminiChatService>()),
  );
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
