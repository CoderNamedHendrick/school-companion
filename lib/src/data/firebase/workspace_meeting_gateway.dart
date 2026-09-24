import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'firebase_providers.dart';
import 'backend_client.dart';
import 'firebase_environment.dart';

final workspaceMeetingGatewayProvider = Provider<WorkspaceMeetingGateway>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpWorkspaceMeetingGateway(
    client: client,
    tokenProvider: () async {
      final user = ref.read(firebaseAuthProvider).currentUser;
      return await user?.getIdToken();
    },
  );
});

abstract interface class WorkspaceMeetingGateway {
  Future<WorkspaceMeetingResult> schedule({
    required String title,
    required String description,
    required String channelId,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<String> attendees,
    required bool transcriptsEnabled,
    required bool smartNotesEnabled,
  });
}

class WorkspaceMeetingResult {
  const WorkspaceMeetingResult({
    required this.status,
    required this.calendarEventId,
    required this.meetUrl,
    required this.message,
  });

  final String status;
  final String calendarEventId;
  final String meetUrl;
  final String message;
}

class HttpWorkspaceMeetingGateway implements WorkspaceMeetingGateway {
  const HttpWorkspaceMeetingGateway({required this.client, required this.tokenProvider});

  final http.Client client;
  final Future<String?> Function() tokenProvider;

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'school-companion-project');
  static const _region = String.fromEnvironment('FIREBASE_FUNCTIONS_REGION', defaultValue: 'europe-west1');
  static const _projectNumber = String.fromEnvironment('FIREBASE_PROJECT_NUMBER', defaultValue: '853755032440');
  Uri get _endpoint => FirebaseEnvironment.useEmulators
      ? Uri.parse(
          'http://${FirebaseEnvironment.emulatorHost}:5001/$_projectId/$_region/schedule-google-workspace-meeting',
        )
      : Uri.parse('https://schedule-google-workspace-meeting-$_projectNumber.$_region.run.app');

  @override
  Future<WorkspaceMeetingResult> schedule({
    required String title,
    required String description,
    required String channelId,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<String> attendees,
    required bool transcriptsEnabled,
    required bool smartNotesEnabled,
  }) async {
    final token = await tokenProvider();
    final response = await client.post(
      _endpoint,
      headers: {
        'content-type': 'application/json',
        ...await appCheckHeaders(),
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'channelId': channelId,
        'startIso': startsAt.toUtc().toIso8601String(),
        'endIso': endsAt.toUtc().toIso8601String(),
        'attendees': attendees,
        'transcriptsEnabled': transcriptsEnabled,
        'smartNotesEnabled': smartNotesEnabled,
      }),
    );
    final decoded = response.body.trim().isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Workspace scheduling failed (${response.statusCode}): '
        '${decoded['message'] ?? decoded['error'] ?? response.body}',
      );
    }
    return WorkspaceMeetingResult(
      status: '${decoded['status'] ?? 'scheduled'}',
      calendarEventId: '${decoded['calendarEventId'] ?? ''}',
      meetUrl: '${decoded['meetUrl'] ?? decoded['htmlLink'] ?? ''}',
      message: '${decoded['message'] ?? ''}',
    );
  }
}
