import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/notification_nav.dart';
import 'providers/app_providers.dart';

class BagMandiApp extends StatefulWidget {
  const BagMandiApp({super.key});

  @override
  State<BagMandiApp> createState() => _BagMandiAppState();
}

class _BagMandiAppState extends State<BagMandiApp> {
  late final AuthProvider _auth = AuthProvider()..bootstrap();
  late final EnquiryProvider _enquiries = EnquiryProvider();
  late final HomeProvider _home = HomeProvider();
  late final GoRouter _router = AppRouter.create(_auth);

  @override
  void initState() {
    super.initState();
    NotificationNav.attach(_router, role: () => _auth.role);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _enquiries),
        ChangeNotifierProvider.value(value: _home),
      ],
      child: MaterialApp.router(
        title: 'BagMandi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
