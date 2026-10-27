import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Scanzo Smart Billing App.
///
/// Pre-configured to support Firebase Phone Authentication with SMS verification,
/// reCAPTCHA verification on Flutter Web (compatible with Vercel and custom domains),
/// and Android/iOS mobile environments.
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
        return web;
    }
  }

  /// Returns true only if valid non-placeholder Firebase credentials are configured.
  static bool get isConfigured {
    final options = currentPlatform;
    final key = options.apiKey;
    final appId = options.appId;
    final projectId = options.projectId;

    final isKeyValid = key.isNotEmpty && !key.toLowerCase().contains('placeholder');
    final isAppIdValid = appId.isNotEmpty && !appId.toLowerCase().contains('placeholder');
    final isProjectValid = projectId.isNotEmpty && !projectId.toLowerCase().contains('placeholder');

    return isKeyValid && isAppIdValid && isProjectValid;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'AIzaSyA5VykTxHEj0FsFzS-OtKIuCgo4XN06Gnk',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: '1:532856431533:web:a99e3aecc3350fc33a3724',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '532856431533',
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'scanzo-billing',
    ),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'scanzo-billing.firebaseapp.com',
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'scanzo-billing.firebasestorage.app',
    ),
    measurementId: String.fromEnvironment(
      'FIREBASE_MEASUREMENT_ID',
      defaultValue: 'G-YCTLHWHEDQ',
    ),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'AIzaSyScanzoBillingAppApiKeyPlaceholder',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '1:102938475612:android:scanzo1234567890abcdef',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '102938475612',
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'scanzo-billing',
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'scanzo-billing.appspot.com',
    ),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: 'AIzaSyScanzoBillingAppApiKeyPlaceholder',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: '1:102938475612:ios:scanzo1234567890abcdef',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '102938475612',
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'scanzo-billing',
    ),
    storageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'scanzo-billing.appspot.com',
    ),
    iosBundleId: 'com.scanzo.smartbilling',
  );
}
