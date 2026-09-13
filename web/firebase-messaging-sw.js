/*
 * Movi-K — Firebase Cloud Messaging service worker (Phase 8D).
 *
 * Les identifiants Firebase ci-dessous sont PUBLICS (même configuration que
 * lib/backend/firebase_options.dart). Aucun secret Admin SDK n'est présent.
 *
 * Ce worker permet à Firebase Messaging Web d'obtenir un token Web Push et
 * d'afficher les notifications reçues lorsque l'onglet Movi-K n'est pas au
 * premier plan. Le clic est ensuite traité par Firebase Messaging côté
 * Flutter via onMessageOpenedApp/getInitialMessage.
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCLIvf9Ql4MZvsKGinjnT1caNfj8Ba6oaE',
  appId: '1:624917306908:web:6e357be752bd9ad1e489d9',
  messagingSenderId: '624917306908',
  projectId: 'movik-connect-prod',
  authDomain: 'movik-connect-prod.firebaseapp.com',
  storageBucket: 'movik-connect-prod.firebasestorage.app',
});

firebase.messaging();
