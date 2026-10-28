// Firebase-Konfiguration für das Projekt bubududu-15f3f.
// Diese Werte sind nicht geheim; den Zugriff schützen die Regeln in firestore.rules.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Für diese Plattform ist Firebase noch nicht eingerichtet.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBbGJsN8Ggne3MlZSytSj11n8Rb5FFKzfE',
    appId: '1:787816121254:web:ed03b3b8fbbd489bad0567',
    messagingSenderId: '787816121254',
    projectId: 'bubududu-15f3f',
    authDomain: 'bubududu-15f3f.firebaseapp.com',
    storageBucket: 'bubududu-15f3f.firebasestorage.app',
  );
}
