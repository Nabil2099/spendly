import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight local UI preferences stored in Hive.
/// Firestore remains the source of truth for expenses and budgets.
class PreferencesService {
  static const String _boxName = 'spendly_prefs';
  static const String _selectedMonthKey = 'selected_month';
  static const String _lastCategoryKey = 'last_category';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _themeModeKey = 'theme_mode';
  static const String _localeCodeKey = 'locale_code';

  Box<dynamic>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  String? getSelectedMonthKey() {
    return _box?.get(_selectedMonthKey) as String?;
  }

  Future<void> setSelectedMonthKey(String monthKey) async {
    await _box?.put(_selectedMonthKey, monthKey);
  }

  String? getLastCategoryId() {
    return _box?.get(_lastCategoryKey) as String?;
  }

  Future<void> setLastCategoryId(String categoryId) async {
    await _box?.put(_lastCategoryKey, categoryId);
  }

  bool getHasSeenOnboarding() {
    return (_box?.get(_hasSeenOnboardingKey) as bool?) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await _box?.put(_hasSeenOnboardingKey, value);
  }

  String? getThemeMode() {
    return _box?.get(_themeModeKey) as String?;
  }

  Future<void> setThemeMode(String mode) async {
    await _box?.put(_themeModeKey, mode);
  }

  String? getLocaleCode() {
    return _box?.get(_localeCodeKey) as String?;
  }

  Future<void> setLocaleCode(String code) async {
    await _box?.put(_localeCodeKey, code);
  }
}
