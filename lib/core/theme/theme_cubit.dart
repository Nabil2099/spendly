import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/preferences_service.dart';

/// Manages light/dark/system [ThemeMode] persisted in Hive.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({PreferencesService? preferencesService})
    : _preferencesService = preferencesService,
      super(_initialMode(preferencesService));

  final PreferencesService? _preferencesService;

  static ThemeMode _initialMode(PreferencesService? prefs) {
    switch (prefs?.getThemeMode()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> toggleDarkMode(bool isDark) async {
    final next = isDark ? ThemeMode.dark : ThemeMode.light;
    emit(next);
    await _preferencesService?.setThemeMode(isDark ? 'dark' : 'light');
  }
}
