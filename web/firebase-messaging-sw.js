// Firebase Messaging requires this root-scoped service worker when getToken()
// is called without an explicit serviceWorkerRegistration.
importScripts(
  'https://www.gstatic.com/firebasejs/12.18.0/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/12.18.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyAq6q4ZDsonA0RQ31eK22faTeX1NiZlWdI',
  authDomain: 'school-companion-project.firebaseapp.com',
  projectId: 'school-companion-project',
  storageBucket: 'school-companion-project.firebasestorage.app',
  messagingSenderId: '853755032440',
  appId: '1:853755032440:web:e4024d7ca1222daac14e8d',
});

firebase.messaging();
