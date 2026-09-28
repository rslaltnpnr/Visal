// ignore_for_file: type=lint
//
// BU DOSYA `flutterfire configure` TARAFINDAN YENİDEN ÜRETİLİR.
//
// Kurulum:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<firebase-proje-id> \
//       --platforms=android,ios --out=lib/firebase_options.dart
//
// Aşağıdaki değerler `--dart-define` ile de verilebilir (CI için):
//   --dart-define=FIREBASE_API_KEY_ANDROID=... vb.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('VISAL web platformunu desteklemez.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'VISAL yalnızca Android ve iOS için yapılandırılmıştır.',
        );
    }
  }

  static const String _projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'visal-app');
  static const String _senderId =
      String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '000000000000');

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_ANDROID',
        defaultValue: 'REPLACE_WITH_ANDROID_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID_ANDROID',
        defaultValue: '1:000000000000:android:0000000000000000000000'),
    messagingSenderId: _senderId,
    projectId: _projectId,
    databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL',
        defaultValue: 'https://visal-app-default-rtdb.europe-west1.firebasedatabase.app'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'visal-app.firebasestorage.app'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY_IOS',
        defaultValue: 'REPLACE_WITH_IOS_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID_IOS',
        defaultValue: '1:000000000000:ios:0000000000000000000000'),
    messagingSenderId: _senderId,
    projectId: _projectId,
    databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL',
        defaultValue: 'https://visal-app-default-rtdb.europe-west1.firebasedatabase.app'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
        defaultValue: 'visal-app.firebasestorage.app'),
    iosClientId: String.fromEnvironment('FIREBASE_IOS_CLIENT_ID',
        defaultValue: '000000000000-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com'),
    iosBundleId: 'app.visal.visal',
  );
}
