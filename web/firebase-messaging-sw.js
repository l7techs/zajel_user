importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

// CUSTOM: rebrand — Firebase project talabati-45c06
firebase.initializeApp({
  apiKey: "AIzaSyB7bvjB_eGVCbiBW5cXl6_UbstTDRkhyVE",
  authDomain: "talabati-45c06.firebaseapp.com",
  projectId: "talabati-45c06",
  storageBucket: "talabati-45c06.firebasestorage.app",
  messagingSenderId: "373551071064",
  appId: "1:373551071064:web:a746c1ef12ca933310af2d",
  measurementId: "G-MCFVCKXE1W"
});

const messaging = firebase.messaging();

messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            const title = payload.notification.title;
            const options = {
                body: payload.notification.score
              };
            return registration.showNotification(title, options);
        });
    return promiseChain;
});
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});