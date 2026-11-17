import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/services/preferences_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferencesService = PreferencesService();
  await preferencesService.init();

  var isFirebaseConfigured = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseConfigured = Firebase.apps.isNotEmpty;
  } catch (_) {
    isFirebaseConfigured = false;
  }

  await setupServiceLocator(
    isFirebaseConfigured: isFirebaseConfigured,
    preferencesService: preferencesService,
  );

  runApp(const SpendlyApp());
}
