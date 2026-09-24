import 'package:flutter_test/flutter_test.dart';
import 'package:school_companion/src/app/app_routes.dart';

void main() {
  test('codec decodes and encodes legal routes', () {
    const codec = AppRouteCodec();
    final decodedPrivacy = codec.decode(Uri.parse('/privacy'));
    expect(decodedPrivacy?.last, isA<PrivacyPolicyRoute>());

    final decodedPrivacyAlt = codec.decode(Uri.parse('/privacy-policy'));
    expect(decodedPrivacyAlt?.last, isA<PrivacyPolicyRoute>());

    final decodedTerms = codec.decode(Uri.parse('/terms'));
    expect(decodedTerms?.last, isA<TermsOfServiceRoute>());

    final decodedTermsAlt = codec.decode(Uri.parse('/terms-of-service'));
    expect(decodedTermsAlt?.last, isA<TermsOfServiceRoute>());

    final encodedPrivacy = codec.encode([const MainShellRoute(), const PrivacyPolicyRoute()]);
    expect(encodedPrivacy.path, '/privacy');

    final encodedTerms = codec.encode([const MainShellRoute(), const TermsOfServiceRoute()]);
    expect(encodedTerms.path, '/terms');
  });
}
