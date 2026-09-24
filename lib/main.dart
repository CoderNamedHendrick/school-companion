import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'src/app/app_routes.dart';
import 'src/app/school_companion_app.dart';
import 'src/data/firebase/auth_session_service.dart';
import 'src/data/firebase/firebase_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!FirebaseEnvironment.useEmulators) {
    if (!FirebaseEnvironment.production) {
      throw StateError('Release builds require USE_PRODUCTION_FIREBASE=true.');
    }
    if (!kIsWeb && {TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform)) {
      throw UnsupportedError('Production App Check is not configured for this platform.');
    }
    const siteKey = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');
    if (kIsWeb && siteKey.isEmpty) {
      throw StateError('Configure APP_CHECK_WEB_SITE_KEY for this web release.');
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb ? ReCaptchaEnterpriseProvider(siteKey) : null,
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;

  if (FirebaseEnvironment.useEmulators) {
    const host = FirebaseEnvironment.emulatorHost;
    await auth.useAuthEmulator(host, 9099);
    firestore.useFirestoreEmulator(host, 8080);
    await storage.useStorageEmulator(host, 9199);
  }
  // Resolve the durable server session before the router renders. FlutterFire
  // can emit a transient null during browser reload, so its stream is attached
  // only after the initial route has been selected.
  final isAuthenticated = kIsWeb
      ? await AuthSessionService.restore(auth)
      : (await auth.authStateChanges().first)?.emailVerified == true;

  final isPublicRoute =
      kIsWeb && const {'/about', '/privacy', '/privacy-policy', '/terms', '/terms-of-service'}.contains(Uri.base.path);

  runApp(const ProviderScope(child: SchoolCompanionApp()));
  if (!isPublicRoute) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouterConfig.router.set([if (isAuthenticated) const MainShellRoute() else const SignInRoute()]);
    });
  }
  if (!kIsWeb) {
    auth.authStateChanges().listen(_syncRouteWithAuthState);
  }
}

void _syncRouteWithAuthState(User? user) {
  final stack = appRouterConfig.router.stack;
  final lastRoute = stack.isNotEmpty ? stack.last : null;
  if (user?.emailVerified == true && lastRoute is SignInRoute) {
    appRouterConfig.router.set(const [MainShellRoute()]);
  } else if (user?.emailVerified != true && lastRoute is MainShellRoute) {
    appRouterConfig.router.set(const [SignInRoute()]);
  }
}
