import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/auth.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:shelf/shelf.dart';

bool get isEmulator => Platform.environment['FUNCTIONS_EMULATOR'] == 'true';

class AccessDenied implements Exception {
  const AccessDenied(this.status, this.message);
  final int status;
  final String message;
}

const productionOrigins = {
  'https://school-companion-project.web.app',
  'https://school-companion-project.firebaseapp.com',
};

void requireSessionOrigin(Request request, {bool local = false}) {
  final origin = request.headers['origin'];
  final uri = origin == null ? null : Uri.tryParse(origin);
  final localOrigin =
      local &&
      uri != null &&
      uri.scheme == 'http' &&
      {'localhost', '127.0.0.1'}.contains(uri.host);
  if ((!productionOrigins.contains(origin) && !localOrigin) ||
      request.headers['x-school-companion'] != '1' ||
      request.headers['content-type']?.split(';').first.trim() !=
          'application/json') {
    throw const AccessDenied(403, 'Request origin is not allowed.');
  }
}

void requireRecentLogin(num? authTime, DateTime now) {
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  if (authTime == null || seconds - authTime > 300 || authTime > seconds + 30) {
    throw const AccessDenied(401, 'Please sign in again.');
  }
}

Future<void> requireAppCheck(Request request) async {
  if (isEmulator) return;
  final token = request.headers['x-firebase-appcheck'];
  if (token == null || token.isEmpty) {
    throw const AccessDenied(401, 'App verification is required.');
  }
  try {
    await FirebaseApp.instance.appCheck().verifyToken(token);
  } catch (_) {
    throw const AccessDenied(401, 'App verification failed.');
  }
}

Future<DecodedIdToken> requireUser(Request request) async {
  final authorization = request.headers['authorization'] ?? '';
  if (!authorization.startsWith('Bearer ')) {
    throw const AccessDenied(401, 'Sign in to continue.');
  }
  DecodedIdToken user;
  try {
    user = await FirebaseApp.instance.auth().verifyIdToken(
      authorization.substring(7),
      checkRevoked: true,
    );
  } catch (_) {
    throw const AccessDenied(401, 'Please sign in again.');
  }
  if (user.emailVerified != true) {
    throw const AccessDenied(403, 'Verify your email address to continue.');
  }
  return user;
}

String documentId(Object? value, String field) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      value.contains('/') ||
      value == '.' ||
      value == '..') {
    throw AccessDenied(400, 'Invalid $field.');
  }
  return value;
}

String boundedText(Object? value, String field, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw AccessDenied(400, 'Invalid $field.');
  }
  return value.trim();
}

String inviteCode(Object? value) {
  final code = boundedText(value, 'invitation code', 64).toUpperCase();
  if (code.length < 8 || !RegExp(r'^[A-Z0-9-]+$').hasMatch(code)) {
    throw const AccessDenied(
      400,
      'Use an invitation code of 8–64 letters, numbers, or hyphens.',
    );
  }
  return code;
}

String privateKey(String value) =>
    sha256.convert(utf8.encode(value)).toString();

Future<void> rateLimit(String uid, String action, {int limit = 20}) async {
  final db = FirebaseApp.instance.firestore();
  final ref = db.collection('_rateLimits').doc(privateKey('$uid:$action'));
  final now = DateTime.now().toUtc();
  await db.runTransaction((tx) async {
    final old = (await tx.get(ref)).data();
    final start = old?['start'] as Timestamp?;
    final active = start != null && now.difference(start.toDate()).inHours < 1;
    final count = active ? (old?['count'] as num? ?? 0).toInt() : 0;
    if (count >= limit) {
      throw const AccessDenied(429, 'Too many requests. Try again later.');
    }
    tx.set(ref, {
      'start': active ? start : Timestamp.fromDate(now),
      'count': count + 1,
    });
  });
}

Future<void> requireLecturerMember(
  String uid,
  Map<String, Object?> body,
) async {
  final channelId = documentId(body['channelId'], 'channel');
  final db = FirebaseApp.instance.firestore();
  final profile = await db.collection('users').doc(uid).get();
  final member = await db
      .collection('channels')
      .doc(channelId)
      .collection('memberships')
      .doc(uid)
      .get();
  if (profile.data()?['role'] != 'lecturer' ||
      !member.exists ||
      member.data()?['status'] != 'active') {
    throw const AccessDenied(403, 'You cannot manage this channel.');
  }
}
