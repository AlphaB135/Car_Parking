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

  // TODO: Replace the placeholder values below with your project's values.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    authDomain: 'REPLACE_WITH_YOUR_PROJECT.firebaseapp.com',
    databaseURL: 'https://REPLACE_WITH_YOUR_PROJECT.firebaseio.com',
    projectId: 'REPLACE_WITH_YOUR_PROJECT',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT.appspot.com',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    appId: 'REPLACE_WITH_APP_ID',
    measurementId: 'REPLACE_WITH_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT.appspot.com',
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
