import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'data/database/database_helper.dart';
import 'data/services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for mobile and responsive layouts
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize Firebase for real Phone Authentication
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize offline persistent storage & authentication session
  final db = DatabaseHelper();
  final session = SessionService();
  await db.init();
  await session.init();

  // Scope active database user identity to the authenticated Firebase session
  if (session.currentUser != null && session.currentUser!.id.isNotEmpty) {
    await db.setActiveUserId(session.currentUser!.id);
  }

  runApp(const ScanzoApp());
}
