import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/auth_navigation.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final auth = context.read<AuthProvider>();

    // Wait until session restore finishes (and keep splash visible briefly).
    while (!auth.ready) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    final elapsed = DateTime.now().difference(started);
    final remaining = const Duration(milliseconds: 1600) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;

    final user = auth.user;
    if (user == null || auth.isGuest) {
      context.go('/login');
      return;
    }
    if (user.role == UserRole.admin) {
      await auth.signOut();
      if (!mounted) return;
      context.go('/login');
      return;
    }
    context.go(AuthNavigation.routeFor(user));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const AppLogo(size: 280),
            const Spacer(flex: 2),
            Text(
              'Connecting Buyers with Manufacturers',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 48, 36),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: const Color(0xFFFF8C00),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
