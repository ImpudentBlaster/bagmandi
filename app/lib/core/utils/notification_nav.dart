import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_providers.dart';

/// Central place for notification → screen redirects.
class NotificationNav {
  static GoRouter? router;
  static UserRole? Function()? roleGetter;

  static void attach(GoRouter goRouter, {UserRole? Function()? role}) {
    router = goRouter;
    if (role != null) roleGetter = role;
  }

  static UserRole? _resolveRole(BuildContext? context) {
    if (roleGetter != null) return roleGetter!();
    if (context != null && context.mounted) {
      try {
        return context.read<AuthProvider>().role;
      } catch (_) {}
    }
    return null;
  }

  /// Opens the right screen for a notification [type] + [refId].
  static void open({
    BuildContext? context,
    String? type,
    String? refId,
    UserRole? role,
  }) {
    final t = (type ?? '').trim().toLowerCase();
    final id = refId?.trim();
    final resolvedRole = role ?? _resolveRole(context);
    final r = router;

    void pushPath(String path) {
      if (r != null) {
        r.push(path);
        return;
      }
      if (context != null && context.mounted) {
        GoRouter.of(context).push(path);
      }
    }

    void goPath(String path) {
      if (r != null) {
        r.go(path);
        return;
      }
      if (context != null && context.mounted) {
        GoRouter.of(context).go(path);
      }
    }

    if (t == 'chat' && id != null && id.isNotEmpty) {
      pushPath('/chat/$id');
      return;
    }

    if (t == 'quote') {
      if (resolvedRole == UserRole.manufacturer) {
        goPath('/manufacturer/enquiries');
      } else if (id != null && id.isNotEmpty) {
        pushPath('/buyer/enquiry/$id');
      } else {
        goPath('/buyer/enquiries');
      }
      return;
    }

    if (t == 'order') {
      goPath(
        resolvedRole == UserRole.manufacturer
            ? '/manufacturer/orders'
            : '/buyer/orders',
      );
      return;
    }

    // Unknown / missing type — open inbox list
    pushPath('/notifications');
  }

  static void openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload);
      if (map is Map) {
        open(
          type: map['type']?.toString(),
          refId: map['refId']?.toString(),
        );
      }
    } catch (_) {}
  }
}
