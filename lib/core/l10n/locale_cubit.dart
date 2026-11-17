import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/preferences_service.dart';

/// Manages the app's active [Locale] (`en` / `ar`) persisted in Hive.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit({PreferencesService? preferencesService})
    : _preferencesService = preferencesService,
      super(_initialLocale(preferencesService));

  final PreferencesService? _preferencesService;

  static Locale _initialLocale(PreferencesService? prefs) {
    final code = prefs?.getLocaleCode();
    if (code == 'ar') return const Locale('ar');
    return const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    if (state.languageCode == locale.languageCode) return;
    emit(locale);
    await _preferencesService?.setLocaleCode(locale.languageCode);
  }
}
