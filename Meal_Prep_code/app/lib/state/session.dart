import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models.dart';

/// Holds who is logged in, app-wide flags, and exposes the API client.
class Session extends ChangeNotifier {
  Session() {
    api = ApiClient(_token);
  }

  late final ApiClient api;
  AppUser? user;
  bool loading = true;
  bool introSeen = true;
  String? _devPhone;

  /// Bumped whenever bookings/plans change elsewhere (e.g. an AI agent drafted and the user
  /// confirmed a booking) so lists keyed on it reload.
  int revision = 0;

  /// Preferred AI provider chosen in the chat screen (null = server default).
  String? aiProvider;

  bool get loggedIn => user != null;

  Future<String?> _token() async {
    if (useFirebase) return await fb.FirebaseAuth.instance.currentUser?.getIdToken();
    return _devPhone == null ? null : 'dev:$_devPhone';
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      introSeen = prefs.getBool('intro_seen') ?? false;
      aiProvider = prefs.getString('ai_provider');
      if (useFirebase) {
        if (fb.FirebaseAuth.instance.currentUser != null) user = await api.me();
      } else {
        _devPhone = prefs.getString('dev_phone');
        if (_devPhone != null) user = await api.me();
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
      user = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> markIntroSeen() async {
    introSeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_seen', true);
  }

  Future<void> setAiProvider(String? key) async {
    aiProvider = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove('ai_provider');
    } else {
      await prefs.setString('ai_provider', key);
    }
  }

  void bump() {
    revision++;
    notifyListeners();
  }

  /// Dev login: no OTP, backend must run with AUTH_MODE=dev.
  Future<void> devLogin(String phone) async {
    _devPhone = phone;
    try {
      user = await api.me();
    } catch (_) {
      _devPhone = null;
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dev_phone', phone);
    notifyListeners();
  }

  /// Called after Firebase phone sign-in succeeds.
  Future<void> firebaseSignedIn() async {
    user = await api.me();
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? role}) async {
    user = await api.updateMe(name: name, role: role);
    notifyListeners();
  }

  Future<void> logout() async {
    if (useFirebase) {
      await fb.FirebaseAuth.instance.signOut();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dev_phone');
      _devPhone = null;
    }
    user = null;
    notifyListeners();
  }
}
