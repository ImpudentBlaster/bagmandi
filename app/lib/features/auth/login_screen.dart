import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/auth_navigation.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final digits = _normalizePhone(_phoneController.text);
    final ok = await auth.sendOtp(digits);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to send OTP'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    // Silent verification already signed the user in.
    if (auth.verificationId == 'auto_verified' && auth.user != null) {
      final user = auth.user!;
      if (user.role == UserRole.admin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admin panel web pe chalta hai. App check ke liye buyer/manufacturer number se login karo.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        await auth.signOut();
        if (!mounted) return;
        return;
      }
      context.go(AuthNavigation.routeFor(user));
      return;
    }

    context.go('/otp?phone=$digits');
  }

  /// Accepts 10 digits, or +91 / 91 prefixed input, and returns 10 digits.
  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F7),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const AppLogo(size: 120),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome to BagMandi',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "India's Bag Industry Marketplace",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Login or Register to continue',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 36),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlignVertical: TextAlignVertical.center,
                            validator: (v) {
                              final n = _normalizePhone(v ?? '');
                              if (n.length != 10) {
                                return 'Enter valid 10 digit mobile number';
                              }
                              return null;
                            },
                            style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '10-digit mobile number',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 14, right: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.smartphone_outlined,
                                      color: AppColors.textSecondary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '+91',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(width: 1, height: 22, color: AppColors.border),
                                  ],
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                              filled: true,
                              fillColor: Colors.white,
                              helperText: kDebugMode
                                  ? 'Debug: use 9999999991 → OTP 123456 (no reCAPTCHA)'
                                  : 'We will send a secure 6-digit code',
                              helperMaxLines: 2,
                              helperStyle: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: 'Continue',
                            isLoading: auth.isLoading,
                            onPressed: _continue,
                          ),
                          const Spacer(),
                          const SizedBox(height: 28),
                          const Divider(color: AppColors.border, thickness: 1),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              context.read<AuthProvider>().continueAsGuest();
                              context.go('/buyer/home');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Continue as Guest',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
