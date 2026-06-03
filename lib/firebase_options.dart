import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyApUwLMqrRzltnYFcVInJjr2Jeyws0ZOKo',
    appId: '1:348057118012:web:cac50e0ab8dd30c6276a39',
    messagingSenderId: '348057118012',
    projectId: 'my-billu',
    authDomain: 'my-billu.firebaseapp.com',
    databaseURL: 'https://my-billu-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'my-billu.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-YWmr8E_D-s1khuNGzs9IXl4Ie6jey-c',
    appId: '1:348057118012:android:90f1dc0285c573fa276a39',
    messagingSenderId: '348057118012',
    projectId: 'my-billu',
    databaseURL: 'https://my-billu-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'my-billu.firebasestorage.app',
  );
}
