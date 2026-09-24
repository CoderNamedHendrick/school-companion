import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

import 'security.dart';

Future<Map<String, Object?>> collaborationAction(
  String uid,
  Map<String, Object?> body,
) async {
  final db = FirebaseApp.instance.firestore();
  final profile = (await db.collection('users').doc(uid).get()).data();
  final role = profile?['role'];
  if (role != 'student' && role != 'lecturer') {
    throw const AccessDenied(403, 'Complete your profile first.');
  }
  switch (body['action']) {
    case 'createChannel':
      await rateLimit(uid, 'createChannel', limit: 5);
      final code = inviteCode(body['code']);
      final kind = body['kind'];
      if (!{'course', 'project', 'studentOnly'}.contains(kind) ||
          (kind == 'course' && role != 'lecturer') ||
          (kind == 'studentOnly' && role != 'student')) {
        throw const AccessDenied(403, 'You cannot create this channel type.');
      }
      final title = boundedText(body['title'], 'title', 120);
      final summary = boundedText(body['summary'], 'summary', 1000);
      final channel = db.collection('channels').doc();
      final invitation = db.collection('_channelInvites').doc(privateKey(code));
      await db.runTransaction((tx) async {
        if ((await tx.get(invitation)).exists) {
          throw const AccessDenied(409, 'Choose another invitation code.');
        }
        tx.set(invitation, {'channelId': channel.id});
        tx.set(channel, {
          'title': title,
          'kind': kind,
          'summary': summary,
          'code': code,
          'members': 1,
          'unread': 0,
          'colorHex': '#0A3150',
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp,
        });
        tx.set(channel.collection('memberships').doc(uid), {
          'userId': uid,
          'channelId': channel.id,
          'role': role,
          'status': 'active',
          'joinedAt': FieldValue.serverTimestamp,
        });
      });
      return {'channelId': channel.id, 'title': title};
    case 'joinChannel':
      await rateLimit(uid, 'joinChannel', limit: 10);
      final code = inviteCode(body['code']);
      final invitation = db.collection('_channelInvites').doc(privateKey(code));
      return db.runTransaction((tx) async {
        final invite = await tx.get(invitation);
        final id = invite.data()?['channelId'];
        if (id is! String) {
          throw const AccessDenied(404, 'Invitation is not available.');
        }
        final channel = db.collection('channels').doc(id);
        final record = await tx.get(channel);
        final data = record.data();
        if (data == null ||
            (data['kind'] == 'studentOnly' && role != 'student')) {
          throw const AccessDenied(403, 'Invitation is not available.');
        }
        final membership = channel.collection('memberships').doc(uid);
        final member = await tx.get(membership);
        if (member.exists && member.data()?['status'] != 'active') {
          throw const AccessDenied(
            403,
            'Contact the channel owner to restore access.',
          );
        }
        if (!member.exists) {
          tx.set(membership, {
            'userId': uid,
            'channelId': id,
            'role': role,
            'status': 'active',
            'joinedAt': FieldValue.serverTimestamp,
          });
          tx.update(channel, {'members': FieldValue.increment(1)});
        }
        return {'title': data['title'], 'channelId': id};
      });
    case 'deleteUpload':
      await rateLimit(uid, 'deleteUpload', limit: 60);
      final path = boundedText(body['path'], 'file path', 512);
      final parts = path.split('/');
      if (parts.length != 4 ||
          parts.first != 'resources' ||
          parts.any((p) => p.isEmpty || p == '.' || p == '..')) {
        throw const AccessDenied(400, 'Invalid resource path.');
      }
      final membership = await db
          .collection('channels')
          .doc(parts[1])
          .collection('memberships')
          .doc(uid)
          .get();
      if (membership.data()?['status'] != 'active' ||
          (parts[2] != uid && role != 'lecturer')) {
        throw const AccessDenied(403, 'You cannot remove this resource.');
      }
      // Revoke the reservation before deleting bytes, so it cannot be replayed.
      await db.collection('_uploadReservations').doc(parts[3]).set({
        'revoked': true,
      });
      await FirebaseApp.instance
          .storage()
          .bucket('school-companion-project.firebasestorage.app')
          .object(path)
          .delete();
      return {'status': 'deleted'};
    case 'reserveUpload':
      final channelId = documentId(body['channelId'], 'channel');
      final member = await db
          .collection('channels')
          .doc(channelId)
          .collection('memberships')
          .doc(uid)
          .get();
      if (member.data()?['status'] != 'active') {
        throw const AccessDenied(403, 'Join the channel before uploading.');
      }
      final size = body['size'];
      final contentType = body['contentType'];
      const extensions = {
        'application/pdf': 'pdf',
        'audio/mpeg': 'mp3',
        'audio/mp4': 'm4a',
        'audio/wav': 'wav',
        'video/mp4': 'mp4',
        'video/quicktime': 'mov',
        'text/plain': 'txt',
      };
      if (size is! int ||
          size <= 0 ||
          size >= 50 * 1024 * 1024 ||
          !extensions.containsKey(contentType)) {
        throw const AccessDenied(
          400,
          'Choose a supported file smaller than 50 MB.',
        );
      }
      final reservation = db.collection('_uploadReservations').doc();
      final fileName = '${reservation.id}.${extensions[contentType]}';
      final quota = db.collection('_uploadQuotas').doc(uid);
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      await db.runTransaction((tx) async {
        final previous = (await tx.get(quota)).data();
        final current = previous?['day'] == today;
        final bytes = current ? (previous?['bytes'] as num? ?? 0).toInt() : 0;
        final count = current ? (previous?['count'] as num? ?? 0).toInt() : 0;
        if (count >= 20 || bytes + size > 100 * 1024 * 1024) {
          throw const AccessDenied(
            429,
            'Your daily upload limit has been reached.',
          );
        }
        tx.set(quota, {
          'day': today,
          'bytes': bytes + size,
          'count': count + 1,
        });
        tx.set(db.collection('_uploadReservations').doc(fileName), {
          'userId': uid,
          'channelId': channelId,
          'size': size,
          'contentType': contentType,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().toUtc().add(const Duration(minutes: 15)),
          ),
        });
      });
      return {'path': 'resources/$channelId/$uid/$fileName'};
    case 'votePoll':
      if (role != 'student') {
        throw const AccessDenied(403, 'Only students can vote.');
      }
      await rateLimit(uid, 'votePoll', limit: 60);
      final poll = db
          .collection('communityPolls')
          .doc(documentId(body['pollId'], 'poll'));
      final option = boundedText(body['option'], 'option', 120);
      final vote = poll.collection('votes').doc(uid);
      await db.runTransaction((tx) async {
        final data = (await tx.get(poll)).data();
        final existing = await tx.get(vote);
        final options = Map<String, dynamic>.from(
          data?['options'] as Map? ?? {},
        );
        if (data?['open'] != true || !options.containsKey(option)) {
          throw const AccessDenied(400, 'This poll option is not available.');
        }
        if (existing.exists) {
          throw const AccessDenied(409, 'You have already voted.');
        }
        options[option] = (options[option] as num).toInt() + 1;
        tx.set(vote, {
          'option': option,
          'createdAt': FieldValue.serverTimestamp,
        });
        tx.update(poll, {
          'options': options,
          'updatedAt': FieldValue.serverTimestamp,
        });
      });
      return {'status': 'recorded'};
    default:
      throw const AccessDenied(400, 'Unknown operation.');
  }
}
