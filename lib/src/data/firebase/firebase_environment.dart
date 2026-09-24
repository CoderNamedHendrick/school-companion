import 'package:flutter/foundation.dart';

abstract final class FirebaseEnvironment {
  static const production = bool.fromEnvironment('USE_PRODUCTION_FIREBASE');
  static const useEmulators = !kReleaseMode && !production;
  static const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'school-companion-project');
  static const region = String.fromEnvironment('FIREBASE_FUNCTIONS_REGION', defaultValue: 'europe-west1');
  static const projectNumber = String.fromEnvironment('FIREBASE_PROJECT_NUMBER', defaultValue: '853755032440');
  static Uri endpoint(String name) => Uri.parse(
    useEmulators
        ? 'http://$emulatorHost:5001/$projectId/$region/$name'
        : 'https://$name-$projectNumber.$region.run.app',
  );
}
