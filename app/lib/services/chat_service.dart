import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/config/app_backend.dart';
import '../core/utils/date_parse.dart';
import 'notification_service.dart';

enum MessageTick { sent, delivered, read }

class ChatPresence {
  final bool flaggedOnline;
  final DateTime? lastActiveAt;

  const ChatPresence({
    this.flaggedOnline = false,
    this.lastActiveAt,
  });

  bool get online {
    if (!flaggedOnline || lastActiveAt == null) return false;
    return DateTime.now().difference(lastActiveAt!) <=
        const Duration(seconds: 90);
  }
}

class ChatPeerInfo {
  final String id;
  final String displayName;
  final String? personName;
  final String? businessName;
  final String role;
  final String? location;
  final bool isVerified;

  const ChatPeerInfo({
    required this.id,
    required this.displayName,
    this.personName,
    this.businessName,
    this.role = '',
    this.location,
    this.isVerified = false,
  });

  String get roleLabel {
    if (role == 'manufacturer') return 'Manufacturer / Seller';
    if (role == 'buyer') return 'Buyer / User';
    return role.isEmpty ? 'Member' : role;
  }

  /// Primary line in chat header (business for seller, person for buyer).
  String get headerTitle {
    if (role == 'manufacturer') {
      final biz = businessName?.trim();
      if (biz != null && biz.isNotEmpty) return biz;
    }
    return displayName;
  }

  /// Secondary line under title.
  String get headerSubtitle {
    final parts = <String>[];
    if (role == 'manufacturer') {
      parts.add('Seller');
      final person = personName?.trim();
      if (person != null && person.isNotEmpty && person != headerTitle) {
        parts.add(person);
      }
    } else if (role == 'buyer') {
      parts.add('Buyer');
      final biz = businessName?.trim();
      if (biz != null && biz.isNotEmpty && biz != headerTitle) {
        parts.add(biz);
      }
    }
    if (location != null && location!.trim().isNotEmpty) {
      parts.add(location!.trim());
    }
    return parts.join(' · ');
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String? senderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.senderName,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: parseAppDate(map['createdAt']),
      senderName: map['senderName']?.toString(),
    );
  }

  /// Tick state for *my* outgoing messages based on peer last-read time.
  /// Single grey = delivered; double blue = read.
  MessageTick tickForPeerRead(DateTime? peerLastReadAt) {
    if (peerLastReadAt != null &&
        !peerLastReadAt.isBefore(createdAt.subtract(const Duration(seconds: 1)))) {
      return MessageTick.read;
    }
    return MessageTick.delivered;
  }
}

class ChatThread {
  final String id;
  final List<String> participantIds;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime updatedAt;
  final Map<String, String> names;
  final Map<String, String> businessNames;
  final Map<String, String> personNames;
  final Map<String, String> roles;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime> lastReadAt;
  final Map<String, DateTime> typingAt;

  ChatThread({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastSenderId,
    required this.updatedAt,
    this.names = const {},
    this.businessNames = const {},
    this.personNames = const {},
    this.roles = const {},
    this.unreadCounts = const {},
    this.lastReadAt = const {},
    this.typingAt = const {},
  });

  factory ChatThread.fromMap(Map<String, dynamic> map, String id) {
    final rawUnread = map['unreadCounts'];
    final unread = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((k, v) {
        unread[k.toString()] = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
      });
    }
    final rawRead = map['lastReadAt'];
    final lastRead = <String, DateTime>{};
    if (rawRead is Map) {
      rawRead.forEach((k, v) {
        lastRead[k.toString()] = parseAppDate(v);
      });
    }
    final rawTyping = map['typing'];
    final typing = <String, DateTime>{};
    if (rawTyping is Map) {
      rawTyping.forEach((k, v) {
        typing[k.toString()] = parseAppDate(v);
      });
    }
    return ChatThread(
      id: id,
      participantIds: List<String>.from(map['participantIds'] ?? const []),
      lastMessage: map['lastMessage']?.toString(),
      lastSenderId: map['lastSenderId']?.toString(),
      updatedAt: parseAppDate(map['updatedAt']),
      names: _stringMap(map['names']),
      businessNames: _stringMap(map['businessNames']),
      personNames: _stringMap(map['personNames']),
      roles: _stringMap(map['roles']),
      unreadCounts: unread,
      lastReadAt: lastRead,
      typingAt: typing,
    );
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  String otherId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => myId);

  String titleFor(String myId) {
    final other = otherId(myId);
    final role = roles[other] ?? '';
    if (role == 'manufacturer') {
      final biz = businessNames[other]?.trim();
      if (biz != null && biz.isNotEmpty) return biz;
    }
    final name = names[other]?.trim();
    if (name != null && name.isNotEmpty) return name;
    final person = personNames[other]?.trim();
    if (person != null && person.isNotEmpty) return person;
    return 'Chat';
  }

  String? subtitleFor(String myId) {
    final other = otherId(myId);
    final role = roles[other] ?? '';
    final parts = <String>[];
    if (role == 'manufacturer') {
      parts.add('Seller');
      final person = personNames[other]?.trim();
      final title = titleFor(myId);
      if (person != null && person.isNotEmpty && person != title) {
        parts.add(person);
      }
    } else if (role == 'buyer') {
      parts.add('Buyer');
      final biz = businessNames[other]?.trim();
      final title = titleFor(myId);
      if (biz != null && biz.isNotEmpty && biz != title) parts.add(biz);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  int unreadFor(String myId) => unreadCounts[myId] ?? 0;

  DateTime? lastReadFor(String userId) => lastReadAt[userId];

  /// Peer is typing if their last typing pulse is fresh.
  bool isTyping(String userId, {Duration window = const Duration(seconds: 5)}) {
    final at = typingAt[userId];
    if (at == null) return false;
    return DateTime.now().difference(at) <= window;
  }
}

/// Firestore-backed 1:1 messaging for buyers ↔ manufacturers.
class ChatService {
  ChatService._();
  static final instance = ChatService._();

  /// Peer userId of the chat screen currently open on THIS device.
  static String? activePeerId;

  final Map<String, Stream<ChatThread?>> _threadStreams = {};
  /// Last inbox snapshot per user — avoids blank/reload flash on tab reopen.
  final Map<String, List<ChatThread>> _inboxCache = {};

  List<ChatThread>? cachedInbox(String userId) => _inboxCache[userId];

  FirebaseFirestore? get _db {
    if (!AppBackend.firebaseReady) return null;
    return FirebaseFirestore.instance;
  }

  String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}__${ids[1]}';
  }

  Future<void> setViewing({
    required String chatId,
    required String userId,
    required bool viewing,
  }) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('chats').doc(chatId).set({
        'viewing.$userId': viewing ? true : FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setViewing: $e');
    }
  }

  Future<String> ensureChat({
    required String myId,
    required String myName,
    required String otherId,
    required String otherName,
    String? myBusinessName,
    String? myPersonName,
    String? myRole,
    String? otherBusinessName,
    String? otherPersonName,
    String? otherRole,
  }) async {
    final id = chatIdFor(myId, otherId);
    final db = _db;
    if (db == null) return id;
    if (otherId.trim().isEmpty || myId.trim().isEmpty) {
      throw Exception('Invalid chat user');
    }

    final ref = db.collection('chats').doc(id);

    // Dot-path merge works for both first create and later updates.
    // Always send participantIds so security rules allow the write.
    final mergePayload = <String, dynamic>{
      'participantIds': [myId, otherId],
      'names.$myId': myName,
      'personNames.$myId': myPersonName ?? myName,
      if (myBusinessName != null && myBusinessName.trim().isNotEmpty)
        'businessNames.$myId': myBusinessName.trim(),
      if (myRole != null && myRole.isNotEmpty) 'roles.$myId': myRole,
      'unreadCounts.$myId': 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (otherName.trim().isNotEmpty && otherName.trim() != 'User') {
      mergePayload['names.$otherId'] = otherName.trim();
    }
    if (otherPersonName != null && otherPersonName.trim().isNotEmpty) {
      mergePayload['personNames.$otherId'] = otherPersonName.trim();
    }
    if (otherBusinessName != null && otherBusinessName.trim().isNotEmpty) {
      mergePayload['businessNames.$otherId'] = otherBusinessName.trim();
    }
    if (otherRole != null && otherRole.isNotEmpty) {
      mergePayload['roles.$otherId'] = otherRole;
    }

    try {
      await ref
          .set(mergePayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('Chat open timed out. Check internet and try again.');
    } on FirebaseException catch (e) {
      // Race: peer created at same time, or transient rule miss — retry once.
      if (e.code == 'permission-denied') {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await ref
            .set(mergePayload, SetOptions(merge: true))
            .timeout(const Duration(seconds: 8));
      } else {
        rethrow;
      }
    }

    // Drop any stale stream cache for this room.
    _threadStreams.remove(id);
    return id;
  }

  Stream<List<ChatThread>> watchInbox(String userId) async* {
    final db = _db;
    if (db == null) {
      _inboxCache[userId] = const [];
      yield const [];
      return;
    }

    final query = db
        .collection('chats')
        .where('participantIds', arrayContains: userId);

    List<ChatThread> mapDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
      final list = docs
          .map((d) => ChatThread.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _inboxCache[userId] = list;
      return list;
    }

    // Seed UI immediately (cache or empty) — never leave Messages on a spinner.
    yield _inboxCache[userId] ?? const [];

    try {
      final snap = await query.get().timeout(const Duration(seconds: 10));
      yield mapDocs(snap.docs);
    } catch (e) {
      debugPrint('watchInbox get: $e');
      yield _inboxCache[userId] ?? const [];
    }

    yield* query.snapshots().map((snap) => mapDocs(snap.docs)).handleError(
      (Object e, StackTrace st) {
        debugPrint('watchInbox snapshots: $e');
      },
    );
  }

  Stream<ChatThread?> watchThread(String chatId) {
    final db = _db;
    if (db == null) return Stream.value(null);
    // Fresh stream each time — avoids a poisoned cached error stream.
    return db.collection('chats').doc(chatId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ChatThread.fromMap(snap.data()!, snap.id);
    });
  }

  Stream<int> watchTotalUnread(String userId) {
    return watchInbox(userId).map(
      (threads) =>
          threads.fold<int>(0, (total, t) => total + t.unreadFor(userId)),
    );
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) {
    final db = _db;
    if (db == null) return Stream.value(const []);
    return db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .handleError((Object e, StackTrace st) {
          debugPrint('watchMessages: $e');
        })
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessage.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? senderName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final db = _db;
    if (db == null) {
      throw Exception('Chat needs an online connection');
    }

    final chatRef = db.collection('chats').doc(chatId);
    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      throw Exception('Chat not found');
    }
    final participants = List<String>.from(
      chatSnap.data()?['participantIds'] ?? const [],
    );
    if (!participants.contains(senderId)) {
      throw Exception('You are not part of this chat');
    }
    final otherId = participants.firstWhere(
      (id) => id != senderId,
      orElse: () => '',
    );

    final now = Timestamp.now();
    final batch = db.batch();
    final msgRef = chatRef.collection('messages').doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'text': trimmed,
      'createdAt': now,
      if (senderName != null && senderName.trim().isNotEmpty)
        'senderName': senderName.trim(),
      'status': 'delivered',
    });
    batch.set(
      chatRef,
      {
        'lastMessage': trimmed,
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        if (otherId.isNotEmpty)
          'unreadCounts.$otherId': FieldValue.increment(1),
        'unreadCounts.$senderId': 0,
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    if (otherId.isNotEmpty) {
      // Skip alert if recipient currently has this chat open.
      var peerViewing = false;
      try {
        final fresh = await chatRef.get();
        final viewing = fresh.data()?['viewing'];
        if (viewing is Map && viewing[otherId] == true) {
          peerViewing = true;
        }
      } catch (_) {}

      if (!peerViewing) {
        final preview =
            trimmed.length > 90 ? '${trimmed.substring(0, 90)}…' : trimmed;
        final title = (senderName != null && senderName.trim().isNotEmpty)
            ? senderName.trim()
            : 'New message';
        try {
          await NotificationService.instance.createNotification(
            userId: otherId,
            title: title,
            body: preview,
            type: 'chat',
            refId: senderId,
          );
        } catch (e) {
          debugPrint('chat notify: $e');
        }
      }
    }
  }

  /// Marks chat as read for [userId] and records last-read time for blue ticks.
  Future<void> markRead({
    required String chatId,
    required String userId,
  }) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('chats').doc(chatId).set({
        'unreadCounts.$userId': 0,
        'lastReadAt.$userId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('markRead: $e');
    }
  }

  Future<void> setTyping({
    required String chatId,
    required String userId,
    required bool typing,
  }) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('chats').doc(chatId).set({
        'typing.$userId':
            typing ? FieldValue.serverTimestamp() : FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setTyping: $e');
    }
  }

  /// Lightweight presence for chat header "online".
  Future<void> setChatPresence({
    required String userId,
    required bool online,
  }) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('users').doc(userId).set({
        'chatOnline': online,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setChatPresence: $e');
    }
  }

  Stream<ChatPresence> watchPresence(String userId) {
    final db = _db;
    if (db == null) {
      return Stream.value(const ChatPresence());
    }
    return db.collection('users').doc(userId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return const ChatPresence();
      return ChatPresence(
        flaggedOnline: data['chatOnline'] == true,
        lastActiveAt: parseAppDate(data['lastActiveAt']),
      );
    });
  }

  Future<Map<String, dynamic>?> loadUserBrief(String userId) async {
    final db = _db;
    if (db == null) return null;
    try {
      final doc = await db.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('loadUserBrief: $e');
      return null;
    }
  }

  static ChatPeerInfo peerInfoFromBrief(String id, Map<String, dynamic>? brief) {
    final role = brief?['role']?.toString() ?? '';
    final business = brief?['businessName']?.toString().trim() ?? '';
    final name = brief?['name']?.toString().trim() ?? '';
    final city = brief?['city']?.toString().trim() ?? '';
    final state = brief?['state']?.toString().trim() ?? '';
    final location = [city, state].where((e) => e.isNotEmpty).join(', ');
    final verified = brief?['isVerified'] == true;

    String display;
    if (role == 'manufacturer' && business.isNotEmpty) {
      display = business;
    } else if (name.isNotEmpty) {
      display = name;
    } else if (business.isNotEmpty) {
      display = business;
    } else {
      display = 'User';
    }

    return ChatPeerInfo(
      id: id,
      displayName: display,
      personName: name.isNotEmpty ? name : null,
      businessName: business.isNotEmpty ? business : null,
      role: role,
      location: location.isNotEmpty ? location : null,
      isVerified: verified,
    );
  }

  static String displayNameFromBrief(Map<String, dynamic>? brief) {
    return peerInfoFromBrief('', brief).displayName;
  }
}
