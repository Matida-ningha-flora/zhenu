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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // NOTE: Remplacer les valeurs ci-dessous par vos propres identifiants Firebase.
  // Vous pouvez obtenir ces valeurs depuis la console Firebase ou en exécutant:
  // `flutterfire configure` dans votre terminal.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCyZKgdfs6cjjjD9Ih--RekDOtsefkpi_s',
    appId: '1:741677905714:web:47a93f0856920c5836492b',
    messagingSenderId: '741677905714',
    projectId: 'zhenu-f0838',
    authDomain: 'zhenu-f0838.firebaseapp.com',
    storageBucket: 'zhenu-f0838.firebasestorage.app',
    measurementId: 'G-HF1P60QJRK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCvPdvBsnlCLDidzLbNvk_UyTmctDbd3oE',
    appId: '1:741677905714:android:78f9e20a5ab6786136492b',
    messagingSenderId: '741677905714',
    projectId: 'zhenu-f0838',
    storageBucket: 'zhenu-f0838.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAzhjNK66toyry-0qDhR3U-DL8cXlYqrqg',
    appId: '1:741677905714:ios:e904f7075a13b25f36492b',
    messagingSenderId: '741677905714',
    projectId: 'zhenu-f0838',
    storageBucket: 'zhenu-f0838.firebasestorage.app',
    iosBundleId: 'com.example.zhenduApp',
  );
}
