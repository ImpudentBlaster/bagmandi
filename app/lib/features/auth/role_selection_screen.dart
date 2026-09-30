import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/auth_navigation.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;

  Future<void> _select(UserRole role) async {
    setState(() => _selectedRole = role);
    final auth = context.read<AuthProvider>();
    await auth.selectRole(role);
    if (!mounted) return;
    final user = auth.user;
    if (user == null) {
      context.go('/login');
      return;
    }
    context.go(AuthNavigation.routeFor(user));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Choose Your Role',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select the option that best describes you',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _RoleCard(
                        title: 'I am a Buyer',
                        subtitle: 'Wholesaler, Retailer, Trader, Distributor',
                        isSelected: _selectedRole == UserRole.buyer,
                        onTap: () => _select(UserRole.buyer),
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E4F8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 30,
                              color: Color(0xFF1E3A8A),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        title: 'I am a Manufacturer',
                        subtitle: 'Manufacturer, Supplier of Bags or Material',
                        isSelected: _selectedRole == UserRole.manufacturer,
                        onTap: () => _select(UserRole.manufacturer),
                        icon: const Icon(
                          Icons.factory_outlined,
                          size: 34,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.textPrimary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 56, height: 48, child: Center(child: icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
