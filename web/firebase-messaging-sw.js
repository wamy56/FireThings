// Firebase Messaging Service Worker for web push notifications.
// Handles background messages and notification clicks.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCLqKJvJGHHNFcvgOma0fjR1gpMsF9ASQU',
  authDomain: 'firethings-51e00.firebaseapp.com',
  projectId: 'firethings-51e00',
  storageBucket: 'firethings-51e00.firebasestorage.app',
  messagingSenderId: '218966840739',
  appId: '1:218966840739:web:19e4d14f2b47d20c7b3616',
});

const messaging = firebase.messaging();

// Handle background messages (tab not focused or closed)
messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'FireThings';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new update',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    tag: payload.data?.jobId || 'default',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click — open or focus the app tab
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const jobId = event.notification.data?.jobId;
  const url = jobId ? `/jobs/${jobId}` : '/jobs';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus();
          client.postMessage({ type: 'navigate', url: url });
          return;
        }
      }
      return clients.openWindow(url);
    })
  );
});
