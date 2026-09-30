import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/auth_navigation.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otp = '';
  int _resendSeconds = 25;
  Timer? _timer;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 25);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        setState(() => _resendSeconds = 0);
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return '+91 ${widget.phone}';
  }

  void _onKey(String value) {
    if (_verifying) return;
    HapticFeedback.selectionClick();
    if (_otp.length >= 6) return;
    setState(() => _otp += value);
    if (_otp.length == 6) _verify();
  }

  void _onBackspace() {
    if (_verifying || _otp.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  Future<void> _verify() async {
    if (_otp.length != 6 || _verifying) return;
    setState(() => _verifying = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(_otp);
    if (!mounted) return;
    if (success) {
      final role = auth.user?.role;
      // Admin belongs on web panel; keep role safe on mobile.
      if (role == UserRole.admin) {
        setState(() {
          _verifying = false;
          _otp = '';
        });
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
        context.go('/login');
        return;
      }
      final user = auth.user;
      if (user == null) {
        context.go('/login');
        return;
      }
      context.go(AuthNavigation.routeFor(user));
    } else {
      setState(() {
        _verifying = false;
        _otp = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Invalid OTP. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.go('/login'),
              ),
            ),
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.28),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Verify OTP',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter the 6 digit OTP sent to',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formattedPhone,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) {
                          final filled = i < _otp.length;
                          final active = i == _otp.length && !_verifying;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 46,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : filled
                                        ? AppColors.textPrimary.withValues(alpha: 0.35)
                                        : AppColors.border,
                                width: active ? 1.6 : 1,
                              ),
                            ),
                            child: Text(
                              filled ? _otp[i] : '',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 22),
                      if (_verifying)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else if (_resendSeconds > 0)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Resend OTP in ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextSpan(
                                text: '00:${_resendSeconds.toString().padLeft(2, '0')}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            context.read<AuthProvider>().sendOtp(widget.phone);
                            setState(() => _otp = '');
                            _startTimer();
                          },
                          child: Text(
                            'Resend OTP',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _NumericKeypad(
              onKey: _onKey,
              onBackspace: _onBackspace,
            ),
          ],
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  const _NumericKeypad({
    required this.onKey,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(['1', '2', '3']),
          _divider(),
          _row(['4', '5', '6']),
          _divider(),
          _row(['7', '8', '9']),
          _divider(),
          SizedBox(
            height: 58,
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                _vDivider(),
                Expanded(child: _KeyButton(label: '0', onTap: () => onKey('0'))),
                _vDivider(),
                Expanded(
                  child: _KeyButton(
                    onTap: onBackspace,
                    child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 1, color: AppColors.border);

  Widget _vDivider() => Container(width: 1, color: AppColors.border);

  Widget _row(List<String> keys) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) _vDivider(),
            Expanded(child: _KeyButton(label: keys[i], onTap: () => onKey(keys[i]))),
          ],
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback onTap;

  const _KeyButton({
    required this.onTap,
    this.label,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: child ??
              Text(
                label ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
        ),
      ),
    );
  }
}
