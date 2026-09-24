import 'package:school_companion_functions/security.dart';
import 'package:school_companion_functions/collaboration_api.dart';

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/auth.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:firebase_admin_sdk/messaging.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:http/http.dart' as http;
import 'package:school_companion_functions/workspace_api_gateway.dart';

Future<void> main(List<String> args) async {
  final gateway = WorkspaceApiGateway(
    client: http.Client(),
    config: WorkspaceConfig.fromEnvironment(),
  );

  await runFunctions((firebase) {
    firebase.https.onRequest(
      name: 'scheduleGoogleWorkspaceMeeting',
      // Secret parameters are registered at runtime as required by the SDK.
      // ignore: non_const_argument_for_const_parameter
      options: _workspaceOptions,
      (request) async => _jsonEndpoint(
        request,
        isEmulator ? _emulateScheduleMeeting : gateway.scheduleMeeting,
        action: 'meeting',
      ),
    );
    firebase.https.onRequest(
      name: 'configureGoogleMeetSpace',
      // ignore: non_const_argument_for_const_parameter
      options: _workspaceOptions,
      (request) async =>
          _jsonEndpoint(request, gateway.configureMeetSpace, action: 'meeting'),
    );
    firebase.https.onRequest(
      name: 'sendAnnouncementPush',
      // ignore: non_const_argument_for_const_parameter
      options: _pushOptions,
      (request) async =>
          _jsonEndpoint(request, _sendAnnouncementPush, action: 'push'),
    );
    firebase.https.onRequest(
      name: 'collaboration',
      // ignore: non_const_argument_for_const_parameter
      options: _collaborationOptions,
      (request) => _jsonEndpoint(request, null, action: 'collaboration'),
    );
    firebase.https.onRequest(
      name: 'authSession',
      // ignore: non_const_argument_for_const_parameter
      options: _sessionOptions,
      _authSession,
    );
  });
}

Future<Response> _authSession(Request request) async {
  if (request.method != 'POST') {
    return _jsonResponse(405, {'error': 'method_not_allowed'});
  }
  try {
    requireSessionOrigin(request, local: isEmulator);
    await requireAppCheck(request);
    final body = await readJsonBody(request);
    final action = body['action'];
    final auth = FirebaseApp.instance.auth();
    if (action == 'create') {
      final user = await requireUser(request);
      requireRecentLogin(
        user.authTime.millisecondsSinceEpoch ~/ 1000,
        DateTime.now().toUtc(),
      );
      await rateLimit(user.uid, 'sessionCreate');
      final sessionCookie = await auth.createSessionCookie(
        request.headers['authorization']!.substring(7),
        const SessionCookieOptions(expiresIn: 432000000),
      );
      return _jsonResponse(200, {'status': 'created'}).change(
        headers: {
          'set-cookie':
              '__session=$sessionCookie; Max-Age=432000; Path=/; HttpOnly; Secure; SameSite=Strict',
        },
      );
    }
    if (action == 'restore') {
      final cookie = _cookie(request, '__session');
      if (cookie == null) throw const AccessDenied(401, 'Please sign in.');
      final decoded = await auth.verifySessionCookie(
        cookie,
        checkRevoked: true,
      );
      if (decoded.emailVerified != true) {
        throw const AccessDenied(403, 'Verify your email.');
      }
      await rateLimit(decoded.uid, 'sessionRestore', limit: 120);
      final token = await auth.createCustomToken(decoded.uid);
      return _jsonResponse(200, {'customToken': token});
    }
    if (action == 'clear') {
      return _jsonResponse(200, {'status': 'cleared'}).change(
        headers: {
          'set-cookie':
              '__session=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Strict',
        },
      );
    }
    return _jsonResponse(400, {'error': 'Invalid session operation.'});
  } on AccessDenied catch (error) {
    return _jsonResponse(error.status, {'error': error.message});
  } catch (_) {
    return _jsonResponse(401, {'error': 'Please sign in again.'});
  }
}

String? _cookie(Request request, String name) {
  final cookieHeader = request.headers['cookie'];
  if (cookieHeader == null) return null;
  for (final part in cookieHeader.split(';')) {
    final pair = part.trim().split('=');
    if (pair.length >= 2 && pair.first == name) {
      return pair.sublist(1).join('=');
    }
  }
  return null;
}

Future<Map<String, Object?>> _emulateScheduleMeeting(
  Map<String, Object?> body,
) async {
  MeetingRequest.fromJson(body);
  return {
    'status': 'emulated',
    'calendarEventId': 'emulator-calendar-event',
    'meetUrl': 'https://meet.google.com/emulator-test',
    'conferenceStatus': 'success',
    'message': '',
  };
}

// The Dart Functions manifest builder derives the deployed secret name from
// these identifiers, so they intentionally match Secret Manager exactly.
// ignore: non_constant_identifier_names
final GOOGLE_WORKSPACE_CLIENT_SECRET = defineSecret(
  'GOOGLE_WORKSPACE_CLIENT_SECRET',
);
// ignore: non_constant_identifier_names
final GOOGLE_WORKSPACE_REFRESH_TOKEN = defineSecret(
  'GOOGLE_WORKSPACE_REFRESH_TOKEN',
);

final _workspaceOptions = HttpsOptions(
  region: Region(SupportedRegion.europeWest1),
  secrets: [GOOGLE_WORKSPACE_CLIENT_SECRET, GOOGLE_WORKSPACE_REFRESH_TOKEN],
  serviceAccount: ServiceAccount(
    'sc-workspace@school-companion-project.iam.gserviceaccount.com',
  ),
  maxInstances: Instances(3),
  timeoutSeconds: TimeoutSeconds(60),
  cors: Cors(isEmulator ? ['*'] : productionOrigins.toList()),
);

final _pushOptions = HttpsOptions(
  region: Region(SupportedRegion.europeWest1),
  serviceAccount: ServiceAccount(
    'sc-push@school-companion-project.iam.gserviceaccount.com',
  ),
  maxInstances: Instances(3),
  timeoutSeconds: TimeoutSeconds(60),
  cors: Cors(isEmulator ? ['*'] : productionOrigins.toList()),
);

final _collaborationOptions = HttpsOptions(
  region: Region(SupportedRegion.europeWest1),
  serviceAccount: ServiceAccount(
    'sc-collaboration@school-companion-project.iam.gserviceaccount.com',
  ),
  maxInstances: Instances(3),
  timeoutSeconds: TimeoutSeconds(60),
  cors: Cors(isEmulator ? ['*'] : productionOrigins.toList()),
);

final _sessionOptions = HttpsOptions(
  region: Region(SupportedRegion.europeWest1),
  serviceAccount: ServiceAccount(
    'sc-auth@school-companion-project.iam.gserviceaccount.com',
  ),
  maxInstances: Instances(3),
  timeoutSeconds: TimeoutSeconds(60),
  cors: Cors(isEmulator ? ['*'] : productionOrigins.toList()),
);

Future<Response> _jsonEndpoint(
  Request request,
  Future<Map<String, Object?>> Function(Map<String, Object?> body)? handler, {
  required String action,
}) async {
  if (request.method != 'POST') {
    return _jsonResponse(405, {'error': 'POST required.'});
  }
  try {
    await requireAppCheck(request);
    final user = await requireUser(request);
    final body = await readJsonBody(request);
    if (action == 'collaboration') {
      return _jsonResponse(200, await collaborationAction(user.uid, body));
    }
    await requireLecturerMember(user.uid, body);
    await rateLimit(user.uid, action, limit: action == 'meeting' ? 10 : 20);
    if (action == 'meeting') await _validateAttendees(body);
    return _jsonResponse(200, await handler!(body));
  } on AccessDenied catch (error) {
    return _jsonResponse(error.status, {'error': error.message});
  } on WorkspaceValidationException catch (_) {
    return _jsonResponse(400, {'error': 'Invalid request.'});
  } on WorkspaceConfigurationException catch (_) {
    return _jsonResponse(503, {
      'error': 'This service is temporarily unavailable.',
    });
  } catch (_) {
    return _jsonResponse(500, {'error': 'The request could not be completed.'});
  }
}

Future<void> _validateAttendees(Map<String, Object?> body) async {
  final attendees = body['attendees'] ?? <Object?>[];
  if (attendees is! List || attendees.length > 30) {
    throw const AccessDenied(400, 'At most 30 channel members can be invited.');
  }
  final db = FirebaseApp.instance.firestore();
  for (final email in attendees) {
    if (email is! String || email.length > 254) {
      throw const AccessDenied(400, 'Invalid attendee.');
    }
    final profiles = await db
        .collection('users')
        .where('email', WhereFilter.equal, email)
        .limit(1)
        .get();
    if (profiles.docs.isEmpty) {
      throw const AccessDenied(403, 'Only channel members can be invited.');
    }
    final membership = await db
        .collection('channels')
        .doc(body['channelId'] as String)
        .collection('memberships')
        .doc(profiles.docs.single.id)
        .get();
    if (!membership.exists || membership.data()?['status'] != 'active') {
      throw const AccessDenied(403, 'Only channel members can be invited.');
    }
  }
}

Future<Map<String, Object?>> _sendAnnouncementPush(
  Map<String, Object?> body,
) async {
  final request = PushNotificationRequest.fromJson(body);
  final app = FirebaseApp.instance;
  final memberships = await app
      .firestore()
      .collection('channels')
      .doc(request.channelId)
      .collection('memberships')
      .where('status', WhereFilter.equal, 'active')
      .limit(500)
      .get();
  final tokens = <String>[];
  for (final membership in memberships.docs) {
    final devices = await app
        .firestore()
        .collection('users')
        .doc(membership.id)
        .collection('devices')
        .limit(5)
        .get();
    for (final device in devices.docs) {
      final token = device.data()['token'];
      if (token is String && token.isNotEmpty) tokens.add(token);
    }
  }
  if (tokens.isEmpty) {
    return {'status': 'no_registered_devices', 'successCount': 0};
  }
  if (isEmulator) {
    return {
      'status': 'emulated',
      'registeredDeviceCount': tokens.length,
      'successCount': tokens.length,
    };
  }
  var successCount = 0;
  var failureCount = 0;
  for (var offset = 0; offset < tokens.length; offset += 500) {
    final end = (offset + 500).clamp(0, tokens.length);
    final response = await app.messaging().sendEachForMulticast(
      MulticastMessage(
        tokens: tokens.sublist(offset, end),
        notification: Notification(title: request.title, body: request.body),
        data: {'channelId': request.channelId, 'type': 'announcement'},
      ),
    );
    successCount += response.successCount;
    failureCount += response.failureCount;
  }
  return {
    'status': failureCount == 0 ? 'sent' : 'partially_sent',
    'successCount': successCount,
    'failureCount': failureCount,
  };
}

class WorkspaceAuthorizationException implements Exception {
  const WorkspaceAuthorizationException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}

Response _jsonResponse(int statusCode, Map<String, Object?> body) {
  return Response(
    statusCode,
    body: encodeJson(body),
    headers: const {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
  );
}
