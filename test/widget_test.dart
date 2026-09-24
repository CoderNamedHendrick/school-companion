import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_companion/src/app/app_routes.dart';
import 'package:school_companion/src/app/school_companion_app.dart';
import 'package:school_companion/src/data/firebase/school_repository.dart';
import 'package:school_companion/src/data/firebase/resource_storage.dart';
import 'package:school_companion/src/features/legal/privacy_policy_screen.dart';
import 'package:school_companion/src/features/legal/terms_of_service_screen.dart';
import 'fixtures/firestore_seed_data.dart';

Future<void> _pumpDashboard(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  appRouterConfig.router.set(const [SignInRoute()]);
  final firestore = FakeFirebaseFirestore();
  await seedSchoolCompanionData(firestore);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [firestoreProvider.overrideWithValue(firestore), activeUserIdProvider.overrideWithValue('current')],
      child: const SchoolCompanionApp(),
    ),
  );
  await tester.pump();
  appRouterConfig.router.set(const [MainShellRoute()]);
  await tester.pumpAndSettle();
}

class _RecordingResourceStorage implements ResourceStorage {
  final deletedPaths = <String>[];

  @override
  Future<void> delete(String storagePath) async {
    deletedPaths.add(storagePath);
  }

  @override
  Future<Uint8List> download(String storagePath) async => Uint8List(0);

  @override
  Future<String> upload({
    required String channelId,
    required String userId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async => 'resources/$channelId/$userId/$fileName';
}

void main() {
  testWidgets('opens About, Privacy Policy, and Terms of Service from the account menu and returns', (tester) async {
    await _pumpDashboard(tester, const Size(1200, 800));

    // 1. About
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About School Companion'));
    await tester.pumpAndSettle();

    expect(appRouterConfig.router.stack.last, isA<AboutRoute>());
    expect(find.text('Everything your learning community needs'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Today in your learning spaces'), findsOneWidget);

    // 2. Privacy Policy
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Privacy Policy'));
    await tester.pumpAndSettle();

    expect(appRouterConfig.router.stack.last, isA<PrivacyPolicyRoute>());
    expect(find.text('1. Information We Collect'), findsOneWidget);
    expect(find.text('3. Data Storage & Security'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Today in your learning spaces'), findsOneWidget);

    // 3. Terms of Service
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Terms of Service'));
    await tester.pumpAndSettle();

    expect(appRouterConfig.router.stack.last, isA<TermsOfServiceRoute>());
    expect(find.text('1. Acceptance of Terms & Eligibility'), findsOneWidget);
    expect(find.text('3. Acceptable Use & Academic Integrity'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Today in your learning spaces'), findsOneWidget);
  });

  testWidgets('renders PrivacyPolicyScreen with all policy sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1. Information We Collect'), findsOneWidget);
    expect(find.text('2. How We Use Your Information'), findsOneWidget);
    expect(find.text('3. Data Storage & Security'), findsOneWidget);
    expect(find.text('4. Information Sharing & Disclosure'), findsOneWidget);
    expect(find.text('5. Your Rights & Data Retention'), findsOneWidget);
    expect(find.text('6. Updates & Contact'), findsOneWidget);
    expect(find.text('View Terms of Service'), findsOneWidget);
  });

  testWidgets('renders TermsOfServiceScreen with all terms sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1. Acceptance of Terms & Eligibility'), findsOneWidget);
    expect(find.text('2. User Accounts & Responsibilities'), findsOneWidget);
    expect(find.text('3. Acceptable Use & Academic Integrity'), findsOneWidget);
    expect(find.text('4. Content Ownership & Course Materials'), findsOneWidget);
    expect(find.text('5. Service Availability & Disclaimers'), findsOneWidget);
    expect(find.text('6. Termination & Governing Terms'), findsOneWidget);
    expect(find.text('View Privacy Policy'), findsOneWidget);
  });

  testWidgets('renders the School Companion dashboard from Firestore', (tester) async {
    await _pumpDashboard(tester, const Size(1200, 800));

    expect(find.text('School Companion'), findsOneWidget);
    expect(find.text('Today in your learning spaces'), findsOneWidget);
    expect(find.text('Software Engineering Project'), findsOneWidget);
    expect(find.text('Chapter 4 implementation review'), findsOneWidget);
  });

  testWidgets('uses compact navigation on a phone-sized viewport', (tester) async {
    await _pumpDashboard(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Community'), findsOneWidget);
  });

  testWidgets('uses rail navigation on a wide desktop viewport', (tester) async {
    await _pumpDashboard(tester, const Size(1200, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('New space'), findsOneWidget);
  });

  testWidgets('project task comments can be viewed and added', (tester) async {
    await _pumpDashboard(tester, const Size(1200, 800));

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Comments').first);
    await tester.pumpAndSettle();

    expect(find.text('Comments on Define Firestore collections'), findsOneWidget);
    expect(find.text('Include role and membership rules in the model.'), findsOneWidget);
    expect(find.text('Dr. Amina Yusuf'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Add a comment'), 'The rules are now documented.');
    await tester.tap(find.text('Post comment'));
    await tester.pumpAndSettle();

    expect(find.text('The rules are now documented.'), findsOneWidget);
  });

  testWidgets('poll creation starts with two options and can add more', (tester) async {
    await _pumpDashboard(tester, const Size(1200, 800));

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Poll'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Question'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Option 1'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Option 2'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Option 3'), findsNothing);

    await tester.tap(find.text('Add option'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Option 3'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Question'), 'Which format should we use?');
    await tester.enterText(find.widgetWithText(TextField, 'Option 1'), 'Document');
    await tester.enterText(find.widgetWithText(TextField, 'Option 2'), 'Slides');
    await tester.enterText(find.widgetWithText(TextField, 'Option 3'), 'Video');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Which format should we use?'), findsOneWidget);
    expect(find.text('Document (0)'), findsOneWidget);
    expect(find.text('Slides (0)'), findsOneWidget);
    expect(find.text('Video (0)'), findsOneWidget);
  });

  testWidgets('closing a quiz dialog preserves the community screen', (tester) async {
    await _pumpDashboard(tester, const Size(1200, 800));

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firestore security rules quick quiz'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Lecturer solution'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Student community'), findsOneWidget);
    expect(find.text('Polls'), findsOneWidget);
    expect(find.text('Quizzes and exercises'), findsOneWidget);

    await tester.tap(find.text('Firestore security rules quick quiz'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('dashboard meets core Flutter accessibility guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpDashboard(tester, const Size(1200, 800));

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('account menu updates the authenticated user profile', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appRouterConfig.router.set(const [SignInRoute()]);
    final firestore = FakeFirebaseFirestore();
    await seedSchoolCompanionData(firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(firestore), activeUserIdProvider.overrideWithValue('current')],
        child: const SchoolCompanionApp(),
      ),
    );
    await tester.pump();
    appRouterConfig.router.set(const [MainShellRoute()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'Hendrick Updated');
    await tester.enterText(find.widgetWithText(TextField, 'Programme'), 'Computer Science');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final profile = await firestore.collection('users').doc('current').get();
    expect(profile.data()?['name'], 'Hendrick Updated');
    expect(profile.data()?['programme'], 'Computer Science');
    expect(profile.data()?['email'], 'hendrick@student.miva.edu.ng');
    expect(profile.data()?['role'], 'student');
  });

  testWidgets('lecturer can moderate and remove a shared channel resource', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appRouterConfig.router.set(const [SignInRoute()]);
    final firestore = FakeFirebaseFirestore();
    final storage = _RecordingResourceStorage();
    await seedSchoolCompanionData(firestore);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          activeUserIdProvider.overrideWithValue('lecturer-1'),
          resourceStorageProvider.overrideWithValue(storage),
        ],
        child: const SchoolCompanionApp(),
      ),
    );
    await tester.pump();
    appRouterConfig.router.set(const [MainShellRoute()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project Methodology Guide.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(storage.deletedPaths, ['resources/swe-401/lecturer-1/methodology-guide.pdf']);
    expect((await firestore.collection('resources').doc('r1').get()).exists, isFalse);
  });
}
