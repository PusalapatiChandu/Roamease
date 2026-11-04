// File generated for RoamEase Firebase Configuration
// Replace placeholder values with your Firebase project credentials or run `flutterfire configure`

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDFYt6jeH-i_vOX0Q8dcilY_LLj8ayX8LE',
    appId: '1:417854473602:web:375845fd13535650857b9b',
    messagingSenderId: '417854473602',
    projectId: 'roamease-1e820',
    authDomain: 'roamease-1e820.firebaseapp.com',
    databaseURL: 'https://roamease-1e820-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'roamease-1e820.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1mVDBPXJUtA11IlCiPo36wKYkwFXJpEU',
    appId: '1:417854473602:android:78a4b61037f35ae1857b9b',
    messagingSenderId: '417854473602',
    projectId: 'roamease-1e820',
    databaseURL: 'https://roamease-1e820-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'roamease-1e820.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAUS7LP2NBZk_ZuchqbaFTWvhZ4-QIKjqQ',
    appId: '1:417854473602:ios:0eb27702cb9afbd3857b9b',
    messagingSenderId: '417854473602',
    projectId: 'roamease-1e820',
    databaseURL: 'https://roamease-1e820-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'roamease-1e820.firebasestorage.app',
    iosClientId: '417854473602-r7lmhk9tad2qeogek7c6v040i3d7dm2l.apps.googleusercontent.com',
    iosBundleId: 'com.example.roamease',
  );
}
