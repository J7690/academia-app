// Firebase Cloud Messaging service worker for Academia (Flutter Web)
// See this file for the latest firebase-js-sdk version:
// https://github.com/firebase/flutterfire/blob/main/packages/firebase_core/firebase_core_web/lib/src/firebase_sdk_version.dart

importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyB_9r-GJ9KdbgTTjZHhav9DZpoCSuh63qA",
  authDomain: "academia-e2c41.firebaseapp.com",
  projectId: "academia-e2c41",
  messagingSenderId: "593442809911",
  appId: "1:593442809911:web:e921b64da1f6548c3af7b2",
  storageBucket: "academia-e2c41.firebasestorage.app",
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Optional: log background messages for debugging.
// FCM continuera à afficher les notifications système si le payload contient
// un champ `notification` (ce que fait déjà l'Edge Function).
//
// Vous verrez ces logs dans la console du navigateur quand un push arrive
// alors que l'onglet est en arrière-plan ou fermé.
messaging.onBackgroundMessage((message) => {
  console.log("[firebase-messaging-sw.js] Background message received:", message);
});
