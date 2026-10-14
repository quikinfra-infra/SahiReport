// web/firebase-messaging-sw.js
// Handles background push notifications for the web app.
// Uses the compat SDK (required for service workers).

importScripts(
  'https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: "AIzaSyDae6cG_X9gl75J_H_v3s-XTsvM8rtpQfM",
  authDomain: "myapp-123-678ec.firebaseapp.com",
  projectId: "myapp-123-678ec",
  storageBucket: "myapp-123-678ec.firebasestorage.app",
  messagingSenderId: "101160836263",
  appId: "1:101160836263:web:9cd05a48c7de19f1cc8f82",
  measurementId: "G-CQY0MCJBXZ"
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'SahiReport';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});