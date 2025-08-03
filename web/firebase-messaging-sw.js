// Import the Firebase scripts for service worker
importScripts('https://www.gstatic.com/firebasejs/10.4.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.4.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyBn3lnnyy2EhM1ej7-j6fA5lSJxoWRVKl8",
  authDomain: "mealmommy-de80f.firebaseapp.com",
  projectId: "mealmommy-de80f",
  storageBucket: "mealmommy-de80f.firebasestorage.app",
  messagingSenderId: "655906802569",
  appId: "1:655906802569:web:ce473c1b851e3d306f1e07",
  measurementId: "G-Z3TSWBM0VR"
});

// Get the messaging instance
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'MealMommy';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
