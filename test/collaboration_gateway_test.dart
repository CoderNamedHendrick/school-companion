import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_companion/src/data/firebase/backend_client.dart';

void main() {
  test('sends authenticated operations without trusting a client identity', () async {
    final gateway = HttpCollaborationGateway(
      MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {'action': 'joinChannel', 'code': 'PRIVATE-123'});
        return http.Response('{"title":"Private channel"}', 200);
      }),
      () async => {'authorization': 'Bearer test-token'},
    );
    expect(await gateway.call({'action': 'joinChannel', 'code': 'PRIVATE-123'}), {'title': 'Private channel'});
  });
  test('surfaces backend authorization denials', () async {
    final gateway = HttpCollaborationGateway(
      MockClient((_) async => http.Response('{"error":"Not permitted"}', 403)),
      () async => {},
    );
    await expectLater(gateway.call({'action': 'joinChannel', 'code': 'PRIVATE-123'}), throwsStateError);
  });
}
