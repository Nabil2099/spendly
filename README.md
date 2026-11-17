# Spendly — Personal Expense Tracker

**Spendly** is a personal expense tracker and budgeting app designed to help you record daily spending in **EGP**, stay within your monthly budget, visualize spending habits, and get practical financial advice powered by **Gemini AI**.

## App Idea

Managing daily expenses shouldn't feel overwhelming. Spendly focuses on a calm, distraction-free workflow:

- **Quick Capture:** Log an expense in seconds with an amount (stored safely in integer piasters), category, date, and optional note.
- **Monthly Budget Tracking:** Set a budget per calendar month and track your remaining balance with a live progress ring.
- **Visual Insights:** Explore category breakdowns, daily trends, 6-month comparisons, and key metrics (highest spending day, average transaction, top expense).
- **AI Financial Advisor:** Get an automatic monthly spending brief on the Stats screen or chat with **Spendly AI** (`gemini-3.5-flash-lite`) using your real monthly data.
- **Cross-Device Sync & Preferences:** Expenses, budgets, and user profiles sync in real time via Cloud Firestore, while UI preferences (selected month, last category, onboarding state, dark/light theme) are saved locally with Hive.

## Features

- **Splash & Onboarding:** Animated launch screen and 3-slide first-run onboarding.
- **Authentication:** Email/password sign-in and registration (with password confirmation) via Firebase Auth.
- **Home (Dashboard):** Monthly EGP total, optional approximate USD conversion (Frankfurter v2 API), budget progress ring & edit dialog, `fl_chart` category/trend switcher, and recent transactions.
- **History (Transactions):** Date-grouped expenses with title/note search, month & category filters, tap-to-edit, and delete confirmation.
- **Stats (Analytics):** Key monthly metrics, AI Spending Brief card, 6-month comparison bar chart, and full category breakdown.
- **AI Advisor:** Conversational Gemini chatbot with formatted responses and quick-prompt chips.
- **Profile & Theme:** Edit display name, bio, and profile picture (`image_picker`), and toggle Light/Dark mode.

## Project Structure

Spendly follows a lightweight **feature-first** structure with **Cubit (`flutter_bloc`)** for state management, **GoRouter** for navigation, and **GetIt** for dependency injection:

```text
lib/
  main.dart                         # App entry, dotenv, Hive, Firebase & GetIt init
  app.dart                          # Root SpendlyApp with MultiBlocProvider & MaterialApp.router
  firebase_options.dart             # Generated FlutterFire platform options
  core/
    di/service_locator.dart         # GetIt registrations for repositories, services & Cubits
    router/app_router.dart          # GoRouter routes, redirects & animated transitions
    services/preferences_service.dart # Hive local UI preferences
    theme/                          # Light & Dark Material 3 themes, colors & ThemeCubit
    utils/money_formatter.dart      # Piaster parsing, EGP/USD formatting & month keys
  features/
    onboarding/                     # SplashScreen & OnboardingScreen
    auth/                           # AuthRepository, AuthCubit & AuthView
    expenses/                       # Expense model/repo, ExpenseCubit, Dashboard, Form, History, Stats & MainShell
    budget/                         # BudgetRepository (users/{uid}/budgets/{yyyy-MM})
    currency/                       # ExchangeRateService (Frankfurter v2 EGP -> USD)
    ai_advisor/                     # GeminiChatService, AiChatCubit & AiAdvisorScreen
    profile/                        # ProfileRepository, ProfileCubit & ProfileScreen
```

## Setup Instructions

### 1. Install Dependencies & Generate Launcher Icons

```bash
flutter pub get
dart run flutter_launcher_icons
```

### 2. Configure Firebase

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Enable **Cloud Firestore**.
4. Configure platforms with FlutterFire CLI:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

5. Deploy the user-scoped Firestore security rules in `firestore.rules`:

   ```bash
   firebase deploy --only firestore:rules
   ```

### 3. Configure Gemini AI Advisor (Optional)

1. Copy `.env.example` to `.env`:

   ```bash
   cp .env.example .env
   ```

2. Add your Gemini API key in `.env`:

   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   GEMINI_MODEL=gemini-3.5-flash-lite
   ```

   `.env` is gitignored so your API key is never committed.

### 4. Run & Verify

```bash
flutter run
dart format .
flutter analyze
flutter test
```
