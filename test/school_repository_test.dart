import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_companion/src/data/firebase/school_repository.dart';
import 'package:school_companion/src/data/school_models.dart';
import 'fixtures/firestore_seed_data.dart';

void main() {
  test('writes collaboration use cases to Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    await seedSchoolCompanionData(firestore);
    final repository = FirestoreSchoolRepository(firestore);

    await repository.sendChannelMessage(
      channelId: 'swe-401',
      senderId: 'current',
      sender: 'Hendrick Emmanuel',
      body: 'This is a Firebase-backed message.',
      isLecturer: false,
    );
    final messages = await repository.watchMessages('swe-401').first;
    expect(messages.map((message) => message.body), contains('This is a Firebase-backed message.'));

    await repository.sendDirectMessage(
      senderId: 'current',
      receiverId: 'lecturer-1',
      sender: 'Hendrick Emmanuel',
      body: 'Direct Firebase message.',
    );
    final directMessages = await repository.watchDirectMessages('current').first;
    expect(directMessages.map((message) => message.body), contains('Direct Firebase message.'));

    await repository.publishAnnouncement(
      channelId: 'swe-401',
      authorId: 'lecturer-1',
      title: 'Testing checklist',
      body: 'Run widget and integration coverage.',
      author: 'Dr. Amina Yusuf',
      pinned: true,
    );
    final announcements = await repository.watchAnnouncements('swe-401').first;
    expect(announcements.map((announcement) => announcement.title), contains('Testing checklist'));

    await repository.addProjectTask(
      title: 'Verify use cases',
      owner: 'Hendrick',
      stage: 'To do',
      channelId: 'capstone-team',
      creatorId: 'current',
    );
    final tasks = await repository.watchProjectTasks().first;
    final task = tasks.firstWhere((item) => item.title == 'Verify use cases');

    await repository.moveProjectTask(taskId: task.id, stage: 'Done');
    await repository.addTaskComment(
      taskId: task.id,
      author: 'Hendrick Emmanuel',
      body: 'Moved after verification.',
      authorId: 'current',
    );
    final comments = await repository.watchTaskComments(task.id).first;
    expect(comments.single.body, 'Moved after verification.');
    expect((await repository.watchProjectTasks().first).firstWhere((item) => item.id == task.id).stage, 'Done');
  });

  test('creates poll, assessment, resource, and meeting documents', () async {
    final firestore = FakeFirebaseFirestore();
    await seedSchoolCompanionData(firestore);
    final repository = FirestoreSchoolRepository(firestore);

    await repository.createCommunityPoll(
      question: 'Preferred meeting day?',
      options: ['Monday', 'Friday'],
      author: 'Hendrick Emmanuel',
      authorId: 'current',
    );
    await repository.createAssessment(
      title: 'Chapter 3 quiz',
      channel: 'Software Engineering Project',
      channelId: 'swe-401',
      authorId: 'lecturer-1',
      instructions: 'Answer every question.',
      solution: 'Model answer.',
      kind: AssessmentKind.quiz,
      questionCount: 5,
    );
    await repository.createAssessment(
      title: 'Chapter 4 implementation exercise',
      channel: 'Software Engineering Project',
      channelId: 'swe-401',
      authorId: 'lecturer-1',
      instructions: 'Complete the implementation tasks.',
      solution: 'Reference implementation.',
      kind: AssessmentKind.exercise,
      questionCount: 2,
    );
    final assessments = await repository.watchAssessments().first;
    expect(assessments.map((assessment) => assessment.title), contains('Chapter 3 quiz'));
    expect(
      assessments.map((assessment) => assessment.kind),
      containsAll([AssessmentKind.quiz, AssessmentKind.exercise]),
    );

    await repository.addResource(
      title: 'Lecture transcript',
      kind: ResourceKind.transcript,
      channelId: 'swe-401',
      channel: 'Software Engineering Project',
      storagePath: 'resources/swe-401/current/transcript.txt',
      transcript: 'Discussed architecture and use cases.',
      notes: 'Summarize for Chapter 4.',
      uploaderId: 'current',
    );
    expect((await repository.watchResources().first).map((resource) => resource.title), contains('Lecture transcript'));
    final resource = (await repository.watchResources().first).firstWhere((item) => item.title == 'Lecture transcript');
    expect(resource.transcript, 'Discussed architecture and use cases.');
    expect(resource.notes, 'Summarize for Chapter 4.');
    expect(resource.uploaderId, 'current');
    await repository.deleteResource(resourceId: resource.id);
    expect((await repository.watchResources().first).map((item) => item.id), isNot(contains(resource.id)));

    await repository.createMeetingRequest(
      title: 'Workspace API review',
      channelId: 'swe-401',
      channel: 'Software Engineering Project',
      startsAtLabel: 'Friday, 10:00 AM',
      duration: '30 min',
      generateMeetLink: true,
      transcriptsEnabled: true,
      smartNotesEnabled: true,
      organizerId: 'lecturer-1',
      startsAt: DateTime.utc(2026, 8, 24, 10),
      endsAt: DateTime.utc(2026, 8, 24, 10, 30),
      attendees: const ['student@test.local'],
    );
    expect((await repository.watchMeetings().first).map((meeting) => meeting.title), contains('Workspace API review'));
  });

  test('creates replies and filters moderated forum posts', () async {
    final firestore = FakeFirebaseFirestore();
    await seedSchoolCompanionData(firestore);
    final repository = FirestoreSchoolRepository(firestore);

    await repository.createCommunityPost(
      title: 'Acceptance evidence discussion',
      author: 'Hendrick Emmanuel',
      tag: 'Testing',
      authorId: 'current',
    );
    final post = (await repository.watchCommunityPosts().first).firstWhere(
      (item) => item.title == 'Acceptance evidence discussion',
    );
    await repository.addCommunityReply(
      postId: post.id,
      authorId: 'current',
      author: 'Hendrick Emmanuel',
      body: 'Include expected and actual results.',
    );
    expect((await repository.watchCommunityReplies(post.id).first).single.body, 'Include expected and actual results.');

    await repository.moderateCommunityPost(postId: post.id, moderationStatus: 'hidden');
    expect(
      (await repository.watchCommunityPosts(includeHidden: false).first).map((item) => item.id),
      isNot(contains(post.id)),
    );
    expect((await repository.watchCommunityPosts().first).map((item) => item.id), contains(post.id));
  });
}
