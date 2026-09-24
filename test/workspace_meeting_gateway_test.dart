import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_companion/src/data/firebase/workspace_meeting_gateway.dart';

void main() {
  test('posts an authenticated Calendar/Meet request and parses success', () async {
    late http.Request captured;
    final gateway = HttpWorkspaceMeetingGateway(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'scheduled',
            'calendarEventId': 'event-123',
            'meetUrl': 'https://meet.google.com/test-room',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'firebase-id-token',
    );

    final result = await gateway.schedule(
      title: 'Review',
      description: 'Chapter 4',
      channelId: 'swe-401',
      startsAt: DateTime.utc(2026, 8, 24, 10),
      endsAt: DateTime.utc(2026, 8, 24, 10, 45),
      attendees: const ['student@test.local'],
      transcriptsEnabled: true,
      smartNotesEnabled: true,
    );

    expect(captured.headers['authorization'], 'Bearer firebase-id-token');
    expect(jsonDecode(captured.body)['channelId'], 'swe-401');
    expect(result.status, 'scheduled');
    expect(result.calendarEventId, 'event-123');
    expect(result.meetUrl, 'https://meet.google.com/test-room');
  });

  test('surfaces a rejected Workspace function response', () async {
    final gateway = HttpWorkspaceMeetingGateway(
      client: MockClient((_) async => http.Response(jsonEncode({'error': 'lecturer_required'}), 403)),
      tokenProvider: () async => 'student-token',
    );

    expect(
      () => gateway.schedule(
        title: 'Rejected',
        description: '',
        channelId: 'swe-401',
        startsAt: DateTime.utc(2026, 8, 24, 10),
        endsAt: DateTime.utc(2026, 8, 24, 11),
        attendees: const [],
        transcriptsEnabled: false,
        smartNotesEnabled: false,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
