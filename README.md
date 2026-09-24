# School Companion

School Companion is a final-year project for the BSc Software Engineering
programme at Miva Open University. It explores how a shared digital workspace
can support communication and collaboration between students and lecturers.

A Flutter application for students and lecturers to manage learning channels,
messages, resources, meetings, projects, and assessments. Firebase provides
identity, storage, and real-time data; the Dart backend integrates Google
Workspace and push notifications.

## Development

Run commands from this directory. Install Flutter (with Dart 3.12.1 or later),
Node.js, Firebase CLI, and JDK 21 for the Firebase emulators. Native builds also
require the relevant Android or Apple toolchain.

```sh
flutter pub get
npm ci
(cd functions && dart pub get)
```

Debug and profile builds use local Firebase emulators by default. To develop
locally, start and seed the emulators:

```sh
firebase emulators:start --project school-companion-project \
  --only auth,firestore,storage,functions
```

In another terminal:

```sh
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
GCLOUD_PROJECT=school-companion-project npm run seed:emulator
flutter run -d chrome
```

For the Android emulator, also pass
`--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`. Emulator mode is disabled in release builds. Connecting a development build to
production requires `--dart-define=USE_PRODUCTION_FIREBASE=true`. Local fixture accounts
are defined in `tool/seed_emulator.mjs`.

## Validation

```sh
flutter analyze
flutter test
(cd functions && dart analyze && dart test)
npm run test:emulator
npm run test:functions-emulator
```

`npm run verify` additionally runs Android integration tests, emulator
performance checks, and a web release build. It requires the Android SDK and
an available emulator. Fixtures live under `test/fixtures`; they are not part
of the application package.

## Release builds

Update `version` in `pubspec.yaml` for each release. Verify that the bundled
Firebase client configuration, backend project, and deployed rules and indexes
match the intended environment. Keep service credentials in Secret Manager
or ignored backend environment files, as described in `functions/.env.example`.

### Android

Copy `android/key.properties.example` to `android/key.properties`, then supply
the upload keystore path, alias, and passwords. The keystore and populated
properties file are ignored by Git. Release builds require these credentials
and never fall back to the debug key.

```sh
flutter build appbundle --release --dart-define=USE_PRODUCTION_FIREBASE=true
```

The bundle is written to `build/app/outputs/bundle/release/`. Confirm the
application identifier and store listing assets before submission.

### iOS

Configure the signing team and provisioning in `ios/Runner.xcworkspace`, with
APNs credentials for push notifications, then build:

```sh
flutter build ipa --release --dart-define=USE_PRODUCTION_FIREBASE=true
```

### Web

```sh
flutter build web --release \
  --dart-define=USE_PRODUCTION_FIREBASE=true \
  --dart-define=APP_CHECK_WEB_SITE_KEY=<registered-public-site-key> \
  --dart-define=FCM_WEB_VAPID_KEY=<public-vapid-key>
```

The registered public settings for this deployment are in
`config/production.json`; use `--dart-define-from-file=config/production.json`
in place of the individual flags above. Forks should register their own Firebase
project and App Check providers.

Serve `build/web` through the Firebase Hosting configuration in `firebase.json`
to support persistent sign-in.

`tools/deploy_school_companion.sh` runs validation, builds the web release,
and deploys Functions, access rules, indexes, and Hosting. It requires
`APP_CHECK_WEB_SITE_KEY` and `SECURITY_MIGRATION_COMPLETE=1`; run it only after
completing the migration below. Run the test suites with JDK 21 or later.

## Release checks

- Test authentication, channel membership, uploads, meetings, and push on the
  target platform using the intended backend.
- Review app icons, store metadata, privacy policy, and terms for publication.
- Confirm signing and platform push credentials. Successful emulator tests do
  not establish native push delivery or external Workspace availability.
- Review Google Workspace account capabilities for transcription and notes.

The `docs/` directory contains project evaluation records and demonstration results.

## License

[MIT License](LICENSE) — Copyright (c) 2026 Sebastine Odeh.

## Security configuration and migration

Accounts must verify their email before accessing shared content. Existing
unverified users must complete verification at their next sign-in. Invitations,
channel creation, and voting use the authenticated `collaboration` function;
clients cannot grant themselves membership or rewrite vote totals. Downloading
files checks current Storage access rather than returning a reusable public URL.
Uploads require a server reservation, are limited to 20 files and 100 MB per user
per UTC day, and cannot overwrite an existing file. Files must be smaller than
50 MB; abandoned reservations also count toward the daily allowance.

Before upgrading an existing deployment:

1. Register the web app with reCAPTCHA Enterprise in Firebase App Check. Register
   Play Integrity for Android and App Attest/Device Check for Apple clients before
   distributing those builds. Debug App Check tokens must never enter production.
2. Configure dedicated runtime service accounts with only the required Firestore,
   Firebase Auth, FCM, and per-secret access. Only the session function needs to
   mint custom tokens; grant its account token-signing permission on itself.
3. Rotate existing invite codes into private `_channelInvites` records using
   `tool/migrate_security.mjs`. The script defaults to a read-only preview and
   requires an explicit project confirmation to apply changes. Existing members
   retain access; owners share replacement codes from their channel.
4. Review stored uploads before revoking existing download tokens. The migration
   supports an explicit token-revocation option; this invalidates previously
   shared URLs. Keep uploads private, and use a malware-scanning/quarantine service
   before allowing untrusted files to be redistributed outside the application.
5. Deploy the updated backend, client, rules, and indexes together. Verify sign-in,
   membership, uploads, and meetings on each supported platform. Then enforce
   App Check for Firestore, Storage, and supported Auth operations in the console.
   The custom HTTP functions already reject missing or invalid App Check tokens.
6. Configure billing alerts, usage quotas, and operational alerts for denied
   requests and failures. Budget notifications do not impose a spending cap.
   Back up the current rules and Hosting release before deployment; rolling back
   to the old client alone will not work with the tightened rules.

GitHub Actions runs analysis, tests, dependency auditing, and secret scanning.
Enable repository secret-scanning push protection and require the Verify checks
on the default branch. Dependabot checks Flutter, backend, npm, and action
updates weekly. Never commit service-account keys, signing keys, environment
secrets, real-user exports, or private rollback snapshots.
