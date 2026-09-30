import '../../models/models.dart';

/// Post-login destination helpers for BagMandi.
class AuthNavigation {
  static bool needsRole(AppUser? user) {
    if (user == null) return true;
    return user.role != UserRole.buyer && user.role != UserRole.manufacturer;
  }

  /// Name / company profile missing or still on auto-generated defaults.
  static bool needsProfile(AppUser? user) {
    if (user == null) return true;
    if (needsRole(user)) return true;

    final name = user.name?.trim() ?? '';
    final business = user.businessName?.trim() ?? '';
    final type = user.businessType?.trim() ?? '';

    if (business.length < 2) return true;
    if (business == 'My Business' || business == 'My Manufacturing Unit') return true;
    if (type.isEmpty) return true;

    if (user.role == UserRole.manufacturer) {
      // GST is optional — companies without GSTIN can skip during registration.
      if ((user.addressLine1?.trim() ?? '').length < 3) return true;
      if ((user.city?.trim() ?? '').length < 2) return true;
      if ((user.state?.trim() ?? '').isEmpty) return true;
      if ((user.pincode?.trim() ?? '').length != 6) return true;
      if ((user.email?.trim() ?? '').isEmpty) return true;
      if ((user.contactNumber?.trim() ?? user.phone).length < 10) return true;
      return false;
    }

    if (name.length < 2) return true;
    if (RegExp(r'^User\s+\d+$').hasMatch(name)) return true;
    return false;
  }

  /// When company address is filled, skip separate location screen.
  static bool needsLocation(AppUser? user) {
    if (user == null) return true;
    if (user.role == UserRole.manufacturer) {
      final city = user.city?.trim() ?? '';
      final addr = user.addressLine1?.trim() ?? '';
      if (city.isNotEmpty && addr.isNotEmpty) return false;
    }
    return user.location == null || user.location!.trim().isEmpty;
  }

  /// Force onboarding path until profile + location are ready.
  static String routeFor(AppUser user) {
    if (user.role == UserRole.admin) return '/login';
    if (needsRole(user)) return '/role-selection';
    if (needsProfile(user)) return '/complete-profile';
    if (needsLocation(user)) return '/location';
    return user.role == UserRole.manufacturer
        ? '/manufacturer/dashboard'
        : '/buyer/home';
  }
}
