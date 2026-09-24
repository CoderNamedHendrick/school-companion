import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'firebase_environment.dart';
import 'firebase_providers.dart';

Future<Map<String, String>> appCheckHeaders() async {
  if (FirebaseEnvironment.useEmulators) return {};
  final token = await FirebaseAppCheck.instance.getToken();
  if (token == null) {
    throw StateError('Could not verify this app. Please try again.');
  }
  return {'x-firebase-appcheck': token};
}

final collaborationGatewayProvider = Provider<CollaborationGateway>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpCollaborationGateway(client, () async {
    final token = await ref.read(firebaseAuthProvider).currentUser?.getIdToken();
    if (token == null) throw StateError('Sign in to continue.');
    return {'authorization': 'Bearer $token', ...await appCheckHeaders()};
  });
});

abstract interface class CollaborationGateway {
  Future<Map<String, dynamic>> call(Map<String, Object?> body);
}

class HttpCollaborationGateway implements CollaborationGateway {
  const HttpCollaborationGateway(this.client, this.headers);
  final http.Client client;
  final Future<Map<String, String>> Function() headers;

  @override
  Future<Map<String, dynamic>> call(Map<String, Object?> body) async {
    final response = await client
        .post(
          FirebaseEnvironment.endpoint('collaboration'),
          headers: {'content-type': 'application/json', ...await headers()},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(result['error'] as String? ?? 'Request failed.');
    }
    return result;
  }
}
