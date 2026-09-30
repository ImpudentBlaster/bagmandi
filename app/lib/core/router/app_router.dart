import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/complete_profile_screen.dart';
import '../../features/auth/location_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/buyer/buyer_enquiries_screen.dart';
import '../../features/buyer/buyer_home_screen.dart';
import '../../features/buyer/buyer_other_screens.dart';
import '../../features/buyer/enquiry_detail_screen.dart';
import '../../features/buyer/post_requirement_screen.dart';
import '../../features/manufacturer/manufacturer_dashboard_screen.dart';
import '../../features/manufacturer/manufacturer_screens.dart';
import '../../features/shared/chat_screen.dart';
import '../../features/shared/notifications_screen.dart';
import '../../features/shared/pp_rates_screen.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_back_scope.dart';
import '../../shared/widgets/app_shells.dart';
import '../utils/auth_navigation.dart';

class AppRouter {
  static Widget _buyerStack(Widget child) =>
      AppBackScope(homePath: '/buyer/home', child: child);

  static Widget _mfrStack(Widget child) =>
      AppBackScope(homePath: '/manufacturer/dashboard', child: child);

  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        if (!auth.ready) {
          return state.matchedLocation == '/' ? null : '/';
        }

        final loc = state.matchedLocation;
        final user = auth.user;
        final loggedIn = user != null && !auth.isGuest;

        // Splash owns first paint / branding.
        if (loc == '/') return null;

        if (!loggedIn) {
          if (loc == '/login' || loc.startsWith('/otp')) return null;
          if (auth.isGuest && (loc.startsWith('/buyer') || loc == '/notifications')) {
            return null;
          }
          return '/login';
        }

        // Already signed in — never show login/OTP again.
        if (loc == '/login' || loc.startsWith('/otp')) {
          return AuthNavigation.routeFor(user);
        }

        final needed = AuthNavigation.routeFor(user);
        final onboarding = loc == '/role-selection' ||
            loc == '/complete-profile' ||
            loc == '/location';
        final inApp = loc.startsWith('/buyer') ||
            loc.startsWith('/manufacturer') ||
            loc.startsWith('/chat') ||
            loc == '/notifications';

        if (inApp &&
            (AuthNavigation.needsRole(user) ||
                AuthNavigation.needsProfile(user) ||
                AuthNavigation.needsLocation(user))) {
          return needed;
        }

        // If onboarding step is already done, skip ahead.
        // Allow /complete-profile always so companies can edit GST/address later.
        if (onboarding && loc != needed) {
          if (loc == '/role-selection' && !AuthNavigation.needsRole(user)) {
            return needed;
          }
          if (loc == '/location' && !AuthNavigation.needsLocation(user)) {
            return needed;
          }
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/otp',
          builder: (_, state) => OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
        ),
        GoRoute(path: '/role-selection', builder: (_, __) => const RoleSelectionScreen()),
        GoRoute(path: '/complete-profile', builder: (_, __) => const CompleteProfileScreen()),
        GoRoute(path: '/location', builder: (_, __) => const LocationScreen()),
        GoRoute(
          path: '/notifications',
          builder: (context, __) {
            final role = context.read<AuthProvider>().role;
            final home = role == UserRole.manufacturer
                ? '/manufacturer/dashboard'
                : '/buyer/home';
            return AppBackScope(homePath: home, child: const NotificationsScreen());
          },
        ),

        ShellRoute(
          builder: (_, __, child) => BuyerShell(child: child),
          routes: [
            GoRoute(path: '/buyer/home', builder: (_, __) => const BuyerHomeScreen()),
            GoRoute(path: '/buyer/enquiries', builder: (_, __) => const BuyerEnquiriesScreen()),
            GoRoute(path: '/buyer/messages', builder: (_, __) => const MessagesInboxScreen()),
            GoRoute(path: '/buyer/orders', builder: (_, __) => const BuyerOrdersScreen()),
            GoRoute(path: '/buyer/profile', builder: (_, __) => const BuyerProfileScreen()),
          ],
        ),
        GoRoute(
          path: '/buyer/post-requirement',
          builder: (_, state) => _buyerStack(
            PostRequirementScreen(
              initialBagType: state.uri.queryParameters['bagType'],
            ),
          ),
        ),
        GoRoute(
          path: '/buyer/find-manufacturer',
          builder: (_, __) => _buyerStack(const FindManufacturerScreen()),
        ),
        GoRoute(
          path: '/buyer/enquiry/:id',
          builder: (_, state) => _buyerStack(
            EnquiryDetailScreen(enquiryId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/buyer/enquiry/:id/compare',
          builder: (_, state) => _buyerStack(
            CompareQuotesScreen(enquiryId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/buyer/enquiry/:id/quote/:quoteId',
          builder: (_, state) => _buyerStack(
            ViewQuoteScreen(
              enquiryId: state.pathParameters['id']!,
              quoteId: state.pathParameters['quoteId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/buyer/chat/:userId',
          redirect: (_, state) => '/chat/${state.pathParameters['userId']}',
        ),
        GoRoute(
          path: '/chat/:userId',
          builder: (context, state) {
            final role = context.read<AuthProvider>().role;
            final home = role == UserRole.manufacturer
                ? '/manufacturer/dashboard'
                : '/buyer/home';
            return AppBackScope(
              homePath: home,
              child: ChatScreen(userId: state.pathParameters['userId']!),
            );
          },
        ),
        GoRoute(
          path: '/pp-rates',
          builder: (context, __) {
            final role = context.read<AuthProvider>().role;
            final home = role == UserRole.manufacturer
                ? '/manufacturer/dashboard'
                : '/buyer/home';
            return AppBackScope(homePath: home, child: const PpRatesScreen());
          },
        ),

        ShellRoute(
          builder: (_, __, child) => ManufacturerShell(child: child),
          routes: [
            GoRoute(path: '/manufacturer/dashboard', builder: (_, __) => const ManufacturerDashboardScreen()),
            GoRoute(path: '/manufacturer/enquiries', builder: (_, __) => const ManufacturerEnquiriesScreen()),
            GoRoute(path: '/manufacturer/messages', builder: (_, __) => const MessagesInboxScreen()),
            GoRoute(path: '/manufacturer/orders', builder: (_, __) => const ManufacturerOrdersScreen()),
            GoRoute(path: '/manufacturer/profile', builder: (_, __) => const ManufacturerProfileScreen()),
          ],
        ),
        GoRoute(
          path: '/manufacturer/marketplace',
          builder: (_, __) => _mfrStack(const MarketplaceScreen()),
        ),
        GoRoute(
          path: '/manufacturer/chat/:userId',
          redirect: (_, state) => '/chat/${state.pathParameters['userId']}',
        ),
        GoRoute(
          path: '/manufacturer/send-quote/:id',
          builder: (_, state) => _mfrStack(
            SendQuoteScreen(enquiryId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/manufacturer/material-requirement',
          builder: (_, __) => _mfrStack(const MaterialRequirementScreen()),
        ),
      ],
    );
  }
}
