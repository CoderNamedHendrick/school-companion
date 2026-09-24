import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const authBase = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const functionsBase =
  'http://127.0.0.1:5001/school-companion-project/europe-west1';

async function signIn(email) {
  const response = await fetch(
    `${authBase}/accounts:signInWithPassword?key=emulator-key`,
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({email, password: 'TestPass123!', returnSecureToken: true}),
    },
  );
  const text = await response.text();
  assert.equal(response.status, 200, text);
  return JSON.parse(text).idToken;
}

async function post(functionName, body, token) {
  const response = await fetch(`${functionsBase}/${functionName}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? {authorization: `Bearer ${token}`} : {}),
    },
    body: JSON.stringify(body),
  });
  return {status: response.status, body: await response.json()};
}

const meeting = {
  title: 'Emulator integration review',
  description: 'Verify authenticated Calendar gateway behavior.',
  channelId: 'swe-401',
  startIso: '2026-08-24T10:00:00.000Z',
  endIso: '2026-08-24T10:45:00.000Z',
  attendees: ['student1@test.local'],
  transcriptsEnabled: true,
  smartNotesEnabled: true,
};

describe('Firebase Functions emulator', () => {
  it('requires authentication and a lecturer role for meeting scheduling', async () => {
    const unauthenticated = await post('schedule-google-workspace-meeting', meeting);
    assert.equal(unauthenticated.status, 401);

    const student = await signIn('student1@test.local');
    const forbidden = await post('schedule-google-workspace-meeting', meeting, student);
    assert.equal(forbidden.status, 403);

    const lecturer = await signIn('lecturer@test.local');
    const accepted = await post('schedule-google-workspace-meeting', meeting, lecturer);
    assert.equal(accepted.status, 200);
    assert.equal(accepted.body.status, 'emulated');
    assert.equal(accepted.body.calendarEventId, 'emulator-calendar-event');
  });

  it('dispatches announcement push through the authenticated emulator path', async () => {
    const lecturer = await signIn('lecturer@test.local');
    const result = await post(
      'send-announcement-push',
      {
        title: 'Test announcement',
        body: 'This exercises membership token fan-out.',
        channelId: 'swe-401',
      },
      lecturer,
    );
    assert.equal(result.status, 200);
    assert.equal(result.body.status, 'emulated');
    assert.equal(result.body.registeredDeviceCount, 3);
    assert.equal(result.body.successCount, 3);
  });
});

describe('backend authorization regressions', () => {
  it('denies cross-channel push and scheduling for a lecturer', async () => {
    const token = await signIn('lecturer@test.local');
    for (const name of ['send-announcement-push', 'schedule-google-workspace-meeting', 'configure-google-meet-space']) {
      const result = await post(name, {...meeting, channelId: 'not-a-member', body: 'spam'}, token);
      assert.equal(result.status, 403);
    }
  });
  it('creates and joins an invitation atomically and ignores forged identity', async () => {
    const student = await signIn('student1@test.local');
    const other = await signIn('student2@test.local');
    const code = 'SECURE-INVITE-123';
    const created = await post('collaboration', {action: 'createChannel', title: 'Protected project', kind: 'project', summary: 'Test space', code, ownerId: 'lecturer-1', ownerRole: 'lecturer'}, student);
    assert.equal(created.status, 200, JSON.stringify(created.body));
    const bad = await post('collaboration', {action: 'joinChannel', code: 'WRONG-INVITE'}, other);
    assert.equal(bad.status, 404);
    const joined = await post('collaboration', {action: 'joinChannel', code, userId: 'lecturer-1'}, other);
    assert.equal(joined.status, 200, JSON.stringify(joined.body));
    assert.equal(joined.body.title, 'Protected project');
    const again = await post('collaboration', {action: 'joinChannel', code}, other);
    assert.equal(again.status, 200);
    const {getFirestore} = await import('firebase-admin/firestore');
    const {getApps, initializeApp} = await import('firebase-admin/app');
    if (!getApps().length) initializeApp({projectId: 'school-companion-project'});
    const db = getFirestore();
    const channel = db.doc(`channels/${created.body.channelId}`);
    assert.equal((await channel.get()).data().createdBy, 'student-1');
    assert.equal((await channel.get()).data().members, 2);
    assert.equal((await channel.collection('memberships').doc('lecturer-1').get()).exists, false);
  });
  it('records one vote per user and rejects repeat or nonexistent choices', async () => {
    const {getFirestore} = await import('firebase-admin/firestore');
    const {getApps, initializeApp} = await import('firebase-admin/app');
    if (!getApps().length) initializeApp({projectId: 'school-companion-project'});
    const poll = getFirestore().doc('communityPolls/security-poll');
    await poll.set({options: {Yes: 0, No: 0}, open: true});
    const token = await signIn('student1@test.local');
    assert.equal((await post('collaboration', {action: 'votePoll', pollId: poll.id, option: 'Missing'}, token)).status, 400);
    assert.equal((await post('collaboration', {action: 'votePoll', pollId: poll.id, option: 'Yes'}, token)).status, 200);
    assert.equal((await post('collaboration', {action: 'votePoll', pollId: poll.id, option: 'No'}, token)).status, 409);
    assert.deepEqual((await poll.get()).data().options, {Yes: 1, No: 0});
  });
  it('denies session creation without CSRF headers and unverified accounts', async () => {
    const token = await signIn('student1@test.local');
    assert.equal((await post('auth-session', {action: 'create'}, token)).status, 403);
    const {getAuth} = await import('firebase-admin/auth');
    await getAuth().updateUser('student-2', {emailVerified: false});
    const unverified = await signIn('student2@test.local');
    assert.equal((await post('collaboration', {action: 'joinChannel', code: 'SECURE-INVITE-123'}, unverified)).status, 403);
    await getAuth().updateUser('student-2', {emailVerified: true});
  });
  it('limits invitation guessing and rejects oversized payloads', async () => {
    const token = await signIn('student2@test.local');
    let result;
    for (let i = 0; i < 11; i++) result = await post('collaboration', {action: 'joinChannel', code: 'WRONG-INVITE'}, token);
    assert.equal(result.status, 429);
    assert.equal((await post('collaboration', {action: 'joinChannel', code: 'x'.repeat(33000)}, token)).status, 413);
  });
});

describe('upload reservation limits', () => {
  it('checks membership, size, and cumulative daily bytes', async () => {
    const token = await signIn('student1@test.local');
    const body = {action: 'reserveUpload', channelId: 'swe-401', size: 1024, contentType: 'application/pdf'};
    assert.equal((await post('collaboration', {...body, channelId: 'not-a-member'}, token)).status, 403);
    assert.equal((await post('collaboration', {...body, size: 50 * 1024 * 1024}, token)).status, 400);
    assert.equal((await post('collaboration', {...body, contentType: 'text/html'}, token)).status, 400);
    const accepted = await post('collaboration', body, token);
    assert.equal(accepted.status, 200);
    assert.match(accepted.body.path, /^resources\/swe-401\/student-1\/[A-Za-z0-9]+\.pdf$/);
    const {getFirestore} = await import('firebase-admin/firestore');
    await getFirestore().doc('_uploadQuotas/student-1').set({day: new Date().toISOString().slice(0, 10), bytes: 100 * 1024 * 1024, count: 19});
    assert.equal((await post('collaboration', body, token)).status, 429);
  });
});

describe('resource deletion', () => {
  it('checks ownership and revokes the reservation before deleting bytes', async () => {
    const {getFirestore} = await import('firebase-admin/firestore');
    const {getStorage} = await import('firebase-admin/storage');
    const path = 'resources/swe-401/student-1/delete-security-test.pdf';
    const file = getStorage().bucket('school-companion-project.firebasestorage.app').file(path);
    await file.save(Buffer.from('%PDF'), {contentType: 'application/pdf'});
    await getFirestore().doc('_uploadReservations/delete-security-test.pdf').set({userId: 'student-1', channelId: 'swe-401'});
    const outsider = await signIn('student2@test.local');
    assert.equal((await post('collaboration', {action: 'deleteUpload', path}, outsider)).status, 403);
    const owner = await signIn('student1@test.local');
    const result = await post('collaboration', {action: 'deleteUpload', path}, owner);
    assert.equal(result.status, 200, JSON.stringify(result.body));
    assert.equal((await file.exists())[0], false);
    assert.equal((await getFirestore().doc('_uploadReservations/delete-security-test.pdf').get()).data().revoked, true);
  });
});
