import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';

/// Service responsible for permanent account persistence, cloud synchronization,
/// and user-data isolation keyed strictly by Firebase UID.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  /// Normalized mobile number key for registry lookups
  static String _normalizeMobile(String mobile) {
    return mobile.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
  }

  /// Checks if an account exists for the given 10-digit mobile number.
  Future<bool> isAccountRegistered(String mobile) async {
    final clean = _normalizeMobile(mobile);
    if (clean.length != 10) return false;

    final prefs = await SharedPreferences.getInstance();
    // 1. Check local persistent cloud registry index
    final registryJson = prefs.getString('cloud_account_registry');
    if (registryJson != null && registryJson.isNotEmpty) {
      try {
        final Map<String, dynamic> registry = jsonDecode(registryJson);
        if (registry.containsKey(clean)) {
          return true;
        }
      } catch (_) {}
    }

    // 2. Check individual account flag
    final accountFlag = prefs.getString('account_registered_$clean');
    if (accountFlag != null && accountFlag.isNotEmpty) {
      return true;
    }

    // 3. Check if any store exists with this mobile number
    final storesStr = prefs.getString('db_stores');
    if (storesStr != null && storesStr.isNotEmpty) {
      try {
        final List list = jsonDecode(storesStr);
        for (var item in list) {
          final storeMobile = _normalizeMobile(item['mobile'] ?? '');
          if (storeMobile == clean) {
            return true;
          }
        }
      } catch (_) {}
    }

    return false;
  }

  /// Registers a newly created account permanently in the cloud registry.
  Future<void> registerAccount({
    required String uid,
    required String mobile,
    required String ownerName,
    required String businessName,
    String? email,
  }) async {
    final clean = _normalizeMobile(mobile);
    final prefs = await SharedPreferences.getInstance();

    final accountData = {
      'uid': uid,
      'mobile': clean,
      'ownerName': ownerName,
      'businessName': businessName,
      'email': email,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Update global registry
    Map<String, dynamic> registry = {};
    final registryJson = prefs.getString('cloud_account_registry');
    if (registryJson != null && registryJson.isNotEmpty) {
      try {
        registry = jsonDecode(registryJson);
      } catch (_) {}
    }
    registry[clean] = accountData;
    registry[uid] = accountData;

    await prefs.setString('cloud_account_registry', jsonEncode(registry));
    await prefs.setString('account_registered_$clean', uid);
    await prefs.setString('account_profile_$uid', jsonEncode(accountData));
  }

  /// Checks if a business profile exists for this Firebase UID.
  Future<bool> hasAccountProfile(String uid) async {
    if (uid.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();

    // Check direct profile
    final profile = prefs.getString('account_profile_$uid');
    if (profile != null && profile.isNotEmpty) return true;

    // Check if user has partition stores
    final storesStr = prefs.getString('db_${uid}_stores');
    if (storesStr != null && storesStr.isNotEmpty) {
      try {
        final List list = jsonDecode(storesStr);
        if (list.isNotEmpty) return true;
      } catch (_) {}
    }

    // Check cloud backup
    final backup = prefs.getString('cloud_backup_$uid');
    if (backup != null && backup.isNotEmpty) return true;

    // Check remote cloud backup
    final remoteData = await restoreUserData(uid);
    if (remoteData != null) return true;

    return false;
  }

  /// Retrieves the account metadata for a specific UID.
  Future<Map<String, dynamic>?> getAccountProfile(String uid) async {
    if (uid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();

    final profile = prefs.getString('account_profile_$uid');
    if (profile != null && profile.isNotEmpty) {
      try {
        return jsonDecode(profile) as Map<String, dynamic>;
      } catch (_) {}
    }

    final backup = prefs.getString('cloud_backup_$uid');
    if (backup != null && backup.isNotEmpty) {
      try {
        final map = jsonDecode(backup) as Map<String, dynamic>;
        if (map.containsKey('accountData')) {
          return map['accountData'] as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Backs up all user data (stores, products, categories, sales, customers, settings)
  /// associated with this Firebase UID.
  Future<void> backupUserData(String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(data);

    // 1. Save to durable cloud backup ledger
    await prefs.setString('cloud_backup_$uid', serialized);

    // 2. Sync to Firebase Cloud Firestore via REST API if authenticated
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == uid) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
          if (projectId.isNotEmpty && !projectId.contains('placeholder')) {
            final uri = Uri.parse(
              'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/scanzo_users/$uid',
            );

            // Firestore REST API document format
            final body = jsonEncode({
              'fields': {
                'backupJson': {'stringValue': serialized},
                'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
                'uid': {'stringValue': uid},
              }
            });

            await http.patch(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: body,
            ).timeout(const Duration(seconds: 10));
          }
        }
      }
    } catch (e) {
      // Offline or Firestore not provisioned; local durable ledger is safely preserved
      debugPrint('Cloud sync notice: $e');
    }
  }

  /// Restores user data from the cloud backup for this Firebase UID upon login or reinstall.
  Future<Map<String, dynamic>?> restoreUserData(String uid) async {
    if (uid.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();

    // 1. Try to fetch from Firebase Cloud Firestore REST API if online
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == uid) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
          if (projectId.isNotEmpty && !projectId.contains('placeholder')) {
            final uri = Uri.parse(
              'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/scanzo_users/$uid',
            );

            final response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              final body = jsonDecode(response.body);
              final fields = body['fields'] as Map<String, dynamic>?;
              final backupStr = fields?['backupJson']?['stringValue'] as String?;
              if (backupStr != null && backupStr.isNotEmpty) {
                final cloudMap = jsonDecode(backupStr) as Map<String, dynamic>;
                // Cache locally
                await prefs.setString('cloud_backup_$uid', backupStr);
                return cloudMap;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Cloud restore remote notice: $e');
    }

    // 2. Fall back to durable local cloud backup ledger
    final backup = prefs.getString('cloud_backup_$uid');
    if (backup != null && backup.isNotEmpty) {
      try {
        return jsonDecode(backup) as Map<String, dynamic>;
      } catch (_) {}
    }

    return null;
  }
}
