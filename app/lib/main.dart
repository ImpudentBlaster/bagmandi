import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/app_backend.dart';
import 'core/config/phone_auth_config.dart';
import 'firebase_options.dart';
import 'services/bagmandi_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (AppBackend.firebaseReady) {
      await PhoneAuthConfig.configure();
      await NotificationService.instance.init();
    }
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  await BagMandiRepository.instance.init();
  debugPrint('BagMandi backend: ${AppBackend.modeLabel}');

  runApp(const BagMandiApp());
}
