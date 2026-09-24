import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../school_models.dart';
import 'firebase_providers.dart';
import 'backend_client.dart';
import 'push_notification_service.dart';
import 'workspace_meeting_gateway.dart';

export 'firebase_providers.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return FirestoreSchoolRepository(
    ref.watch(firestoreProvider),
    ref.watch(workspaceMeetingGatewayProvider),
    ref.watch(announcementPushGatewayProvider),
    ref.watch(collaborationGatewayProvider),
  );
});

final currentUserProvider = StreamProvider<SchoolUser?>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(schoolRepositoryProvider).watchUser(userId);
});

final channelsProvider = StreamProvider<List<LearningChannel>>((ref) {
  return ref
      .watch(accessibleChannelIdsProvider)
      .when(
        data: (ids) => ref.watch(schoolRepositoryProvider).watchChannels(ids),
        loading: () => Stream.value(const <LearningChannel>[]),
        error: Stream.error,
      );
});

final channelProvider = StreamProvider.family<LearningChannel?, String>((ref, channelId) {
  return ref.watch(schoolRepositoryProvider).watchChannel(channelId);
});

final channelMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, channelId) {
  return ref.watch(schoolRepositoryProvider).watchMessages(channelId);
});

final channelAnnouncementsProvider = StreamProvider.family<List<Announcement>, String>((ref, channelId) {
  return ref.watch(schoolRepositoryProvider).watchAnnouncements(channelId);
});

final directMessagesProvider = StreamProvider<List<DirectMessage>>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(schoolRepositoryProvider).watchDirectMessages(userId);
});

final accessibleChannelIdsProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(schoolRepositoryProvider).watchMembershipChannelIds(userId);
});

final resourcesProvider = StreamProvider<List<LearningResource>>((ref) {
  return ref
      .watch(accessibleChannelIdsProvider)
      .when(
        data: (channelIds) => ref.watch(schoolRepositoryProvider).watchResources(channelIds),
        loading: () => Stream.value(const <LearningResource>[]),
        error: Stream.error,
      );
});

final meetingsProvider = StreamProvider<List<ScheduledMeeting>>((ref) {
  return ref
      .watch(accessibleChannelIdsProvider)
      .when(
        data: (channelIds) => ref.watch(schoolRepositoryProvider).watchMeetings(channelIds),
        loading: () => Stream.value(const <ScheduledMeeting>[]),
        error: Stream.error,
      );
});

final projectTasksProvider = StreamProvider<List<ProjectTask>>((ref) {
  return ref
      .watch(accessibleChannelIdsProvider)
      .when(
        data: (channelIds) => ref.watch(schoolRepositoryProvider).watchProjectTasks(channelIds),
        loading: () => Stream.value(const <ProjectTask>[]),
        error: Stream.error,
      );
});

final taskCommentsProvider = StreamProvider.family<List<TaskComment>, String>((ref, taskId) {
  return ref.watch(schoolRepositoryProvider).watchTaskComments(taskId);
});

final communityPostsProvider = StreamProvider<List<CommunityPost>>((ref) {
  return ref
      .watch(currentUserProvider)
      .when(
        data: (user) => user == null
            ? Stream.value(const <CommunityPost>[])
            : ref.watch(schoolRepositoryProvider).watchCommunityPosts(includeHidden: user.role == UserRole.lecturer),
        loading: () => Stream.value(const <CommunityPost>[]),
        error: Stream.error,
      );
});

final communityRepliesProvider = StreamProvider.family<List<CommunityReply>, String>((ref, postId) {
  return ref.watch(schoolRepositoryProvider).watchCommunityReplies(postId);
});

final communityPollsProvider = StreamProvider<List<CommunityPoll>>((ref) {
  return ref.watch(schoolRepositoryProvider).watchCommunityPolls();
});

final assessmentsProvider = StreamProvider<List<Assessment>>((ref) {
  return ref
      .watch(accessibleChannelIdsProvider)
      .when(
        data: (channelIds) => ref.watch(schoolRepositoryProvider).watchAssessments(channelIds),
        loading: () => Stream.value(const <Assessment>[]),
        error: Stream.error,
      );
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(schoolRepositoryProvider).watchNotifications(userId);
});

abstract interface class SchoolRepository {
  Stream<SchoolUser?> watchUser(String userId);
  Stream<List<String>> watchMembershipChannelIds(String userId);
  Stream<List<LearningChannel>> watchChannels([List<String>? channelIds]);
  Stream<LearningChannel?> watchChannel(String channelId);
  Stream<List<ChatMessage>> watchMessages(String channelId);
  Stream<List<DirectMessage>> watchDirectMessages(String userId);
  Stream<List<Announcement>> watchAnnouncements(String channelId);
  Stream<List<LearningResource>> watchResources([List<String>? channelIds]);
  Stream<List<ScheduledMeeting>> watchMeetings([List<String>? channelIds]);
  Stream<List<ProjectTask>> watchProjectTasks([List<String>? channelIds]);
  Stream<List<TaskComment>> watchTaskComments(String taskId);
  Stream<List<CommunityPost>> watchCommunityPosts({bool includeHidden = true});
  Stream<List<CommunityReply>> watchCommunityReplies(String postId);
  Stream<List<CommunityPoll>> watchCommunityPolls();
  Stream<List<Assessment>> watchAssessments([List<String>? channelIds]);
  Stream<List<AppNotification>> watchNotifications(String userId);

  Future<void> ensureUserProfile({
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    required String programme,
  });

  Future<void> updateUserProfile({required String userId, required String name, required String programme});

  Future<void> markNotificationRead({required String userId, required String notificationId});

  Future<void> createChannel({
    required String title,
    required ChannelKind kind,
    required String code,
    required String summary,
    required String ownerId,
    required UserRole ownerRole,
  });

  Future<String> joinChannel({required String code, required String userId, required UserRole role});

  Future<void> sendChannelMessage({
    required String channelId,
    required String senderId,
    required String sender,
    required String body,
    required bool isLecturer,
  });

  Future<void> sendDirectMessage({
    required String senderId,
    required String receiverId,
    required String sender,
    required String body,
  });

  Future<void> publishAnnouncement({
    required String channelId,
    required String authorId,
    required String title,
    required String body,
    required String author,
    required bool pinned,
  });

  Future<void> addResource({
    required String title,
    required ResourceKind kind,
    required String channelId,
    required String channel,
    required String storagePath,
    required String transcript,
    required String notes,
    required String uploaderId,
  });

  Future<void> deleteResource({required String resourceId});

  Future<void> createMeetingRequest({
    required String title,
    required String channelId,
    required String channel,
    required String startsAtLabel,
    required String duration,
    required bool generateMeetLink,
    required bool transcriptsEnabled,
    required bool smartNotesEnabled,
    required String organizerId,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<String> attendees,
  });

  Future<void> addProjectTask({
    required String title,
    required String owner,
    required String stage,
    required String channelId,
    required String creatorId,
  });

  Future<void> moveProjectTask({required String taskId, required String stage});

  Future<void> addTaskComment({
    required String taskId,
    required String author,
    required String body,
    required String authorId,
  });

  Future<void> createCommunityPost({
    required String title,
    required String author,
    required String tag,
    required String authorId,
  });

  Future<void> addCommunityReply({
    required String postId,
    required String authorId,
    required String author,
    required String body,
  });

  Future<void> moderateCommunityPost({required String postId, required String moderationStatus});

  Future<void> createCommunityPoll({
    required String question,
    required List<String> options,
    required String author,
    required String authorId,
  });

  Future<void> votePoll({required String pollId, required String option});

  Future<void> createAssessment({
    required String title,
    required String channel,
    required AssessmentKind kind,
    required int questionCount,
    required String channelId,
    required String authorId,
    required String instructions,
    required String solution,
  });
}

class FirestoreSchoolRepository implements SchoolRepository {
  const FirestoreSchoolRepository(
    this._firestore, [
    this._workspaceGateway,
    this._pushGateway,
    this._collaborationGateway,
  ]);

  final FirebaseFirestore _firestore;
  final WorkspaceMeetingGateway? _workspaceGateway;
  final AnnouncementPushGateway? _pushGateway;
  final CollaborationGateway? _collaborationGateway;

  CollaborationGateway get _collaboration =>
      _collaborationGateway ?? (throw StateError('The collaboration service is unavailable.'));

  @override
  Stream<SchoolUser?> watchUser(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SchoolUser.fromSnapshot(doc);
    });
  }

  @override
  Stream<List<String>> watchMembershipChannelIds(String userId) {
    return _firestore
        .collectionGroup('memberships')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc.reference.parent.parent?.id).whereType<String>().toList(growable: false),
        );
  }

  @override
  Stream<List<LearningChannel>> watchChannels([List<String>? channelIds]) {
    if (channelIds != null && channelIds.isEmpty) return Stream.value([]);
    Query<Map<String, dynamic>> query = _firestore.collection('channels');
    if (channelIds != null) {
      query = query.where(FieldPath.documentId, whereIn: channelIds.take(30).toList());
    }
    return query.snapshots().map((snapshot) {
      final channels = snapshot.docs.map(LearningChannel.fromSnapshot).toList();
      channels.sort((a, b) => a.title.compareTo(b.title));
      return channels;
    });
  }

  @override
  Stream<LearningChannel?> watchChannel(String channelId) {
    return _firestore.collection('channels').doc(channelId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LearningChannel.fromSnapshot(doc);
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String channelId) {
    return _firestore
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromSnapshot).toList());
  }

  @override
  Stream<List<DirectMessage>> watchDirectMessages(String userId) {
    return _firestore
        .collection('directMessages')
        .where('participants', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(DirectMessage.fromSnapshot).toList());
  }

  @override
  Stream<List<Announcement>> watchAnnouncements(String channelId) {
    return _firestore
        .collection('announcements')
        .where('channelId', isEqualTo: channelId)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Announcement.fromSnapshot).toList());
  }

  @override
  Stream<List<LearningResource>> watchResources([List<String>? channelIds]) {
    if (channelIds != null && channelIds.isEmpty) {
      return Stream.value(const <LearningResource>[]);
    }
    Query<Map<String, dynamic>> query = _firestore.collection('resources');
    if (channelIds != null) {
      query = query.where('channelId', whereIn: channelIds.take(30).toList());
    }
    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(LearningResource.fromSnapshot).toList());
  }

  @override
  Stream<List<ScheduledMeeting>> watchMeetings([List<String>? channelIds]) {
    if (channelIds != null && channelIds.isEmpty) {
      return Stream.value(const <ScheduledMeeting>[]);
    }
    Query<Map<String, dynamic>> query = _firestore.collection('meetings');
    if (channelIds != null) {
      query = query.where('channelId', whereIn: channelIds.take(30).toList());
    }
    return query
        .orderBy('startsAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ScheduledMeeting.fromSnapshot).toList());
  }

  @override
  Stream<List<ProjectTask>> watchProjectTasks([List<String>? channelIds]) {
    if (channelIds != null && channelIds.isEmpty) {
      return Stream.value(const <ProjectTask>[]);
    }
    Query<Map<String, dynamic>> query = _firestore.collection('projectTasks');
    if (channelIds != null) {
      query = query.where('channelId', whereIn: channelIds.take(30).toList());
    }
    return query.orderBy('rank').snapshots().map((snapshot) => snapshot.docs.map(ProjectTask.fromSnapshot).toList());
  }

  @override
  Stream<List<TaskComment>> watchTaskComments(String taskId) {
    return _firestore
        .collection('projectTasks')
        .doc(taskId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TaskComment.fromSnapshot).toList());
  }

  @override
  Stream<List<CommunityPost>> watchCommunityPosts({bool includeHidden = true}) {
    Query<Map<String, dynamic>> query = _firestore.collection('communityPosts');
    if (!includeHidden) {
      query = query.where('moderationStatus', isEqualTo: 'visible');
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityPost.fromSnapshot).toList());
  }

  @override
  Stream<List<CommunityReply>> watchCommunityReplies(String postId) {
    return _firestore
        .collection('communityPosts')
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityReply.fromSnapshot).toList());
  }

  @override
  Stream<List<CommunityPoll>> watchCommunityPolls() {
    return _firestore
        .collection('communityPolls')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CommunityPoll.fromSnapshot).toList());
  }

  @override
  Stream<List<Assessment>> watchAssessments([List<String>? channelIds]) {
    if (channelIds != null && channelIds.isEmpty) {
      return Stream.value(const <Assessment>[]);
    }
    Query<Map<String, dynamic>> query = _firestore.collection('assessments');
    if (channelIds != null) {
      query = query.where('channelId', whereIn: channelIds.take(30).toList());
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Assessment.fromSnapshot).toList());
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppNotification.fromSnapshot).toList());
  }

  @override
  Future<void> ensureUserProfile({
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    required String programme,
  }) {
    return _firestore.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'role': role.name,
      'programme': programme,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateUserProfile({required String userId, required String name, required String programme}) {
    final normalizedName = name.trim();
    final normalizedProgramme = programme.trim();
    if (normalizedName.isEmpty || normalizedName.length > 100) {
      throw ArgumentError.value(name, 'name', 'Must contain 1 to 100 characters.');
    }
    if (normalizedProgramme.length > 160) {
      throw ArgumentError.value(programme, 'programme', 'Must contain at most 160 characters.');
    }
    return _firestore.collection('users').doc(userId).update({
      'name': normalizedName,
      'programme': normalizedProgramme,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markNotificationRead({required String userId, required String notificationId}) {
    return _firestore.collection('users').doc(userId).collection('notifications').doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createChannel({
    required String title,
    required ChannelKind kind,
    required String code,
    required String summary,
    required String ownerId,
    required UserRole ownerRole,
  }) async {
    await _collaboration.call({
      'action': 'createChannel',
      'title': title,
      'kind': kind.name,
      'code': code,
      'summary': summary,
    });
  }

  @override
  Future<String> joinChannel({required String code, required String userId, required UserRole role}) async {
    final result = await _collaboration.call({'action': 'joinChannel', 'code': code});
    return result['title'] as String;
  }

  @override
  Future<void> sendChannelMessage({
    required String channelId,
    required String senderId,
    required String sender,
    required String body,
    required bool isLecturer,
  }) async {
    final channel = _firestore.collection('channels').doc(channelId);
    await channel.collection('messages').add({
      'sender': sender,
      'senderId': senderId,
      'body': body,
      'timeLabel': 'Now',
      'isLecturer': isLecturer,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await channel.update({'unread': FieldValue.increment(1)});
  }

  @override
  Future<void> sendDirectMessage({
    required String senderId,
    required String receiverId,
    required String sender,
    required String body,
  }) {
    return _firestore.collection('directMessages').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'participants': [senderId, receiverId],
      'sender': sender,
      'body': body,
      'timeLabel': 'Now',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> publishAnnouncement({
    required String channelId,
    required String authorId,
    required String title,
    required String body,
    required String author,
    required bool pinned,
  }) async {
    final announcement = _firestore.collection('announcements').doc();
    final memberships = await _firestore.collection('channels').doc(channelId).collection('memberships').get();
    final batch = _firestore.batch();
    batch.set(announcement, {
      'channelId': channelId,
      'title': title,
      'body': body,
      'author': author,
      'authorId': authorId,
      'pinned': pinned,
      'publishedLabel': 'Now',
      'publishedAt': FieldValue.serverTimestamp(),
    });
    for (final membership in memberships.docs) {
      final recipientId = membership.id;
      if (recipientId == authorId) continue;
      final notification = _firestore.collection('users').doc(recipientId).collection('notifications').doc();
      batch.set(notification, {
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'read': false,
        'createdLabel': 'Now',
        'createdAt': FieldValue.serverTimestamp(),
        'announcementId': announcement.id,
        'channelId': channelId,
      });
    }
    await batch.commit();
    await _pushGateway?.dispatchAnnouncement(title: title, body: body, channelId: channelId);
  }

  @override
  Future<void> addResource({
    required String title,
    required ResourceKind kind,
    required String channelId,
    required String channel,
    required String storagePath,
    required String transcript,
    required String notes,
    required String uploaderId,
  }) {
    return _firestore.collection('resources').add({
      'title': title,
      'kind': kind.name,
      'channelId': channelId,
      'channel': channel,
      'updatedLabel': 'Now',
      'hasTranscript': transcript.trim().isNotEmpty,
      'storagePath': storagePath,
      'transcript': transcript,
      'notes': notes,
      'uploaderId': uploaderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteResource({required String resourceId}) {
    return _firestore.collection('resources').doc(resourceId).delete();
  }

  @override
  Future<void> createMeetingRequest({
    required String title,
    required String channelId,
    required String channel,
    required String startsAtLabel,
    required String duration,
    required bool generateMeetLink,
    required bool transcriptsEnabled,
    required bool smartNotesEnabled,
    required String organizerId,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<String> attendees,
  }) async {
    final meeting = _firestore.collection('meetings').doc();
    await meeting.set({
      'title': title,
      'channelId': channelId,
      'channel': channel,
      'timeLabel': startsAtLabel,
      'duration': duration,
      'status': generateMeetLink ? 'Workspace scheduling requested' : 'Calendar draft',
      'generateMeetLink': generateMeetLink,
      'transcriptsEnabled': transcriptsEnabled,
      'smartNotesEnabled': smartNotesEnabled,
      'meetUrl': '',
      'calendarEventId': '',
      'organizerId': organizerId,
      'startsAt': Timestamp.fromDate(startsAt.toUtc()),
      'endsAt': Timestamp.fromDate(endsAt.toUtc()),
      'attendees': attendees,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final gateway = _workspaceGateway;
    if (!generateMeetLink || gateway == null) return;
    try {
      final result = await gateway.schedule(
        title: title,
        description: 'Scheduled from School Companion for $channel.',
        channelId: channelId,
        startsAt: startsAt,
        endsAt: endsAt,
        attendees: attendees,
        transcriptsEnabled: transcriptsEnabled,
        smartNotesEnabled: smartNotesEnabled,
      );
      await meeting.update({
        'status': result.status,
        'calendarEventId': result.calendarEventId,
        'meetUrl': result.meetUrl,
        'workspaceMessage': result.message,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await meeting.update({
        'status': 'Scheduling failed',
        'workspaceMessage': '$error',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  @override
  Future<void> addProjectTask({
    required String title,
    required String owner,
    required String stage,
    required String channelId,
    required String creatorId,
  }) {
    return _firestore.collection('projectTasks').add({
      'title': title,
      'owner': owner,
      'stage': stage,
      'channelId': channelId,
      'creatorId': creatorId,
      'comments': 0,
      'rank': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> moveProjectTask({required String taskId, required String stage}) {
    return _firestore.collection('projectTasks').doc(taskId).update({
      'stage': stage,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addTaskComment({
    required String taskId,
    required String author,
    required String body,
    required String authorId,
  }) async {
    final task = _firestore.collection('projectTasks').doc(taskId);
    await task.collection('comments').add({
      'taskId': taskId,
      'author': author,
      'body': body,
      'authorId': authorId,
      'createdLabel': 'Now',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await task.update({'comments': FieldValue.increment(1)});
  }

  @override
  Future<void> createCommunityPost({
    required String title,
    required String author,
    required String tag,
    required String authorId,
  }) {
    return _firestore.collection('communityPosts').add({
      'title': title,
      'author': author,
      'replies': 0,
      'tag': tag,
      'authorId': authorId,
      'moderationStatus': 'visible',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> addCommunityReply({
    required String postId,
    required String authorId,
    required String author,
    required String body,
  }) async {
    final post = _firestore.collection('communityPosts').doc(postId);
    final reply = post.collection('replies').doc();
    final batch = _firestore.batch();
    batch.set(reply, {
      'authorId': authorId,
      'author': author,
      'body': body,
      'createdLabel': 'Now',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(post, {'replies': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  @override
  Future<void> moderateCommunityPost({required String postId, required String moderationStatus}) {
    return _firestore.collection('communityPosts').doc(postId).update({
      'moderationStatus': moderationStatus,
      'moderatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createCommunityPoll({
    required String question,
    required List<String> options,
    required String author,
    required String authorId,
  }) {
    return _firestore.collection('communityPolls').add({
      'question': question,
      'options': {for (final option in options) option: 0},
      'open': true,
      'author': author,
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> votePoll({required String pollId, required String option}) async {
    await _collaboration.call({'action': 'votePoll', 'pollId': pollId, 'option': option});
  }

  @override
  Future<void> createAssessment({
    required String title,
    required String channel,
    required AssessmentKind kind,
    required int questionCount,
    required String channelId,
    required String authorId,
    required String instructions,
    required String solution,
  }) {
    return _firestore.collection('assessments').add({
      'title': title,
      'channel': channel,
      'kind': kind.name,
      'questionCount': questionCount,
      'channelId': channelId,
      'authorId': authorId,
      'status': 'Open',
      'instructions': instructions,
      'solution': solution,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
