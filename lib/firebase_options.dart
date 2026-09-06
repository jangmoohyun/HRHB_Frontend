// File generated manually from Firebase console config files.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8g5BLCgZ1XmByPJ8sALRSaR3ALEHuMgc',
    appId: '1:530775206499:android:e071470e1b1c2a75a4a656',
    messagingSenderId: '530775206499',
    projectId: 'hrhb-836ca',
    storageBucket: 'hrhb-836ca.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3D9rvLv3wOEqy54fs6CN7hqHe7ntgj5Y',
    appId: '1:530775206499:ios:16bfcdcdbe8e7e5aa4a656',
    messagingSenderId: '530775206499',
    projectId: 'hrhb-836ca',
    storageBucket: 'hrhb-836ca.firebasestorage.app',
    iosBundleId: 'com.moohyun.haru',
  );
}
