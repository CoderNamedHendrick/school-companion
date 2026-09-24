import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  Timestamp,
  where,
} from 'firebase/firestore';
import {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} from 'firebase/storage';

const projectId = 'demo-school-companion';
let env;

const profile = (role, email) => ({
  name: role === 'lecturer' ? 'Dr. Test Lecturer' : 'Test Student',
  email,
  programme: 'Software Engineering',
  role,
});

const membership = (userId, channelId, role) => ({
  userId,
  channelId,
  role,
  status: 'active',
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
    storage: {
      rules: await readFile(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users', 'lecturer'), profile('lecturer', 'lecturer@test.local')),
      setDoc(doc(db, 'users', 'studentA'), profile('student', 'a@test.local')),
      setDoc(doc(db, 'users', 'studentB'), profile('student', 'b@test.local')),
      setDoc(doc(db, 'channels', 'course'), {
        title: 'Secure Course', kind: 'course', createdBy: 'lecturer', members: 2,
      }),
      setDoc(doc(db, 'channels', 'private'), {
        title: 'Private Group', kind: 'studentOnly', createdBy: 'studentB', members: 1,
      }),
    ]);
    await Promise.all([
      setDoc(doc(db, 'channels', 'course', 'memberships', 'lecturer'), membership('lecturer', 'course', 'lecturer')),
      setDoc(doc(db, 'channels', 'course', 'memberships', 'studentA'), membership('studentA', 'course', 'student')),
      setDoc(doc(db, 'channels', 'private', 'memberships', 'studentB'), membership('studentB', 'private', 'student')),
    ]);
  });
});

after(async () => env?.cleanup());

describe('authentication and roles', () => {
  it('rejects unauthenticated reads and lecturer self-promotion', async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'channels', 'course')));
    const db = env.authenticatedContext('newUser', {email_verified: true, email: 'new@test.local'}).firestore();
    await assertFails(setDoc(doc(db, 'users', 'newUser'), profile('lecturer', 'new@test.local')));
    await assertSucceeds(setDoc(doc(db, 'users', 'newUser'), profile('student', 'new@test.local')));
    await assertSucceeds(updateDoc(doc(db, 'users', 'newUser'), {
      name: 'Updated Student', programme: 'Computer Science',
    }));
    await assertFails(updateDoc(doc(db, 'users', 'newUser'), {role: 'lecturer'}));
    await assertFails(updateDoc(doc(db, 'users', 'newUser'), {email_verified: true, email: 'attacker@test.local'}));
    await assertFails(updateDoc(doc(db, 'users', 'newUser'), {name: ''}));
    await assertFails(updateDoc(doc(db, 'users', 'newUser'), {admin: true}));
  });
});

describe('channel membership isolation', () => {
  it('requires the backend to create channels', async () => {
    const db = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    await assertFails(setDoc(doc(db, 'channels', 'owned'), {
      title: 'Owned Channel', kind: 'project', createdBy: 'studentA',
    }));
    await assertFails(getDoc(doc(db, 'channels', 'private')));
    await assertFails(getDocs(collection(db, 'channels')));
    await assertSucceeds(getDoc(doc(db, 'channels', 'course')));
  });

  it('allows members to chat and rejects outsiders and sender spoofing', async () => {
    const memberDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const outsiderDb = env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).firestore();
    const payload = {senderId: 'studentA', sender: 'Test Student', body: 'Hello', isLecturer: false};
    await assertSucceeds(addDoc(collection(memberDb, 'channels', 'course', 'messages'), payload));
    await assertFails(addDoc(collection(outsiderDb, 'channels', 'course', 'messages'), {...payload, senderId: 'studentB'}));
    await assertFails(addDoc(collection(memberDb, 'channels', 'course', 'messages'), {...payload, senderId: 'studentB'}));
    await assertFails(addDoc(collection(memberDb, 'channels', 'course', 'messages'), {...payload, sender: 'Dr. Test Lecturer'}));
    await assertFails(addDoc(collection(memberDb, 'channels', 'course', 'messages'), {...payload, isLecturer: true}));
  });

  it('rejects self enrollment and forged memberships', async () => {
    const db = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    await assertFails(setDoc(
      doc(db, 'channels', 'private', 'memberships', 'studentA'),
      membership('studentA', 'private', 'student'),
    ));
    await assertFails(setDoc(
      doc(db, 'channels', 'private', 'memberships', 'studentB'),
      membership('studentB', 'private', 'student'),
    ));
    await assertFails(setDoc(
      doc(db, 'channels', 'private', 'memberships', 'studentA'),
      membership('studentA', 'private', 'lecturer'),
    ));
  });

  it('discovers only the current user memberships for scoped collection queries', async () => {
    const memberDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const memberships = await assertSucceeds(getDocs(query(
      collectionGroup(memberDb, 'memberships'),
      where('userId', '==', 'studentA'),
    )));
    assert.deepEqual(
      memberships.docs.map((item) => item.data().channelId),
      ['course'],
    );
    await assertFails(getDocs(query(
      collectionGroup(memberDb, 'memberships'),
      where('userId', '==', 'studentB'),
    )));
  });

  it('rejects client member-count updates and self enrollment in a transaction', async () => {
    const db = env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).firestore();
    await assertFails(runTransaction(db, async (tx) => {
      tx.set(doc(db, 'channels/course/memberships/studentB'), membership('studentB', 'course', 'student'));
      tx.update(doc(db, 'channels/course'), {members: 3});
    }));
  });

});

describe('lecturer-only workflows', () => {
  it('allows a lecturer announcement and assessment but rejects a student', async () => {
    const lecturerDb = env.authenticatedContext('lecturer', {email_verified: true, email: 'lecturer@test.local'}).firestore();
    const studentDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const announcement = {channelId: 'course', title: 'Notice', body: 'Read this', author: 'Dr. Test Lecturer', authorId: 'lecturer', pinned: true};
    await assertSucceeds(addDoc(collection(lecturerDb, 'announcements'), announcement));
    await assertFails(addDoc(collection(studentDb, 'announcements'), {...announcement, authorId: 'studentA'}));
    const assessment = {channelId: 'course', title: 'Quiz', authorId: 'lecturer', kind: 'quiz'};
    await assertSucceeds(addDoc(collection(lecturerDb, 'assessments'), assessment));
    await assertFails(addDoc(collection(studentDb, 'assessments'), {...assessment, authorId: 'studentA'}));
  });

  it('allows only a lecturer member to schedule a meeting', async () => {
    const lecturerDb = env.authenticatedContext('lecturer', {email_verified: true, email: 'lecturer@test.local'}).firestore();
    const studentDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const meeting = {channelId: 'course', organizerId: 'lecturer', title: 'Review'};
    await assertSucceeds(addDoc(collection(lecturerDb, 'meetings'), meeting));
    await assertFails(addDoc(collection(studentDb, 'meetings'), {...meeting, organizerId: 'studentA'}));
  });

  it('fans in-app notifications out only from lecturers', async () => {
    const lecturerDb = env.authenticatedContext('lecturer', {email_verified: true, email: 'lecturer@test.local'}).firestore();
    const studentDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const notice = {channelId: 'course', recipientId: 'studentA', title: 'Notice', body: 'Review', read: false};
    await assertSucceeds(setDoc(doc(lecturerDb, 'users', 'studentA', 'notifications', 'n1'), notice));
    await assertSucceeds(getDoc(doc(studentDb, 'users', 'studentA', 'notifications', 'n1')));
    await assertSucceeds(updateDoc(doc(studentDb, 'users', 'studentA', 'notifications', 'n1'), {read: true}));
    await assertFails(setDoc(doc(studentDb, 'users', 'studentB', 'notifications', 'n2'), {...notice, recipientId: 'studentB'}));
  });
});

describe('collaboration integrity', () => {
  it('protects direct messages from non-participants', async () => {
    const senderDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const message = doc(collection(senderDb, 'directMessages'));
    await assertSucceeds(setDoc(message, {
      senderId: 'studentA', receiverId: 'lecturer', participants: ['studentA', 'lecturer'], sender: 'Test Student', body: 'Question',
    }));
    await assertSucceeds(getDoc(message));
    await assertFails(getDoc(doc(env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).firestore(), 'directMessages', message.id)));
  });

  it('allows task collaboration only for channel members', async () => {
    const memberDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const outsiderDb = env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).firestore();
    const task = {channelId: 'course', creatorId: 'studentA', title: 'Test task', stage: 'To do'};
    await assertSucceeds(setDoc(doc(memberDb, 'projectTasks', 'task1'), task));
    await assertSucceeds(updateDoc(doc(memberDb, 'projectTasks', 'task1'), {stage: 'Done'}));
    await assertFails(updateDoc(doc(outsiderDb, 'projectTasks', 'task1'), {stage: 'Done'}));
    await assertFails(updateDoc(doc(memberDb, 'projectTasks', 'task1'), {creatorId: 'studentB'}));
    await assertSucceeds(addDoc(collection(memberDb, 'projectTasks', 'task1', 'comments'), {
      authorId: 'studentA', author: 'Test Student', body: 'Verified',
    }));
    await assertFails(addDoc(collection(outsiderDb, 'projectTasks', 'task1', 'comments'), {
      authorId: 'studentB', author: 'Test Student', body: 'Intrusion',
    }));
  });

  it('isolates resource metadata and assessments by channel membership', async () => {
    const memberDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const outsiderDb = env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).firestore();
    await assertSucceeds(setDoc(doc(memberDb, 'resources', 'owned'), {
      channelId: 'course', uploaderId: 'studentA', title: 'Member PDF', kind: 'pdf',
      storagePath: 'resources/course/studentA/member.pdf',
    }));
    await assertFails(updateDoc(doc(memberDb, 'resources', 'owned'), {uploaderId: 'studentB'}));
    await assertFails(setDoc(doc(memberDb, 'resources', 'spoofed-path'), {
      channelId: 'course', uploaderId: 'studentA', title: 'Spoof', kind: 'pdf',
      storagePath: 'resources/course/studentB/spoof.pdf',
    }));
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'resources', 'r1'), {
        channelId: 'course', uploaderId: 'studentA', title: 'Private resource',
      });
      await setDoc(doc(context.firestore(), 'assessments', 'a1'), {
        channelId: 'course', authorId: 'lecturer', title: 'Member quiz',
      });
    });
    await assertSucceeds(getDoc(doc(memberDb, 'resources', 'r1')));
    await assertFails(getDoc(doc(outsiderDb, 'resources', 'r1')));
    await assertSucceeds(getDoc(doc(memberDb, 'assessments', 'a1')));
    await assertFails(getDoc(doc(outsiderDb, 'assessments', 'a1')));
  });

  it('prevents students from rewriting poll identity fields and client-written vote totals', async () => {
    const authorDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const voterDb = env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).firestore();
    await assertSucceeds(setDoc(doc(authorDb, 'communityPolls', 'poll'), {
      authorId: 'studentA', author: 'Test Student', question: 'Choose', options: {Yes: 0, No: 0}, open: true,
    }));
    await assertFails(updateDoc(doc(voterDb, 'communityPolls', 'poll'), {options: {Yes: 1, No: 0}}));
    await assertFails(setDoc(doc(voterDb, 'communityPolls/poll/votes/studentB'), {option: 'Yes'}));
    await assertFails(updateDoc(doc(voterDb, 'communityPolls', 'poll'), {question: 'Tampered'}));
  });

  it('allows student forum replies, rejects lecturer-authored posts, and permits moderation', async () => {
    const studentDb = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).firestore();
    const lecturerDb = env.authenticatedContext('lecturer', {email_verified: true, email: 'lecturer@test.local'}).firestore();
    await assertSucceeds(setDoc(doc(studentDb, 'communityPosts', 'post'), {
      authorId: 'studentA', author: 'Test Student', title: 'Topic', replies: 0, moderationStatus: 'visible',
    }));
    await assertFails(setDoc(doc(lecturerDb, 'communityPosts', 'lecturer-post'), {
      authorId: 'lecturer', author: 'Dr. Test Lecturer', title: 'Not student-led', replies: 0,
    }));
    await assertSucceeds(setDoc(doc(studentDb, 'communityPosts', 'post', 'replies', 'r1'), {
      authorId: 'studentA', author: 'Test Student', body: 'Reply',
    }));
    await assertSucceeds(updateDoc(doc(lecturerDb, 'communityPosts', 'post'), {moderationStatus: 'hidden'}));
    await assertSucceeds(getDoc(doc(lecturerDb, 'communityPosts', 'post')));
    await assertFails(getDoc(doc(studentDb, 'communityPosts', 'post')));
    await assertFails(setDoc(doc(studentDb, 'communityPosts', 'post', 'replies', 'r2'), {
      authorId: 'studentA', author: 'Test Student', body: 'Hidden reply',
    }));
  });
});

describe('resource storage', () => {
  it('allows member PDF/audio/video and blocks path spoofing, outsiders, and executables', async () => {
    const memberStorage = env.authenticatedContext('studentA', {email_verified: true, email: 'a@test.local'}).storage();
    const outsiderStorage = env.authenticatedContext('studentB', {email_verified: true, email: 'b@test.local'}).storage();
    const lecturerStorage = env.authenticatedContext('lecturer', {email_verified: true, email: 'lecturer@test.local'}).storage();
    await env.withSecurityRulesDisabled(async context => {
      for (const [name, size, contentType] of [['evidence.pdf', 4, 'application/pdf'], ['audio.mp3', 3, 'audio/mpeg'], ['video.mp4', 4, 'video/mp4']]) {
        await setDoc(doc(context.firestore(), '_uploadReservations', name), {
          userId: 'studentA', channelId: 'course', size, contentType,
          expiresAt: Timestamp.fromMillis(Date.now() + 60000),
        });
      }
    });
    const path = 'resources/course/studentA/evidence.pdf';
    await assertSucceeds(uploadBytes(ref(memberStorage, path), new Uint8Array([37, 80, 68, 70]), {contentType: 'application/pdf'}));
    await assertSucceeds(uploadBytes(ref(memberStorage, 'resources/course/studentA/audio.mp3'), new Uint8Array([73, 68, 51]), {contentType: 'audio/mpeg'}));
    const videoPath = 'resources/course/studentA/video.mp4';
    await assertSucceeds(uploadBytes(ref(memberStorage, videoPath), new Uint8Array([0, 0, 0, 24]), {contentType: 'video/mp4'}));
    await assertSucceeds(getBytes(ref(memberStorage, path)));
    await assertFails(getBytes(ref(outsiderStorage, path)));
    await assertFails(uploadBytes(ref(memberStorage, 'resources/course/studentB/spoof.pdf'), new Uint8Array([37, 80, 68, 70]), {contentType: 'application/pdf'}));
    await assertFails(uploadBytes(ref(memberStorage, 'resources/course/studentA/tool.bin'), new Uint8Array([1]), {contentType: 'application/octet-stream'}));
    await assertFails(deleteObject(ref(lecturerStorage, videoPath)));
    await assertFails(uploadBytes(ref(memberStorage, path), new Uint8Array([37, 80, 68, 70]), {contentType: 'application/pdf'}));
    await assertFails(uploadBytes(ref(memberStorage, 'resources/course/studentA/unreserved.pdf'), new Uint8Array([37, 80, 68, 70]), {contentType: 'application/pdf'}));
  });
});


describe('security regressions', () => {
  it('denies content access to an unverified account', async () => {
    const db = env.authenticatedContext('studentA', {email_verified: false, email: 'a@test.local'}).firestore();
    await assertFails(getDoc(doc(db, 'channels/course')));
    await assertFails(addDoc(collection(db, 'channels/course/messages'), {
      senderId: 'studentA', sender: 'Test Student', body: 'Blocked', isLecturer: false,
    }));
  });
  it('denies client reads and writes to private invitations and quota records', async () => {
    const db = env.authenticatedContext('lecturer', {email_verified: true}).firestore();
    for (const path of ['_channelInvites/test', '_rateLimits/test']) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), {channelId: 'course', count: 0}));
    }
  });
  it('rejects suspended memberships even when the document exists', async () => {
    await env.withSecurityRulesDisabled(async context => {
      await updateDoc(doc(context.firestore(), 'channels/course/memberships/studentA'), {status: 'suspended'});
    });
    const db = env.authenticatedContext('studentA', {email_verified: true}).firestore();
    await assertFails(getDoc(doc(db, 'channels/course')));
    await assertFails(updateDoc(doc(db, 'channels/course/memberships/studentA'), {status: 'active'}));
  });
  it('rejects unknown message fields and oversized bodies', async () => {
    const db = env.authenticatedContext('studentA', {email_verified: true}).firestore();
    const message = {senderId: 'studentA', sender: 'Test Student', body: 'Hello', isLecturer: false};
    await assertFails(addDoc(collection(db, 'channels/course/messages'), {...message, admin: true}));
    await assertFails(addDoc(collection(db, 'channels/course/messages'), {...message, body: 'x'.repeat(4001)}));
  });
});
