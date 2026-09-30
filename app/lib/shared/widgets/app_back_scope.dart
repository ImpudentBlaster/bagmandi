import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Android back: leave stack → home first; on home, double-back to exit.
class AppBackScope extends StatefulWidget {
  final Widget child;
  final String homePath;

  const AppBackScope({
    super.key,
    required this.child,
    required this.homePath,
  });

  @override
  State<AppBackScope> createState() => _AppBackScopeState();
}

class _AppBackScopeState extends State<AppBackScope> {
  DateTime? _lastExitPrompt;

  bool get _onHome {
    final path = GoRouterState.of(context).uri.path;
    return path == widget.homePath;
  }

  void _handleBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (!_onHome) {
      context.go(widget.homePath);
      return;
    }
    final now = DateTime.now();
    if (_lastExitPrompt != null &&
        now.difference(_lastExitPrompt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastExitPrompt = now;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: widget.child,
    );
  }
}
