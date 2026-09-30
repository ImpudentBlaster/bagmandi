import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class AppBackend {
  static bool get firebaseReady {
    try {
      if (Firebase.apps.isEmpty) return false;
      final id = DefaultFirebaseOptions.currentPlatform.projectId;
      return id.isNotEmpty && !id.startsWith('YOUR_');
    } catch (_) {
      return false;
    }
  }

  static String get modeLabel => firebaseReady ? 'Firebase' : 'Local DB';
}
