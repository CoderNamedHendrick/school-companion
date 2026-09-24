import 'dart:convert';
import 'dart:io';
import 'security.dart';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

class WorkspaceConfig {
  const WorkspaceConfig({
    required this.accessToken,
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.calendarId,
    required this.organizerEmail,
  });

  final String accessToken;
  final String clientId;
  final String clientSecret;
  final String refreshToken;
  final String calendarId;
  final String organizerEmail;

  static const requiredEnvironment = [
    'GOOGLE_WORKSPACE_CLIENT_ID',
    'GOOGLE_WORKSPACE_CLIENT_SECRET',
    'GOOGLE_WORKSPACE_REFRESH_TOKEN',
    'GOOGLE_WORKSPACE_CALENDAR_ID',
    'GOOGLE_WORKSPACE_ORGANIZER_EMAIL',
  ];

  bool get isConfigured =>
      (accessToken.isNotEmpty ||
          (clientId.isNotEmpty &&
              clientSecret.isNotEmpty &&
              refreshToken.isNotEmpty)) &&
      calendarId.isNotEmpty &&
      organizerEmail.isNotEmpty;

  factory WorkspaceConfig.fromEnvironment() {
    return WorkspaceConfig(
      accessToken: Platform.environment['GOOGLE_WORKSPACE_ACCESS_TOKEN'] ?? '',
      clientId: Platform.environment['GOOGLE_WORKSPACE_CLIENT_ID'] ?? '',
      clientSecret:
          Platform.environment['GOOGLE_WORKSPACE_CLIENT_SECRET'] ?? '',
      refreshToken:
          Platform.environment['GOOGLE_WORKSPACE_REFRESH_TOKEN'] ?? '',
      calendarId:
          Platform.environment['GOOGLE_WORKSPACE_CALENDAR_ID'] ?? 'primary',
      organizerEmail:
          Platform.environment['GOOGLE_WORKSPACE_ORGANIZER_EMAIL'] ?? '',
    );
  }
}

class WorkspaceApiGateway {
  WorkspaceApiGateway({required this.client, required this.config});

  final http.Client client;
  final WorkspaceConfig config;
  String? _cachedAccessToken;
  DateTime? _accessTokenExpiresAt;

  Future<Map<String, Object?>> scheduleMeeting(
    Map<String, Object?> body,
  ) async {
    final request = MeetingRequest.fromJson(body);
    final calendarPayload = request.toCalendarEvent(config.organizerEmail);

    if (!config.isConfigured) {
      throw const WorkspaceConfigurationException(
        'Google Workspace credentials are not configured for this function.',
      );
    }

    final accessToken = await _getAccessToken();

    final response = await client.post(
      Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/${Uri.encodeComponent(config.calendarId)}/events',
        const {'conferenceDataVersion': '1', 'sendUpdates': 'all'},
      ),
      headers: _headers(accessToken),
      body: encodeJson(calendarPayload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkspaceValidationException(
        'Calendar API returned ${response.statusCode}: ${response.body}',
      );
    }

    final event = decodeJson(response.body);
    final meetUrl = _extractMeetUrl(event);
    final warnings = <String>[];
    if (meetUrl.isNotEmpty) {
      if (request.transcriptsEnabled) {
        final warning = await _enableCalendarMeetArtifact(
          accessToken: accessToken,
          meetUrl: meetUrl,
          configName: 'transcriptionConfig',
          settingName: 'autoTranscriptionGeneration',
          displayName: 'Automatic transcription',
        );
        if (warning != null) warnings.add(warning);
      }
      if (request.smartNotesEnabled) {
        final warning = await _enableCalendarMeetArtifact(
          accessToken: accessToken,
          meetUrl: meetUrl,
          configName: 'smartNotesConfig',
          settingName: 'autoSmartNotesGeneration',
          displayName: 'Automatic smart notes',
        );
        if (warning != null) warnings.add(warning);
      }
    } else if (request.transcriptsEnabled || request.smartNotesEnabled) {
      warnings.add(
        'Google Meet did not return a ready meeting space for auto-artifact configuration.',
      );
    }
    return {
      'status': warnings.isEmpty ? 'scheduled' : 'scheduled_with_warnings',
      'calendarEventId': event['id'],
      'htmlLink': event['htmlLink'],
      'meetUrl': meetUrl,
      'conferenceStatus': _conferenceStatus(event),
      'message': warnings.join(' '),
    };
  }

  Future<Map<String, Object?>> configureMeetSpace(
    Map<String, Object?> body,
  ) async {
    final request = MeetSpaceRequest.fromJson(body);
    final payload = request.toMeetSpacePayload();

    if (!config.isConfigured) {
      throw const WorkspaceConfigurationException(
        'Google Workspace credentials are not configured for this function.',
      );
    }

    final accessToken = await _getAccessToken();

    final response = await client.post(
      Uri.https('meet.googleapis.com', '/v2/spaces'),
      headers: _headers(accessToken),
      body: encodeJson(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkspaceValidationException(
        'Meet API returned ${response.statusCode}: ${response.body}',
      );
    }

    final space = decodeJson(response.body);
    return {
      'status': 'configured',
      'spaceName': space['name'],
      'meetingUri': space['meetingUri'],
      'payload': payload,
    };
  }

  Map<String, String> _headers(String accessToken) => {
    'authorization': 'Bearer $accessToken',
    'content-type': 'application/json',
  };

  Future<String?> _enableCalendarMeetArtifact({
    required String accessToken,
    required String meetUrl,
    required String configName,
    required String settingName,
    required String displayName,
  }) async {
    final pathSegments = Uri.parse(meetUrl).pathSegments;
    final meetingCode = pathSegments.isEmpty ? '' : pathSegments.last;
    if (meetingCode.isEmpty) {
      return '$displayName could not be configured because the meeting code was missing.';
    }
    final getResponse = await client.get(
      Uri.https('meet.googleapis.com', '/v2/spaces/$meetingCode'),
      headers: _headers(accessToken),
    );
    if (getResponse.statusCode < 200 || getResponse.statusCode >= 300) {
      throw WorkspaceValidationException(
        'Meet space lookup API returned ${getResponse.statusCode}: ${getResponse.body}',
      );
    }
    final spaceName = decodeJson(getResponse.body)['name'];
    if (spaceName is! String || !spaceName.startsWith('spaces/')) {
      throw const WorkspaceValidationException(
        'Meet space lookup did not return a canonical resource name.',
      );
    }
    final response = await client.patch(
      Uri.https('meet.googleapis.com', '/v2/$spaceName', {
        'updateMask': 'config.artifactConfig.$configName.$settingName',
      }),
      headers: _headers(accessToken),
      body: encodeJson({
        'name': spaceName,
        'config': {
          'artifactConfig': {
            configName: {settingName: 'ON'},
          },
        },
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    if (response.statusCode == 403 &&
        response.body.contains('FEATURE_UNAVAILABLE_TO_USER')) {
      return '$displayName is unavailable for ${config.organizerEmail}; the Calendar event and Meet link were still created.';
    }
    throw WorkspaceValidationException(
      'Meet settings API returned ${response.statusCode}: ${response.body}',
    );
  }

  Future<String> _getAccessToken() async {
    if (config.accessToken.isNotEmpty) return config.accessToken;

    final cached = _cachedAccessToken;
    final expiresAt = _accessTokenExpiresAt;
    if (cached != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return cached;
    }

    final response = await client.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      headers: const {'content-type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': config.clientId,
        'client_secret': config.clientSecret,
        'refresh_token': config.refreshToken,
        'grant_type': 'refresh_token',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WorkspaceConfigurationException(
        'Google OAuth token refresh failed with status ${response.statusCode}.',
      );
    }

    final payload = decodeJson(response.body);
    final token = payload['access_token'];
    if (token is! String || token.isEmpty) {
      throw const WorkspaceConfigurationException(
        'Google OAuth token refresh returned no access token.',
      );
    }
    final expiresIn = switch (payload['expires_in']) {
      final int value => value,
      final String value => int.tryParse(value) ?? 3600,
      _ => 3600,
    };
    _cachedAccessToken = token;
    _accessTokenExpiresAt = DateTime.now().add(
      Duration(seconds: expiresIn > 120 ? expiresIn - 60 : expiresIn),
    );
    return token;
  }

  String _extractMeetUrl(Map<String, Object?> event) {
    final conferenceData = event['conferenceData'];
    if (conferenceData is! Map) return '';
    final entryPoints = conferenceData['entryPoints'];
    if (entryPoints is! List) return '';
    for (final entryPoint in entryPoints) {
      if (entryPoint is Map && entryPoint['entryPointType'] == 'video') {
        return '${entryPoint['uri'] ?? ''}';
      }
    }
    return '';
  }

  String _conferenceStatus(Map<String, Object?> event) {
    final conferenceData = event['conferenceData'];
    if (conferenceData is! Map) return 'pending';
    final createRequest = conferenceData['createRequest'];
    if (createRequest is! Map) return 'pending';
    final status = createRequest['status'];
    if (status is! Map) return 'pending';
    return '${status['statusCode'] ?? 'pending'}';
  }
}

class MeetingRequest {
  const MeetingRequest({
    required this.title,
    required this.description,
    required this.channelId,
    required this.startIso,
    required this.endIso,
    required this.attendees,
    required this.transcriptsEnabled,
    required this.smartNotesEnabled,
  });

  final String title;
  final String description;
  final String channelId;
  final String startIso;
  final String endIso;
  final List<String> attendees;
  final bool transcriptsEnabled;
  final bool smartNotesEnabled;

  factory MeetingRequest.fromJson(Map<String, Object?> json) {
    final title = _requiredString(json, 'title');
    final channelId = _requiredString(json, 'channelId');
    final startIso = _requiredString(json, 'startIso');
    final endIso = _requiredString(json, 'endIso');
    final attendees = switch (json['attendees']) {
      final List<Object?> values => values.map((value) => '$value').toList(),
      _ => const <String>[],
    };
    return MeetingRequest(
      title: title,
      description: _optionalString(json, 'description'),
      channelId: channelId,
      startIso: startIso,
      endIso: endIso,
      attendees: attendees,
      transcriptsEnabled: _optionalBool(json, 'transcriptsEnabled'),
      smartNotesEnabled: _optionalBool(json, 'smartNotesEnabled'),
    );
  }

  Map<String, Object?> toCalendarEvent(String organizerEmail) {
    return {
      'summary': title,
      'description': [
        description,
        'School Companion channel: $channelId',
        if (transcriptsEnabled) 'Transcripts requested',
        if (smartNotesEnabled) 'Smart notes requested',
      ].where((line) => line.isNotEmpty).join('\n'),
      'start': {'dateTime': startIso},
      'end': {'dateTime': endIso},
      'organizer': {'email': organizerEmail},
      'attendees': [
        for (final email in attendees) {'email': email},
      ],
      'conferenceData': {
        'createRequest': {
          'requestId':
              'school-companion-$channelId-${DateTime.now().microsecondsSinceEpoch}',
          'conferenceSolutionKey': {'type': 'hangoutsMeet'},
        },
      },
    };
  }
}

class MeetSpaceRequest {
  const MeetSpaceRequest({
    required this.accessType,
    required this.entryPointAccess,
    required this.moderationEnabled,
    required this.transcriptsEnabled,
    required this.smartNotesEnabled,
  });

  final String accessType;
  final String entryPointAccess;
  final bool moderationEnabled;
  final bool transcriptsEnabled;
  final bool smartNotesEnabled;

  factory MeetSpaceRequest.fromJson(Map<String, Object?> json) {
    return MeetSpaceRequest(
      accessType: _optionalString(json, 'accessType', fallback: 'TRUSTED'),
      entryPointAccess: _optionalString(
        json,
        'entryPointAccess',
        fallback: 'ALL',
      ),
      moderationEnabled: _optionalBool(json, 'moderationEnabled'),
      transcriptsEnabled: _optionalBool(json, 'transcriptsEnabled'),
      smartNotesEnabled: _optionalBool(json, 'smartNotesEnabled'),
    );
  }

  Map<String, Object?> toMeetSpacePayload() {
    return {
      'config': {
        'accessType': accessType,
        'entryPointAccess': entryPointAccess,
        'moderation': moderationEnabled ? 'ON' : 'OFF',
        if (moderationEnabled)
          'moderationRestrictions': {
            'chatRestriction': 'NO_RESTRICTION',
            'reactionRestriction': 'NO_RESTRICTION',
            'presentRestriction': 'HOSTS_ONLY',
          },
        if (transcriptsEnabled || smartNotesEnabled)
          'artifactConfig': {
            if (transcriptsEnabled)
              'transcriptionConfig': {
                'autoTranscriptionGeneration': transcriptsEnabled
                    ? 'ON'
                    : 'OFF',
              },
            if (smartNotesEnabled)
              'smartNotesConfig': {
                'autoSmartNotesGeneration': smartNotesEnabled ? 'ON' : 'OFF',
              },
          },
      },
    };
  }
}

class WorkspaceValidationException implements Exception {
  const WorkspaceValidationException(this.message);

  final String message;
}

class WorkspaceConfigurationException implements Exception {
  const WorkspaceConfigurationException(this.message);

  final String message;
}

class PushNotificationRequest {
  const PushNotificationRequest({
    required this.title,
    required this.body,
    required this.channelId,
  });

  final String title;
  final String body;
  final String channelId;

  factory PushNotificationRequest.fromJson(Map<String, Object?> json) {
    return PushNotificationRequest(
      title: _requiredString(json, 'title'),
      body: _requiredString(json, 'body'),
      channelId: _requiredString(json, 'channelId'),
    );
  }
}

Future<Map<String, Object?>> readJsonBody(Request request) async {
  final chunks = <int>[];
  await for (final chunk in request.read()) {
    if (chunks.length + chunk.length > 32768) {
      throw const AccessDenied(413, 'Request is too large.');
    }
    chunks.addAll(chunk);
  }
  try {
    return decodeJson(utf8.decode(chunks));
  } on FormatException {
    throw const AccessDenied(400, 'Invalid JSON.');
  }
}

Map<String, Object?> decodeJson(String text) {
  final value = jsonDecode(text);
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  throw const WorkspaceValidationException('Expected a JSON object.');
}

String encodeJson(Map<String, Object?> value) => jsonEncode(value);

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty && value.length <= 4000) {
    return value.trim();
  }
  throw WorkspaceValidationException('Missing required field: $key');
}

String _optionalString(
  Map<String, Object?> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty && value.length <= 4000) {
    return value.trim();
  }
  return fallback;
}

bool _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is bool ? value : false;
}
