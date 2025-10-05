// Placeholder Firebase options file.
// Run `flutterfire configure` to generate a real `firebase_options.dart` for
// your Firebase project, or replace the values below with the config from
// your Firebase Console -> Project settings -> Your apps (Web config).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        // Desktop platforms typically use platform-default initialization.
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCpUlDqMxgqS43xx2n3S8qbubxWkp__YaU',
    authDomain: 'myapp-292ad.firebaseapp.com',
    databaseURL: 'https://myapp-292ad-default-rtdb.firebaseio.com',
    projectId: 'myapp-292ad',
    storageBucket: 'myapp-292ad.firebasestorage.app',
    messagingSenderId: '328892986991',
    appId: '1:328892986991:web:1f2dbdf5e2168c1ce0ff9a',
    measurementId: 'G-8GJRZLD3S7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATXhn5wX1-of1vk6AkzH0VdayqUvb5VTA',
    appId: '1:328892986991:android:ead831136e73a8fce0ff9a',
    messagingSenderId: '328892986991',
    projectId: 'myapp-292ad',
    databaseURL: 'https://myapp-292ad-default-rtdb.firebaseio.com',
    storageBucket: 'myapp-292ad.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT',
    databaseURL: 'https://REPLACE_WITH_YOUR_PROJECT.firebaseio.com',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT.appspot.com',
    iosBundleId: 'REPLACE_WITH_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = ios;
}
