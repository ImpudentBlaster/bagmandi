import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/config/app_backend.dart';
import '../core/utils/notification_nav.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.messageId}');
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? type;
  final String? refId;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type,
    this.refId,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['createdAt'];
    DateTime created;
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }
    return AppNotification(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type']?.toString(),
      refId: map['refId']?.toString(),
      read: map['read'] == true,
      createdAt: created,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  StreamSubscription<QuerySnapshot>? _watchSub;

  static const _androidChannel = AndroidNotificationChannel(
    'bagmandi_alerts',
    'BagMandi Alerts',
    description: 'Chat, quotes, orders and account alerts',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready || !AppBackend.firebaseReady) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        NotificationNav.openFromPayload(resp.payload);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((message) {
      final title =
          message.notification?.title ?? message.data['title'] ?? 'BagMandi';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      showLocal(
        title: title.toString(),
        body: body.toString(),
        type: message.data['type']?.toString(),
        refId: message.data['refId']?.toString(),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationNav.open(
        type: message.data['type']?.toString(),
        refId: message.data['refId']?.toString(),
      );
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Defer until router is ready.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        NotificationNav.open(
          type: initial.data['type']?.toString(),
          refId: initial.data['refId']?.toString(),
        );
      });
    }

    _ready = true;
  }

  Future<String?> getToken() async {
    if (!AppBackend.firebaseReady) return null;
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM token error: $e');
      return null;
    }
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String? type,
    String? refId,
  }) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'type': type,
        'refId': refId,
        'title': title,
      }),
    );
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    String? refId,
  }) async {
    if (!AppBackend.firebaseReady || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'refId': refId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> watchForUser(String userId) {
    if (!AppBackend.firebaseReady) {
      return Stream.value(const []);
    }
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppNotification.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<void> markRead(String id) async {
    if (!AppBackend.firebaseReady) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    if (!AppBackend.firebaseReady) return;
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Live toast when a new unread notification arrives for this user.
  void startInboxWatcher(String userId) {
    _watchSub?.cancel();
    if (!AppBackend.firebaseReady) return;
    var lastSeen = DateTime.now();
    _watchSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        final n = AppNotification.fromMap(doc.data(), doc.id);
        if (!n.read && n.createdAt.isAfter(lastSeen)) {
          showLocal(
            title: n.title,
            body: n.body,
            type: n.type,
            refId: n.refId,
          );
        }
      }
      if (snap.docs.isNotEmpty) {
        final newest =
            AppNotification.fromMap(snap.docs.first.data(), snap.docs.first.id);
        if (newest.createdAt.isAfter(lastSeen)) lastSeen = newest.createdAt;
      }
    });
  }

  void stopInboxWatcher() {
    _watchSub?.cancel();
    _watchSub = null;
  }
}
