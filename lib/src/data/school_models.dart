import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum UserRole { lecturer, student }

enum ChannelKind { course, project, studentOnly }

enum ResourceKind { pdf, audio, video, transcript }

enum AssessmentKind { quiz, exercise }

class SchoolUser {
  const SchoolUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.programme,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String programme;

  factory SchoolUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SchoolUser(
      id: doc.id,
      name: data.string('name', fallback: 'School Companion User'),
      email: data.string('email'),
      role: _enumFromName(UserRole.values, data.string('role'), UserRole.student),
      programme: data.string('programme'),
    );
  }
}

class LearningChannel {
  const LearningChannel({
    required this.id,
    required this.title,
    required this.kind,
    required this.code,
    required this.summary,
    required this.members,
    required this.unread,
    required this.color,
  });

  final String id;
  final String title;
  final ChannelKind kind;
  final String code;
  final String summary;
  final int members;
  final int unread;
  final Color color;

  factory LearningChannel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LearningChannel(
      id: doc.id,
      title: data.string('title', fallback: 'Untitled channel'),
      kind: _enumFromName(ChannelKind.values, data.string('kind'), ChannelKind.course),
      code: data.string('code'),
      summary: data.string('summary'),
      members: data.integer('members'),
      unread: data.integer('unread'),
      color: _colorFromHex(data.string('colorHex'), const Color(0xFF0A3150)),
    );
  }
}

class ChannelMembership {
  const ChannelMembership({
    required this.id,
    required this.userId,
    required this.channelId,
    required this.role,
    required this.status,
  });

  final String id;
  final String userId;
  final String channelId;
  final UserRole role;
  final String status;

  factory ChannelMembership.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChannelMembership(
      id: doc.id,
      userId: data.string('userId'),
      channelId: data.string('channelId'),
      role: _enumFromName(UserRole.values, data.string('role'), UserRole.student),
      status: data.string('status', fallback: 'active'),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.time,
    required this.isLecturer,
  });

  final String id;
  final String sender;
  final String body;
  final String time;
  final bool isLecturer;

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      sender: data.string('sender', fallback: 'Unknown sender'),
      body: data.string('body'),
      time: data.string('timeLabel'),
      isLecturer: data.boolean('isLecturer'),
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.sender,
    required this.body,
    required this.time,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String sender;
  final String body;
  final String time;

  factory DirectMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DirectMessage(
      id: doc.id,
      senderId: data.string('senderId'),
      receiverId: data.string('receiverId'),
      sender: data.string('sender', fallback: 'School Companion User'),
      body: data.string('body'),
      time: data.string('timeLabel', fallback: 'Now'),
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.channelId,
    required this.title,
    required this.body,
    required this.author,
    required this.pinned,
    required this.published,
  });

  final String id;
  final String channelId;
  final String title;
  final String body;
  final String author;
  final bool pinned;
  final String published;

  factory Announcement.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Announcement(
      id: doc.id,
      channelId: data.string('channelId'),
      title: data.string('title', fallback: 'Announcement'),
      body: data.string('body'),
      author: data.string('author', fallback: 'Lecturer'),
      pinned: data.boolean('pinned'),
      published: data.string('publishedLabel', fallback: 'Recently'),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.created,
  });

  final String id;
  final String title;
  final String body;
  final bool read;
  final String created;

  factory AppNotification.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      title: data.string('title', fallback: 'Notification'),
      body: data.string('body'),
      read: data.boolean('read'),
      created: data.string('createdLabel', fallback: 'Now'),
    );
  }
}

class LearningResource {
  const LearningResource({
    required this.id,
    required this.title,
    required this.kind,
    required this.channelId,
    required this.channel,
    required this.updated,
    required this.hasTranscript,
    required this.storagePath,
    required this.transcript,
    required this.notes,
    required this.uploaderId,
  });

  final String id;
  final String title;
  final ResourceKind kind;
  final String channelId;
  final String channel;
  final String updated;
  final bool hasTranscript;
  final String storagePath;
  final String transcript;
  final String notes;
  final String uploaderId;

  factory LearningResource.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LearningResource(
      id: doc.id,
      title: data.string('title', fallback: 'Untitled resource'),
      kind: _enumFromName(ResourceKind.values, data.string('kind'), ResourceKind.pdf),
      channelId: data.string('channelId'),
      channel: data.string('channel'),
      updated: data.string('updatedLabel'),
      hasTranscript: data.boolean('hasTranscript'),
      storagePath: data.string('storagePath'),
      transcript: data.string('transcript'),
      notes: data.string('notes'),
      uploaderId: data.string('uploaderId'),
    );
  }
}

class ScheduledMeeting {
  const ScheduledMeeting({
    required this.id,
    required this.title,
    required this.channelId,
    required this.channel,
    required this.time,
    required this.duration,
    required this.status,
    required this.meetUrl,
    required this.calendarEventId,
    required this.transcriptsEnabled,
    required this.smartNotesEnabled,
  });

  final String id;
  final String title;
  final String channelId;
  final String channel;
  final String time;
  final String duration;
  final String status;
  final String meetUrl;
  final String calendarEventId;
  final bool transcriptsEnabled;
  final bool smartNotesEnabled;

  factory ScheduledMeeting.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ScheduledMeeting(
      id: doc.id,
      title: data.string('title', fallback: 'Untitled meeting'),
      channelId: data.string('channelId'),
      channel: data.string('channel'),
      time: data.string('timeLabel'),
      duration: data.string('duration'),
      status: data.string('status'),
      meetUrl: data.string('meetUrl'),
      calendarEventId: data.string('calendarEventId'),
      transcriptsEnabled: data.boolean('transcriptsEnabled'),
      smartNotesEnabled: data.boolean('smartNotesEnabled'),
    );
  }
}

class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.title,
    required this.owner,
    required this.stage,
    required this.comments,
  });

  final String id;
  final String title;
  final String owner;
  final String stage;
  final int comments;

  factory ProjectTask.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ProjectTask(
      id: doc.id,
      title: data.string('title', fallback: 'Untitled task'),
      owner: data.string('owner'),
      stage: data.string('stage', fallback: 'To do'),
      comments: data.integer('comments'),
    );
  }
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.author,
    required this.body,
    required this.created,
  });

  final String id;
  final String taskId;
  final String author;
  final String body;
  final String created;

  factory TaskComment.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TaskComment(
      id: doc.id,
      taskId: data.string('taskId'),
      author: data.string('author', fallback: 'Contributor'),
      body: data.string('body'),
      created: data.string('createdLabel', fallback: 'Now'),
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.title,
    required this.author,
    required this.replies,
    required this.tag,
    required this.authorId,
    required this.moderationStatus,
  });

  final String id;
  final String title;
  final String author;
  final int replies;
  final String tag;
  final String authorId;
  final String moderationStatus;

  factory CommunityPost.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CommunityPost(
      id: doc.id,
      title: data.string('title', fallback: 'Untitled discussion'),
      author: data.string('author'),
      replies: data.integer('replies'),
      tag: data.string('tag'),
      authorId: data.string('authorId'),
      moderationStatus: data.string('moderationStatus', fallback: 'visible'),
    );
  }
}

class CommunityReply {
  const CommunityReply({
    required this.id,
    required this.authorId,
    required this.author,
    required this.body,
    required this.created,
  });

  final String id;
  final String authorId;
  final String author;
  final String body;
  final String created;

  factory CommunityReply.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CommunityReply(
      id: doc.id,
      authorId: data.string('authorId'),
      author: data.string('author', fallback: 'Student'),
      body: data.string('body'),
      created: data.string('createdLabel', fallback: 'Now'),
    );
  }
}

class CommunityPoll {
  const CommunityPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.open,
    required this.author,
  });

  final String id;
  final String question;
  final Map<String, int> options;
  final bool open;
  final String author;

  int get totalVotes => options.values.fold(0, (total, votes) => total + votes);

  factory CommunityPoll.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawOptions = data['options'];
    return CommunityPoll(
      id: doc.id,
      question: data.string('question', fallback: 'Poll'),
      options: rawOptions is Map
          ? rawOptions.map((key, value) => MapEntry('$key', value is num ? value.toInt() : 0))
          : const <String, int>{},
      open: data.boolean('open', fallback: true),
      author: data.string('author', fallback: 'Student'),
    );
  }
}

class Assessment {
  const Assessment({
    required this.id,
    required this.title,
    required this.channel,
    required this.kind,
    required this.questionCount,
    required this.status,
    required this.instructions,
    required this.solution,
  });

  final String id;
  final String title;
  final String channel;
  final AssessmentKind kind;
  final int questionCount;
  final String status;
  final String instructions;
  final String solution;

  factory Assessment.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Assessment(
      id: doc.id,
      title: data.string('title', fallback: 'Assessment'),
      channel: data.string('channel'),
      kind: _enumFromName(AssessmentKind.values, data.string('kind'), AssessmentKind.quiz),
      questionCount: data.integer('questionCount'),
      status: data.string('status', fallback: 'Draft'),
      instructions: data.string('instructions'),
      solution: data.string('solution'),
    );
  }
}

extension SchoolMapReader on Map<String, dynamic> {
  String string(String key, {String fallback = ''}) {
    final value = this[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  int integer(String key, {int fallback = 0}) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  bool boolean(String key, {bool fallback = false}) {
    final value = this[key];
    return value is bool ? value : fallback;
  }
}

T _enumFromName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

Color _colorFromHex(String value, Color fallback) {
  final normalized = value.replaceFirst('#', '');
  if (normalized.length == 6) {
    return Color(int.parse('FF$normalized', radix: 16));
  }
  if (normalized.length == 8) {
    return Color(int.parse(normalized, radix: 16));
  }
  return fallback;
}
