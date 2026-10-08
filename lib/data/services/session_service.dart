import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_session.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  UserSession? _currentUser;
  bool _isOnboardingDone = false;
  bool _isBusinessSetupDone = false;

  UserSession? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isOnboardingDone => _isOnboardingDone;
  bool get isBusinessSetupDone => _isBusinessSetupDone;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboardingDone = prefs.getBool(AppConstants.keyOnboardingCompleted) ?? false;
    _isBusinessSetupDone = prefs.getBool(AppConstants.keyBusinessSetupCompleted) ?? false;

    final userJson = prefs.getString(AppConstants.keyUserSession);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        _currentUser = UserSession.fromMap(jsonDecode(userJson));
      } catch (e) {
        _currentUser = null;
      }
    }
  }

  Future<void> saveSession(UserSession session) async {
    _currentUser = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserSession, jsonEncode(session.toMap()));
    await prefs.setBool(AppConstants.keyIsLoggedIn, true);
  }

  Future<void> markOnboardingCompleted() async {
    _isOnboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingCompleted, true);
  }

  Future<void> markBusinessSetupCompleted() async {
    _isBusinessSetupDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyBusinessSetupCompleted, true);
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserSession);
    await prefs.setBool(AppConstants.keyIsLoggedIn, false);
    // Note: Do NOT clear business data or onboarding flag so the store config is preserved!
  }
}
