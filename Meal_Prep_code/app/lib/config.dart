import 'package:flutter/foundation.dart';

/// Turn on Firebase phone-OTP login with:
///   flutter run --dart-define=USE_FIREBASE=true
/// (after running `flutterfire configure`, which generates lib/firebase_options.dart).
/// Without it the app uses dev login: any phone number, no OTP, backend AUTH_MODE=dev.
const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

/// Override with --dart-define=API_URL=http://192.168.1.10:8000 for a real phone on your Wi-Fi.
const String _apiOverride = String.fromEnvironment('API_URL');

String get apiBaseUrl {
  if (_apiOverride.isNotEmpty) return _apiOverride;
  // The Android emulator reaches the Mac's localhost via 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
