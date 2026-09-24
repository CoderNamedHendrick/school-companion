import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_companion_functions/workspace_api_gateway.dart';
import 'package:test/test.dart';

void main() {
  test('builds Calendar event payload with Meet conference request', () {
    final request = MeetingRequest.fromJson({
      'title': 'Project review',
      'description': 'Review Chapter 4 implementation',
      'channelId': 'swe-401',
      'startIso': '2026-07-03T10:00:00+01:00',
      'endIso': '2026-07-03T10:45:00+01:00',
      'attendees': ['student@miva.edu.ng'],
      'transcriptsEnabled': true,
      'smartNotesEnabled': true,
    });

    final event = request.toCalendarEvent('lecturer@miva.edu.ng');
    expect(event['summary'], 'Project review');
    expect(event['organizer'], {'email': 'lecturer@miva.edu.ng'});
    expect(event['conferenceData'], isA<Map<String, Object?>>());
    expect((event['description'] as String), contains('Transcripts requested'));
  });

  test('builds Meet space payload with moderation and artifacts', () {
    final request = MeetSpaceRequest.fromJson({
      'moderationEnabled': true,
      'transcriptsEnabled': true,
      'smartNotesEnabled': true,
    });

    final payload = request.toMeetSpacePayload();
    final config = payload['config'] as Map<String, Object?>;
    final artifactConfig = config['artifactConfig'] as Map<String, Object?>;

    expect(config['entryPointAccess'], 'ALL');
    expect(config['moderation'], 'ON');
    expect(artifactConfig['transcriptionConfig'], {
      'autoTranscriptionGeneration': 'ON',
    });
    expect(artifactConfig['smartNotesConfig'], {
      'autoSmartNotesGeneration': 'ON',
    });
  });

  test(
    'omits disabled Meet artifacts instead of requesting licensed fields',
    () {
      final request = MeetSpaceRequest.fromJson({
        'moderationEnabled': true,
        'transcriptsEnabled': true,
        'smartNotesEnabled': false,
      });

      final payload = request.toMeetSpacePayload();
      final config = payload['config'] as Map<String, Object?>;
      final artifactConfig = config['artifactConfig'] as Map<String, Object?>;

      expect(artifactConfig, contains('transcriptionConfig'));
      expect(artifactConfig, isNot(contains('smartNotesConfig')));
    },
  );

  test('validates push notification payload', () {
    final request = PushNotificationRequest.fromJson({
      'title': 'Deadline reminder',
      'body': 'Submit Chapter 4 before Friday.',
      'channelId': 'swe-401',
    });

    expect(request.title, 'Deadline reminder');
    expect(request.channelId, 'swe-401');
    expect(
      () => PushNotificationRequest.fromJson({'title': 'Incomplete'}),
      throwsA(isA<WorkspaceValidationException>()),
    );
  });

  test('refreshes and caches a Google Workspace access token', () async {
    var oauthCalls = 0;
    var calendarCalls = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'oauth2.googleapis.com') {
        oauthCalls += 1;
        expect(request.method, 'POST');
        expect(request.bodyFields['grant_type'], 'refresh_token');
        return http.Response(
          jsonEncode({'access_token': 'fresh-token', 'expires_in': 3600}),
          200,
        );
      }
      if (request.url.host == 'www.googleapis.com') {
        calendarCalls += 1;
        expect(request.headers['authorization'], 'Bearer fresh-token');
        return http.Response(
          jsonEncode({
            'id': 'event-1',
            'htmlLink': 'https://calendar.google.com/event-1',
            'conferenceData': {
              'createRequest': {
                'status': {'statusCode': 'success'},
              },
              'entryPoints': [
                {
                  'entryPointType': 'video',
                  'uri': 'https://meet.google.com/abc-defg-hij',
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final gateway = WorkspaceApiGateway(
      client: client,
      config: const WorkspaceConfig(
        accessToken: '',
        clientId: 'client-id',
        clientSecret: 'client-secret',
        refreshToken: 'refresh-token',
        calendarId: 'primary',
        organizerEmail: 'lecturer@miva.edu.ng',
      ),
    );
    final request = {
      'title': 'Project review',
      'description': '',
      'channelId': 'swe-401',
      'startIso': '2026-07-03T10:00:00+01:00',
      'endIso': '2026-07-03T10:45:00+01:00',
      'attendees': <String>[],
    };

    await gateway.scheduleMeeting(request);
    await gateway.scheduleMeeting(request);

    expect(oauthCalls, 1);
    expect(calendarCalls, 2);
  });

  test(
    'configures requested artifacts on the Calendar-created Meet space',
    () async {
      var meetPatchCalls = 0;
      final gateway = WorkspaceApiGateway(
        client: MockClient((request) async {
          if (request.url.host == 'www.googleapis.com') {
            return http.Response(jsonEncode(_calendarEventResponse), 200);
          }
          if (request.url.host == 'meet.googleapis.com') {
            if (request.method == 'GET') {
              expect(request.url.path, '/v2/spaces/abc-defg-hij');
              return http.Response(
                jsonEncode({'name': 'spaces/canonicalSpaceId'}),
                200,
              );
            }
            meetPatchCalls += 1;
            expect(request.method, 'PATCH');
            expect(request.url.path, '/v2/spaces/canonicalSpaceId');
            expect(
              request.url.queryParameters['updateMask'],
              'config.artifactConfig.transcriptionConfig.autoTranscriptionGeneration',
            );
            expect(request.body, contains('autoTranscriptionGeneration'));
            expect(request.body, contains('spaces/canonicalSpaceId'));
            return http.Response(
              jsonEncode({'name': 'spaces/canonicalSpaceId'}),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
        config: _staticTokenConfig,
      );

      final result = await gateway.scheduleMeeting({
        ..._meetingRequest,
        'transcriptsEnabled': true,
        'smartNotesEnabled': false,
      });

      expect(result['status'], 'scheduled');
      expect(result['message'], '');
      expect(meetPatchCalls, 1);
    },
  );

  test(
    'keeps the meeting when a licensed Meet artifact is unavailable',
    () async {
      final gateway = WorkspaceApiGateway(
        client: MockClient((request) async {
          if (request.url.host == 'www.googleapis.com') {
            return http.Response(jsonEncode(_calendarEventResponse), 200);
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({'name': 'spaces/canonicalSpaceId'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'status': 'PERMISSION_DENIED',
                'details': [
                  {'reason': 'FEATURE_UNAVAILABLE_TO_USER'},
                ],
              },
            }),
            403,
          );
        }),
        config: _staticTokenConfig,
      );

      final result = await gateway.scheduleMeeting({
        ..._meetingRequest,
        'transcriptsEnabled': false,
        'smartNotesEnabled': true,
      });

      expect(result['status'], 'scheduled_with_warnings');
      expect(result['calendarEventId'], 'event-1');
      expect(
        result['message'],
        contains('Automatic smart notes is unavailable'),
      );
    },
  );
}

const _staticTokenConfig = WorkspaceConfig(
  accessToken: 'access-token',
  clientId: '',
  clientSecret: '',
  refreshToken: '',
  calendarId: 'primary',
  organizerEmail: 'lecturer@miva.edu.ng',
);

const _meetingRequest = <String, Object?>{
  'title': 'Project review',
  'description': '',
  'channelId': 'swe-401',
  'startIso': '2026-07-03T10:00:00+01:00',
  'endIso': '2026-07-03T10:45:00+01:00',
  'attendees': <String>[],
};

const _calendarEventResponse = <String, Object?>{
  'id': 'event-1',
  'htmlLink': 'https://calendar.google.com/event-1',
  'conferenceData': {
    'createRequest': {
      'status': {'statusCode': 'success'},
    },
    'entryPoints': [
      {
        'entryPointType': 'video',
        'uri': 'https://meet.google.com/abc-defg-hij',
      },
    ],
  },
};
