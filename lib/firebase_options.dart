import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for fuchsia.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDMUY4Y21gKeKNOV4Phcl78jjc-3aFw7RY',
    appId: '1:301270996685:web:a60148c46a647a50c0fb84',
    messagingSenderId: '301270996685',
    projectId: 'tccamboni',
    databaseURL: 'https://tccamboni-default-rtdb.firebaseio.com',
    storageBucket: 'tccamboni.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDMUY4Y21gKeKNOV4Phcl78jjc-3aFw7RY',
    appId: '1:301270996685:android:a60148c46a647a50c0fb84',
    messagingSenderId: '301270996685',
    projectId: 'tccamboni',
    databaseURL: 'https://tccamboni-default-rtdb.firebaseio.com',
    storageBucket: 'tccamboni.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDMUY4Y21gKeKNOV4Phcl78jjc-3aFw7RY',
    appId: '1:301270996685:ios:a60148c46a647a50c0fb84',
    messagingSenderId: '301270996685',
    projectId: 'tccamboni',
    databaseURL: 'https://tccamboni-default-rtdb.firebaseio.com',
    storageBucket: 'tccamboni.firebasestorage.app',
    iosBundleId: 'com.amboni.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDMUY4Y21gKeKNOV4Phcl78jjc-3aFw7RY',
    appId: '1:301270996685:ios:a60148c46a647a50c0fb84',
    messagingSenderId: '301270996685',
    projectId: 'tccamboni',
    databaseURL: 'https://tccamboni-default-rtdb.firebaseio.com',
    storageBucket: 'tccamboni.firebasestorage.app',
    iosBundleId: 'com.amboni.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDMUY4Y21gKeKNOV4Phcl78jjc-3aFw7RY',
    appId: '1:301270996685:web:a60148c46a647a50c0fb84',
    messagingSenderId: '301270996685',
    projectId: 'tccamboni',
    databaseURL: 'https://tccamboni-default-rtdb.firebaseio.com',
    storageBucket: 'tccamboni.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDMUY4Y21gKeKNOV4Phcl78jjc-3aFw7RY',
    appId: '1:301270996685:web:a60148c46a647a50c0fb84',
    messagingSenderId: '301270996685',
    projectId: 'tccamboni',
    databaseURL: 'https://tccamboni-default-rtdb.firebaseio.com',
    storageBucket: 'tccamboni.firebasestorage.app',
  );
}
