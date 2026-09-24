import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'firebase_providers.dart';
import 'backend_client.dart';
import 'firebase_environment.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  final service = PushNotificationService(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    messaging: ref.watch(firebaseMessagingProvider),
    client: client,
  );
  ref.onDispose(service.dispose);
  return service;
});

final announcementPushGatewayProvider = Provider<AnnouncementPushGateway?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return ref.watch(pushNotificationServiceProvider);
});

abstract interface class AnnouncementPushGateway {
  Future<Map<String, dynamic>> dispatchAnnouncement({
    required String title,
    required String body,
    required String channelId,
  });
}

class PushNotificationService implements AnnouncementPushGateway {
  PushNotificationService({required this.firestore, required this.auth, required this.messaging, required this.client});

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseMessaging messaging;
  final http.Client client;
  StreamSubscription<String>? _tokenSubscription;

  void dispose() {
    unawaited(_tokenSubscription?.cancel());
  }

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'school-companion-project');
  static const _region = String.fromEnvironment('FIREBASE_FUNCTIONS_REGION', defaultValue: 'europe-west1');
  static const _projectNumber = String.fromEnvironment('FIREBASE_PROJECT_NUMBER', defaultValue: '853755032440');
  static const _webVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

  Uri get _dispatchEndpoint => FirebaseEnvironment.useEmulators
      ? Uri.parse('http://${FirebaseEnvironment.emulatorHost}:5001/$_projectId/$_region/send-announcement-push')
      : Uri.parse('https://send-announcement-push-$_projectNumber.$_region.run.app');

  Future<String> registerDevice(String userId) async {
    if (FirebaseEnvironment.useEmulators) {
      await _saveToken(userId, 'emulator-device-$userId');
      return 'emulated';
    }
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return 'permission_denied';
    }
    final token = await messaging.getToken(vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey);
    if (token == null || token.isEmpty) return 'token_unavailable';
    await _saveToken(userId, token);
    await _tokenSubscription?.cancel();
    _tokenSubscription = messaging.onTokenRefresh.listen((next) {
      if (auth.currentUser?.uid == userId) unawaited(_saveToken(userId, next));
    });
    return 'registered';
  }

  Future<void> unregisterDevice() async {
    await _tokenSubscription?.cancel();
    final user = auth.currentUser;
    if (user == null) return;
    if (!FirebaseEnvironment.useEmulators) {
      if (!await messaging.isSupported()) return;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
    }
    final token = FirebaseEnvironment.useEmulators
        ? 'emulator-device-${user.uid}'
        : await messaging.getToken(vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey);
    if (token == null) return;
    final id = base64UrlEncode(utf8.encode(token)).replaceAll('=', '');
    await firestore.collection('users').doc(user.uid).collection('devices').doc(id).delete();
    if (!FirebaseEnvironment.useEmulators) await messaging.deleteToken();
  }

  Future<void> _saveToken(String userId, String token) {
    final deviceId = base64UrlEncode(utf8.encode(token)).replaceAll('=', '');
    return firestore.collection('users').doc(userId).collection('devices').doc(deviceId).set({
      'token': token,
      'platform': 'flutter',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>> dispatchAnnouncement({
    required String title,
    required String body,
    required String channelId,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    final token = await user.getIdToken();
    final response = await client.post(
      _dispatchEndpoint,
      headers: {
        'content-type': 'application/json',
        ...await appCheckHeaders(),
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: jsonEncode({'title': title, 'body': body, 'channelId': channelId}),
    );
    final result = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Push dispatch failed (${response.statusCode}): '
        '${result['message'] ?? result['error'] ?? response.body}',
      );
    }
    return result;
  }
}
