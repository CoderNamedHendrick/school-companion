import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:school_companion/firebase_options.dart';
import 'package:school_companion/src/app/app_routes.dart';
import 'package:school_companion/src/app/school_companion_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final emulatorHost = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
    appRouterConfig.router.set(const [SignInRoute()]);
  });

  testWidgets('signs in, updates profile, and persists a channel message', (tester) async {
    appRouterConfig.router.set(const [SignInRoute()]);
    await tester.pumpWidget(const ProviderScope(child: SchoolCompanionApp()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email address'), 'student1@test.local');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'TestPass123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    for (var attempt = 0; attempt < 100; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (FirebaseAuth.instance.currentUser != null) break;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | ');
      fail('Firebase emulator sign-in did not complete. UI: $visibleText');
    }
    expect(FirebaseAuth.instance.currentUser!.uid, 'student-1');
    await tester.pumpAndSettle();
    expect(find.text('Today in your learning spaces'), findsOneWidget);

    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'Student Integration Test');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final profile = await FirebaseFirestore.instance.collection('users').doc('student-1').get();
    expect(profile.data()?['name'], 'Student Integration Test');
    expect(profile.data()?['role'], 'student');
    expect(profile.data()?['email'], 'student1@test.local');

    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('Software Engineering Project').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    const message = 'Automated real-emulator integration message';
    await tester.enterText(find.widgetWithText(TextField, 'Write a message or question'), message);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text(message), findsOneWidget);
    final persisted = await FirebaseFirestore.instance
        .collection('channels')
        .doc('swe-401')
        .collection('messages')
        .where('body', isEqualTo: message)
        .get();
    expect(persisted.docs, hasLength(1));
    expect(persisted.docs.single.data()['senderId'], 'student-1');
    expect(persisted.docs.single.data()['sender'], 'Student Integration Test');
  });
}
