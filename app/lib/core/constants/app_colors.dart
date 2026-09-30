import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF189F43);
  static const primaryDark = Color(0xFF0E7A32);
  static const splash = Color(0xFF0A4D28);
  static const primaryLight = Color(0xFFE7F8ED);
  static const manufacturer = Color(0xFF4C4B9E);
  static const manufacturerLight = Color(0xFFEEEDF7);
  static const secondary = Color(0xFF343A40);
  static const background = Color(0xFFF4F6F8);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1D21);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF189F43);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC3545);
  static const info = Color(0xFF3B82F6);
  static const purple = Color(0xFF4C4B9E);
  static const quoted = Color(0xFF189F43);
  static const open = Color(0xFF3B82F6);
  static const closed = Color(0xFF6B7280);
  static const rateCard = Color(0xFF121418);
  static const adminSidebar = Color(0xFF1A1D21);
  static const adminSidebarActive = Color(0xFF189F43);
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 24.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
}
