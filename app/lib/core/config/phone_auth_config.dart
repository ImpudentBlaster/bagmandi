import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Phone Auth setup for BagMandi (debug + release).
///
/// Requires Firebase Console:
/// - Phone provider enabled
/// - India (IN) allowed in SMS region policy
/// - SHA-1 + SHA-256 registered for package `com.bagmandi.app`
/// - Google Cloud → Credentials → Android OAuth client (package + SHA-1)
///   so `google-services.json` has non-empty `oauth_client`
class PhoneAuthConfig {
  /// Firebase Console → Authentication → Phone → Phone numbers for testing
  /// These only work after the SAME numbers are added in Console.
  static const Map<String, String> debugTestNumbers = {
    '+919999999991': '123456',
    '+919999999992': '654321',
  };

  static bool get isDebug => kDebugMode;

  /// Call once after Firebase.initializeApp().
  static Future<void> configure() async {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: false,
      // Prefer Play Integrity first; reCAPTCHA is used as fallback on failure.
      forceRecaptchaFlow: false,
    );
  }

  static String? testOtpFor(String e164) => debugTestNumbers[e164];

  static bool isTestNumber(String e164) => debugTestNumbers.containsKey(e164);

  /// User-facing message for common phone-auth failures.
  static String friendlyError(FirebaseAuthException e) {
    final code = e.code;
    final msg = (e.message ?? '').toLowerCase();

    if (code == 'too-many-requests' ||
        msg.contains('blocked all requests') ||
        msg.contains('unusual activity') ||
        msg.contains('17010')) {
      return 'Is device pe OTP temporarily block ho gaya hai. 30–60 min baad try karo, ya abhi test number 9999999991 / OTP 123456 use karo.';
    }
    if (code == 'operation-not-allowed' || msg.contains('region')) {
      return 'SMS for India is not enabled yet. Please try again shortly.';
    }
    if (code == 'invalid-phone-number') {
      return 'Enter a valid 10-digit mobile number.';
    }
    if (code == 'quota-exceeded') {
      return 'SMS limit reached. Please try again later.';
    }
    if (code == 'session-expired') {
      return 'OTP expired. Please request a new OTP.';
    }
    if ((msg.contains('blocked') && msg.contains('android')) ||
        msg.contains('api_key_android_app_blocked') ||
        msg.contains('application <empty>')) {
      return 'Login config sync ho rahi hai. App band karke dubara open karo, phir OTP try karo.';
    }
    if (msg.contains('app identifier') ||
        msg.contains('play integrity') ||
        msg.contains('play_integrity') ||
        msg.contains('sha-256') ||
        msg.contains('sha256') ||
        msg.contains('not authorized') ||
        msg.contains('recaptcha') ||
        msg.contains('17093') ||
        msg.contains('missing_client_identifier')) {
      return 'Device verify fail. Test number try karo: 9999999991 / OTP 123456, ya 1 min baad dubara OTP bhejo.';
    }
    if ((e.message ?? '').trim().isNotEmpty) {
      return e.message!.trim();
    }
    return 'OTP send failed. Please try again.';
  }
}
