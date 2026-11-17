# Spendly — Personal Expense Tracker

A personal expense tracker built with **Flutter + Material 3**, **Cubit (`flutter_bloc`)**, **Firebase Auth**, **Cloud Firestore**, **Hive**, **Dio**, and **`fl_chart`**.

## Features

- **Email/Password Authentication** (Firebase Auth) with persistent sessions and sign-out menu.
- **Dashboard**: Monthly spending total in **EGP**, optional approximate **USD** equivalent via Frankfurter v2 API (`https://api.frankfurter.dev/v2/rate/EGP/USD`), monthly budget dialog with progress ring, category spending bar chart, and recent transactions.
- **Add / Edit Expense**: Single form for creating and editing expenses with positive amount validation (stored in integer piasters), 7 categories (`Food`, `Transport`, `Bills`, `Shopping`, `Health`, `Entertainment`, `Other`), date picker, and optional notes.
- **Transactions**: Date-grouped expense history, title/note search, month & category filters, tap-to-edit, and delete with confirmation.
- **Local Preferences**: Selected month and last-used category persisted locally with Hive.

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Firebase

This repository does not include Firebase credentials. To connect your own Firebase project:

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Enable **Cloud Firestore** in production mode.
4. Install the FlutterFire CLI and configure your platforms:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

5. If `flutterfire configure` generates `lib/firebase_options.dart`, update `lib/main.dart` to pass `options: DefaultFirebaseOptions.currentPlatform` into `Firebase.initializeApp(...)`.
6. Deploy the user-scoped Firestore security rules in `firestore.rules`:

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
