import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:school_companion_functions/security.dart';
import 'package:school_companion_functions/workspace_api_gateway.dart';

void main() {
  test('sessions require same-origin JSON with the custom CSRF header', () {
    Request request(
      String origin, {
      String marker = '1',
      String content = 'application/json',
    }) => Request(
      'POST',
      Uri.parse('https://school-companion-project.web.app/api/auth-session'),
      headers: {
        'origin': origin,
        'x-school-companion': marker,
        'content-type': content,
      },
    );
    expect(
      () => requireSessionOrigin(
        request('https://school-companion-project.web.app'),
      ),
      returnsNormally,
    );
    for (final origin in [
      'https://evil.example',
      'null',
      'http://localhost:7357',
    ]) {
      expect(
        () => requireSessionOrigin(request(origin)),
        throwsA(isA<AccessDenied>()),
      );
    }
    expect(
      () => requireSessionOrigin(
        request('https://school-companion-project.web.app', marker: ''),
      ),
      throwsA(isA<AccessDenied>()),
    );
    expect(
      () => requireSessionOrigin(
        request(
          'https://school-companion-project.web.app',
          content: 'text/plain',
        ),
      ),
      throwsA(isA<AccessDenied>()),
    );
  });
  test(
    'sessions require recent authentication, not merely a fresh ID token',
    () {
      final now = DateTime.utc(2026, 9, 24);
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      expect(() => requireRecentLogin(seconds - 100, now), returnsNormally);
      for (final time in [null, seconds - 301, seconds + 31]) {
        expect(
          () => requireRecentLogin(time, now),
          throwsA(isA<AccessDenied>()),
        );
      }
    },
  );
  test('invitations and document IDs reject malformed input', () {
    expect(inviteCode(' abcdef-1234 '), 'ABCDEF-1234');
    for (final code in ['tiny', '../private', 'x' * 65]) {
      expect(() => inviteCode(code), throwsA(isA<AccessDenied>()));
    }
    expect(
      () => documentId('other/channel', 'channel'),
      throwsA(isA<AccessDenied>()),
    );
  });
  test(
    'request parser bounds streamed input and rejects malformed JSON',
    () async {
      final uri = Uri.parse('https://example.test/');
      await expectLater(
        readJsonBody(Request('POST', uri, body: '{')),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        readJsonBody(Request('POST', uri, body: 'x' * 32769)),
        throwsA(isA<AccessDenied>()),
      );
      expect(
        await readJsonBody(
          Request('POST', uri, body: '{"action":"joinChannel"}'),
        ),
        {'action': 'joinChannel'},
      );
    },
  );
}
