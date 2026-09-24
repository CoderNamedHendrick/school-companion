import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedSchoolCompanionData(FirebaseFirestore firestore) async {
  await firestore.collection('users').doc('current').set({
    'name': 'Hendrick Emmanuel',
    'email': 'hendrick@student.miva.edu.ng',
    'role': 'student',
    'programme': 'BSc. Software Engineering',
  });
  await firestore.collection('users').doc('current').collection('notifications').doc('n1').set({
    'title': 'Implementation review scheduled',
    'body': 'Your supervisor added a Google Meet review session.',
    'read': false,
    'recipientId': 'current',
    'createdLabel': 'Now',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(7000),
  });

  await firestore.collection('channels').doc('swe-401').set({
    'title': 'Software Engineering Project',
    'kind': 'course',
    'code': 'SWE 401',
    'summary': 'Supervisor feedback, proposal milestones, and implementation notes.',
    'members': 84,
    'unread': 12,
    'colorHex': '#0A3150',
    'createdBy': 'lecturer-1',
  });
  await firestore.collection('channels').doc('capstone-team').set({
    'title': 'Capstone Build Team',
    'kind': 'project',
    'code': 'PROJECT',
    'summary': 'Kanban tasks, weekly standups, and shared deliverables.',
    'members': 6,
    'unread': 4,
    'colorHex': '#B79A7F',
    'createdBy': 'current',
  });
  await firestore.collection('users').doc('lecturer-1').set({
    'name': 'Dr. Amina Yusuf',
    'email': 'amina@lecturer.miva.edu.ng',
    'role': 'lecturer',
    'programme': 'Software Engineering',
  });
  for (final entry in const [
    ('swe-401', 'current', 'student'),
    ('swe-401', 'lecturer-1', 'lecturer'),
    ('capstone-team', 'current', 'student'),
  ]) {
    await firestore.collection('channels').doc(entry.$1).collection('memberships').doc(entry.$2).set({
      'userId': entry.$2,
      'channelId': entry.$1,
      'role': entry.$3,
      'status': 'active',
    });
  }

  await firestore.collection('channels').doc('swe-401').collection('messages').doc('m1').set({
    'sender': 'Dr. Amina Yusuf',
    'senderId': 'lecturer-1',
    'body': 'Please upload your implementation plan before Friday so I can review the Firebase data model.',
    'timeLabel': '9:30 AM',
    'isLecturer': true,
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
  });
  await firestore.collection('channels').doc('swe-401').collection('messages').doc('m2').set({
    'sender': 'Hendrick Emmanuel',
    'senderId': 'current',
    'body': 'I have updated chapters 1 to 3 and started the Flutter project structure.',
    'timeLabel': '9:42 AM',
    'isLecturer': false,
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
  });

  await firestore.collection('directMessages').doc('dm1').set({
    'senderId': 'lecturer-1',
    'receiverId': 'current',
    'participants': ['lecturer-1', 'current'],
    'sender': 'Dr. Amina Yusuf',
    'body': 'Send me your latest build notes after the integration test.',
    'timeLabel': '8:15 AM',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(2500),
  });

  await firestore.collection('resources').doc('r1').set({
    'title': 'Project Methodology Guide.pdf',
    'kind': 'pdf',
    'channelId': 'swe-401',
    'channel': 'Software Engineering Project',
    'updatedLabel': 'Today',
    'hasTranscript': false,
    'storagePath': 'resources/swe-401/lecturer-1/methodology-guide.pdf',
    'transcript': '',
    'notes': 'Chapter 3 methodology reference.',
    'uploaderId': 'lecturer-1',
    'updatedAt': Timestamp.fromMillisecondsSinceEpoch(4000),
  });
  await firestore.collection('resources').doc('r2').set({
    'title': 'Firebase Data Modeling Walkthrough',
    'kind': 'video',
    'channelId': 'capstone-team',
    'channel': 'Capstone Build Team',
    'updatedLabel': 'Yesterday',
    'hasTranscript': true,
    'storagePath': 'resources/capstone-team/current/firebase-modeling.mp4',
    'transcript': 'Firestore collections, roles, and channel membership.',
    'notes': 'Use subcollections for messages and comments.',
    'uploaderId': 'current',
    'updatedAt': Timestamp.fromMillisecondsSinceEpoch(3000),
  });

  await firestore.collection('meetings').doc('meeting-1').set({
    'title': 'Chapter 4 implementation review',
    'channelId': 'swe-401',
    'channel': 'Software Engineering Project',
    'timeLabel': 'Wed, 11:00 AM',
    'duration': '45 min',
    'status': 'Meet link ready',
    'meetUrl': 'https://meet.google.com/example',
    'calendarEventId': 'calendar-event-1',
    'transcriptsEnabled': true,
    'smartNotesEnabled': true,
    'organizerId': 'lecturer-1',
    'startsAt': Timestamp.fromMillisecondsSinceEpoch(5000),
  });

  await firestore.collection('announcements').doc('a1').set({
    'channelId': 'swe-401',
    'title': 'Proposal defense checklist',
    'body': 'Pin your problem statement, architecture, and testing plan.',
    'author': 'Dr. Amina Yusuf',
    'authorId': 'lecturer-1',
    'pinned': true,
    'publishedLabel': 'Today',
    'publishedAt': Timestamp.fromMillisecondsSinceEpoch(5500),
  });

  await firestore.collection('projectTasks').doc('task-1').set({
    'title': 'Define Firestore collections',
    'owner': 'Hendrick',
    'stage': 'To do',
    'comments': 2,
    'rank': 1,
    'channelId': 'capstone-team',
    'creatorId': 'current',
  });
  await firestore.collection('projectTasks').doc('task-2').set({
    'title': 'Build responsive channel dashboard',
    'owner': 'Hendrick',
    'stage': 'In progress',
    'comments': 5,
    'rank': 2,
    'channelId': 'capstone-team',
    'creatorId': 'current',
  });
  await firestore.collection('projectTasks').doc('task-1').collection('comments').doc('c1').set({
    'taskId': 'task-1',
    'author': 'Dr. Amina Yusuf',
    'body': 'Include role and membership rules in the model.',
    'authorId': 'lecturer-1',
    'createdLabel': 'Today',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(6100),
  });

  await firestore.collection('communityPosts').doc('post-1').set({
    'title': 'Best format for final-year project questionnaires?',
    'author': 'Adaobi',
    'replies': 18,
    'tag': 'Research',
    'authorId': 'current',
    'moderationStatus': 'visible',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(6000),
  });
  await firestore.collection('communityPosts').doc('post-1').collection('replies').doc('reply-1').set({
    'authorId': 'current',
    'author': 'Hendrick Emmanuel',
    'body': 'A concise Likert-scale questionnaire works well for UAT.',
    'createdLabel': 'Today',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(6050),
  });
  await firestore.collection('communityPolls').doc('poll-1').set({
    'question': 'Which chapter should we review together next?',
    'options': {'Chapter 4': 6, 'Chapter 5': 3},
    'open': true,
    'author': 'Adaobi',
    'authorId': 'current',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(6200),
  });
  await firestore.collection('assessments').doc('quiz-1').set({
    'title': 'Firestore security rules quick quiz',
    'channel': 'Software Engineering Project',
    'kind': 'quiz',
    'questionCount': 8,
    'status': 'Open',
    'channelId': 'swe-401',
    'authorId': 'lecturer-1',
    'instructions': 'Answer eight questions about authentication and access control.',
    'solution': 'Use least privilege, membership checks, and immutable role fields.',
    'createdAt': Timestamp.fromMillisecondsSinceEpoch(6300),
  });
}
