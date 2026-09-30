import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';

/// Role-aware chat navigation — same screens for buyer & manufacturer.
class ChatNav {
  static String room(String otherUserId) => '/chat/$otherUserId';

  static String inbox(BuildContext context) {
    final role = context.read<AuthProvider>().role;
    return role == UserRole.manufacturer
        ? '/manufacturer/messages'
        : '/buyer/messages';
  }

  static void openRoom(BuildContext context, String otherUserId) {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest || auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to chat')),
      );
      context.push('/login');
      return;
    }
    if (otherUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start chat')),
      );
      return;
    }
    context.push(room(otherUserId));
  }

  static void openInbox(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest || auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view messages')),
      );
      context.push('/login');
      return;
    }
    context.go(inbox(context));
  }
}
