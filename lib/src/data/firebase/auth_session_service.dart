import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_client.dart';
import 'firebase_environment.dart';

abstract final class AuthSessionService {
  static final Uri _endpoint = Uri.base.resolve('/api/auth-session');

  static Future<bool> restore(FirebaseAuth auth) async {
    if (!kIsWeb || FirebaseEnvironment.useEmulators) {
      return (await auth.authStateChanges().first)?.emailVerified == true;
    }
    final response = await http.post(
      _endpoint,
      headers: {'content-type': 'application/json', 'x-school-companion': '1', ...await appCheckHeaders()},
      body: jsonEncode({'action': 'restore'}),
    );
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final customToken = body['customToken'];
    if (customToken is! String || customToken.isEmpty) return false;
    final credential = await auth.signInWithCustomToken(customToken).timeout(const Duration(seconds: 20));
    return credential.user?.emailVerified == true;
  }

  static Future<void> create(User? user) async {
    if (!kIsWeb || FirebaseEnvironment.useEmulators || user == null) return;
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return;
    final response = await http.post(
      _endpoint,
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $idToken',
        'x-school-companion': '1',
        ...await appCheckHeaders(),
      },
      body: jsonEncode({'action': 'create'}),
    );
    if (response.statusCode != 200) {
      throw StateError('Could not create the persistent login session.');
    }
  }

  static Future<void> clear() async {
    if (!kIsWeb || FirebaseEnvironment.useEmulators) return;
    final response = await http.post(
      _endpoint,
      headers: {'content-type': 'application/json', 'x-school-companion': '1', ...await appCheckHeaders()},
      body: jsonEncode({'action': 'clear'}),
    );
    if (response.statusCode != 200) {
      throw StateError('Could not sign out. Please try again.');
    }
  }
}
