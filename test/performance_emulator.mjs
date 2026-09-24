import { performance } from 'node:perf_hooks';
import { initializeApp as initializeAdminApp } from 'firebase-admin/app';
import { getFirestore as getAdminFirestore, Timestamp } from 'firebase-admin/firestore';
import { initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {
  addDoc,
  collection,
  connectFirestoreEmulator,
  getDocs,
  getFirestore,
  limit,
  orderBy,
  query,
  serverTimestamp,
} from 'firebase/firestore';
import {
  connectStorageEmulator,
  getBytes,
  getStorage,
  ref,
  uploadBytes,
} from 'firebase/storage';

const projectId = process.env.GCLOUD_PROJECT ?? 'school-companion-project';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Performance measurements require the local emulators.');
}
const adminApp = initializeAdminApp({projectId}, `performance-admin-${Date.now()}`);
const admin = getAdminFirestore(adminApp);
const channelId = 'performance-evidence';
const channelRef = admin.collection('channels').doc(channelId);

await channelRef.set({
  title: 'Performance Evidence',
  kind: 'project',
  code: 'PERF-E2E',
  summary: 'Scoped emulator performance measurements.',
  members: 1,
  unread: 0,
  createdBy: 'student-1',
  createdAt: Timestamp.now(),
});
await channelRef.collection('memberships').doc('student-1').set({
  userId: 'student-1',
  channelId,
  role: 'student',
  status: 'active',
  joinedAt: Timestamp.now(),
});

const app = initializeApp({
  projectId,
  apiKey: 'demo-key',
  authDomain: `${projectId}.firebaseapp.com`,
  storageBucket: `${projectId}.firebasestorage.app`,
}, `performance-client-${Date.now()}`);
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
const firestore = getFirestore(app);
connectFirestoreEmulator(firestore, '127.0.0.1', 8080);
const storage = getStorage(app);
connectStorageEmulator(storage, '127.0.0.1', 9199);

const authStart = performance.now();
await signInWithEmailAndPassword(auth, 'student1@test.local', 'TestPass123!');
const authMs = performance.now() - authStart;
const messages = collection(firestore, 'channels', channelId, 'messages');

const percentile = (values, percentage) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * percentage) - 1)];
};
const rounded = (value) => Math.round(value * 100) / 100;

// Warm up the SDK connection so cold startup is reported separately.
await addDoc(messages, {
  senderId: 'student-1', sender: 'Hendrick Emmanuel', body: 'warm-up',
  isLecturer: false, createdAt: serverTimestamp(),
});

const sequential = [];
for (let index = 0; index < 30; index += 1) {
  const started = performance.now();
  await addDoc(messages, {
    senderId: 'student-1', sender: 'Hendrick Emmanuel',
    body: `sequential-message-${index}`, isLecturer: false,
    createdAt: serverTimestamp(),
  });
  sequential.push(performance.now() - started);
}

const concurrentStart = performance.now();
await Promise.all(Array.from({length: 50}, (_, index) => addDoc(messages, {
  senderId: 'student-1', sender: 'Hendrick Emmanuel',
  body: `concurrent-message-${index}`, isLecturer: false,
  createdAt: serverTimestamp(),
})));
const concurrentMs = performance.now() - concurrentStart;

const readStart = performance.now();
const readSnapshot = await getDocs(query(messages, orderBy('createdAt'), limit(100)));
const readMs = performance.now() - readStart;

const bytes = new TextEncoder().encode('School Companion performance evidence. '.repeat(32));
const uploadTimes = [];
const downloadTimes = [];
for (let index = 0; index < 5; index += 1) {
  const fileName = `perf-${Date.now()}-${index}.txt`;
  const reservation = admin.collection('_uploadReservations').doc(fileName);
  await reservation.set({
    userId: 'student-1', channelId, size: bytes.byteLength,
    contentType: 'text/plain', expiresAt: Timestamp.fromMillis(Date.now() + 60000),
  });
  const object = ref(storage, `resources/${channelId}/student-1/${fileName}`);
  const uploadStart = performance.now();
  await uploadBytes(object, bytes, {contentType: 'text/plain'});
  uploadTimes.push(performance.now() - uploadStart);
  const downloadStart = performance.now();
  await getBytes(object);
  downloadTimes.push(performance.now() - downloadStart);
  await reservation.delete();
}

const result = {
  environment: 'Firebase Emulator Suite on localhost',
  samples: {
    sequentialWrites: sequential.length,
    concurrentWrites: 50,
    messagesRead: readSnapshot.size,
    storageUploads: uploadTimes.length,
    storageDownloads: downloadTimes.length,
    storagePayloadBytes: bytes.byteLength,
  },
  milliseconds: {
    coldAuthentication: rounded(authMs),
    firestoreSequentialWriteP50: rounded(percentile(sequential, 0.50)),
    firestoreSequentialWriteP95: rounded(percentile(sequential, 0.95)),
    firestoreConcurrent50Total: rounded(concurrentMs),
    firestoreRead100: rounded(readMs),
    storageUploadP50: rounded(percentile(uploadTimes, 0.50)),
    storageUploadP95: rounded(percentile(uploadTimes, 0.95)),
    storageDownloadP50: rounded(percentile(downloadTimes, 0.50)),
    storageDownloadP95: rounded(percentile(downloadTimes, 0.95)),
  },
  throughput: {
    concurrentFirestoreWritesPerSecond: rounded(50000 / concurrentMs),
  },
};

console.log(JSON.stringify(result, null, 2));
await admin.recursiveDelete(channelRef);
process.exit(0);
