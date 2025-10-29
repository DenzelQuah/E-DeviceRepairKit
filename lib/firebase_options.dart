import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBXQrjpir23ZNce462Slm8wuWJoY1h0OBE',
    appId: '1:528214248415:web:4fdbb0dc6858b33d62526a',
    messagingSenderId: '528214248415',
    projectId: 'e-devicerepairkit',
    authDomain: 'e-devicerepairkit.firebaseapp.com',
    storageBucket: 'e-devicerepairkit.firebasestorage.app',
    measurementId: 'G-8YWYJG9XVD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCba8eNnHEflbVNy8nA9uCzlFsdF0w8Dcw',
    appId: '1:528214248415:android:88d33996849676cb62526a',
    messagingSenderId: '528214248415',
    projectId: 'e-devicerepairkit',
    storageBucket: 'e-devicerepairkit.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwLc3rPWTLh3oJxDY61MoS59L7YasRBzs',
    appId: '1:528214248415:ios:2793eb0c7536badd62526a',
    messagingSenderId: '528214248415',
    projectId: 'e-devicerepairkit',
    storageBucket: 'e-devicerepairkit.firebasestorage.app',
    iosBundleId: 'com.example.eRepairkit',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDwLc3rPWTLh3oJxDY61MoS59L7YasRBzs',
    appId: '1:528214248415:ios:2793eb0c7536badd62526a',
    messagingSenderId: '528214248415',
    projectId: 'e-devicerepairkit',
    storageBucket: 'e-devicerepairkit.firebasestorage.app',
    iosBundleId: 'com.example.eRepairkit',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBXQrjpir23ZNce462Slm8wuWJoY1h0OBE',
    appId: '1:528214248415:web:00ec6fa38a15b2bd62526a',
    messagingSenderId: '528214248415',
    projectId: 'e-devicerepairkit',
    authDomain: 'e-devicerepairkit.firebaseapp.com',
    storageBucket: 'e-devicerepairkit.firebasestorage.app',
    measurementId: 'G-S0J28Z6ERL',
  );
}
