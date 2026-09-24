import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:school_companion/src/app/app_routes.dart';
import 'package:school_companion/src/app/school_companion_app.dart';
import 'package:school_companion/src/data/firebase/school_repository.dart';
import '../test/fixtures/firestore_seed_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens a seeded channel and resource list', (tester) async {
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

    expect(find.text('Software Engineering Project'), findsOneWidget);

    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Software Engineering Project'));
    await tester.pumpAndSettle();

    expect(find.text('Live discussion'), findsOneWidget);
    expect(find.text('Dr. Amina Yusuf'), findsOneWidget);
    expect(find.textContaining('Firebase data model'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Write a message or question'), 'Integration test message');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Integration test message'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('Resource repository'), findsOneWidget);
    expect(find.text('Firebase Data Modeling Walkthrough'), findsOneWidget);
    expect(find.text('Transcript'), findsOneWidget);
  });
}
