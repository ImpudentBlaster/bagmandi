import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/auth_navigation.dart';
import '../../providers/app_providers.dart';
import '../../services/chat_service.dart';
import 'app_back_scope.dart';

class BuyerShell extends StatefulWidget {
  final Widget child;

  const BuyerShell({super.key, required this.child});

  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _index = 0;

  static const _home = '/buyer/home';
  static const _routes = [_home, '/buyer/enquiries', '/buyer/messages', '/buyer/orders', '/buyer/profile'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (!auth.isGuest && user != null) {
      final next = AuthNavigation.routeFor(user);
      if (next != _home &&
          (AuthNavigation.needsRole(user) ||
              AuthNavigation.needsProfile(user) ||
              AuthNavigation.needsLocation(user))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(next);
        });
      }
    }

    final location = GoRouterState.of(context).uri.toString();
    _index = _routes.indexWhere((r) => location.startsWith(r));
    if (_index < 0) _index = 0;

    final userId = user?.id;

    return AppBackScope(
      homePath: _home,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => context.go(_routes[i]),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
              const BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Enquiries'),
              BottomNavigationBarItem(
                icon: _UnreadIcon(userId: userId, color: AppColors.textSecondary, outlined: true),
                activeIcon: _UnreadIcon(userId: userId, color: AppColors.primary, outlined: false),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class ManufacturerShell extends StatefulWidget {
  final Widget child;

  const ManufacturerShell({super.key, required this.child});

  @override
  State<ManufacturerShell> createState() => _ManufacturerShellState();
}

class _ManufacturerShellState extends State<ManufacturerShell> {
  int _index = 0;

  static const _home = '/manufacturer/dashboard';
  static const _routes = [
    _home,
    '/manufacturer/enquiries',
    '/manufacturer/messages',
    '/manufacturer/orders',
    '/manufacturer/profile',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      final next = AuthNavigation.routeFor(user);
      if (next != _home &&
          (AuthNavigation.needsRole(user) ||
              AuthNavigation.needsProfile(user) ||
              AuthNavigation.needsLocation(user))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(next);
        });
      }
    }

    final location = GoRouterState.of(context).uri.toString();
    _index = _routes.indexWhere((r) => location.startsWith(r));
    if (_index < 0) _index = 0;
    final userId = user?.id;

    return AppBackScope(
      homePath: _home,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => context.go(_routes[i]),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: AppColors.manufacturer,
            unselectedItemColor: AppColors.textSecondary,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
              const BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), activeIcon: Icon(Icons.inbox), label: 'Enquiries'),
              BottomNavigationBarItem(
                icon: _UnreadIcon(userId: userId, color: AppColors.textSecondary, outlined: true),
                activeIcon: _UnreadIcon(userId: userId, color: AppColors.manufacturer, outlined: false),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
              const BottomNavigationBarItem(icon: Icon(Icons.business_outlined), activeIcon: Icon(Icons.business), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadIcon extends StatelessWidget {
  final String? userId;
  final Color color;
  final bool outlined;

  const _UnreadIcon({
    required this.userId,
    required this.color,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      outlined ? Icons.chat_outlined : Icons.chat,
      color: color,
    );
    if (userId == null) return icon;
    return StreamBuilder<int>(
      stream: ChatService.instance.watchTotalUnread(userId!),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return icon;
        return Badge(
          label: Text(count > 99 ? '99+' : '$count'),
          child: icon,
        );
      },
    );
  }
}
