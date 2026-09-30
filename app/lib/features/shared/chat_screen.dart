import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/chat_nav.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/chat_service.dart';
import '../../shared/widgets/common_widgets.dart';

Color _accentFor(BuildContext context) {
  final role = context.watch<AuthProvider>().role;
  return role == UserRole.manufacturer ? AppColors.manufacturer : AppColors.primary;
}

Color _accentLightFor(BuildContext context) {
  final role = context.watch<AuthProvider>().role;
  return role == UserRole.manufacturer
      ? AppColors.manufacturerLight
      : AppColors.primaryLight;
}

/// 1:1 chat room — buyer ↔ manufacturer with read receipts & clear names.
class ChatScreen extends StatefulWidget {
  final String userId;

  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  String? _chatId;
  ChatPeerInfo? _peer;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _lastMsgCount = 0;
  Timer? _presenceTimer;
  Timer? _typingIdleTimer;
  Timer? _uiTick;
  bool _typingActive = false;
  String? _myId;

  @override
  void initState() {
    super.initState();
    ChatService.activePeerId = widget.userId;
    WidgetsBinding.instance.addObserver(this);
    _ctrl.addListener(_onComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    if (ChatService.activePeerId == widget.userId) {
      ChatService.activePeerId = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    _typingIdleTimer?.cancel();
    _uiTick?.cancel();
    _ctrl.removeListener(_onComposerChanged);
    _goOffline();
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markReadNow();
      _goOnline();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _goOffline();
    }
  }

  void _markReadNow() {
    final me = context.read<AuthProvider>().user;
    final chatId = _chatId;
    if (me == null || chatId == null) return;
    ChatService.instance.markRead(chatId: chatId, userId: me.id);
  }

  void _goOnline() {
    final me = context.read<AuthProvider>().user;
    if (me == null) return;
    _myId = me.id;
    ChatService.instance.setChatPresence(userId: me.id, online: true);
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      ChatService.instance.setChatPresence(userId: me.id, online: true);
    });
    _uiTick?.cancel();
    _uiTick = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() {});
    });
  }

  void _goOffline() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _uiTick?.cancel();
    _uiTick = null;
    final id = _myId;
    final chatId = _chatId;
    if (id != null && chatId != null) {
      ChatService.instance.setViewing(chatId: chatId, userId: id, viewing: false);
    }
    if (id == null) return;
    ChatService.instance.setChatPresence(userId: id, online: false);
    if (chatId != null && _typingActive) {
      _typingActive = false;
      ChatService.instance.setTyping(chatId: chatId, userId: id, typing: false);
    }
  }

  void _onComposerChanged() {
    final me = context.read<AuthProvider>().user;
    final chatId = _chatId;
    if (me == null || chatId == null) return;
    final hasText = _ctrl.text.trim().isNotEmpty;
    if (!hasText) {
      if (_typingActive) {
        _typingActive = false;
        ChatService.instance.setTyping(chatId: chatId, userId: me.id, typing: false);
      }
      _typingIdleTimer?.cancel();
      return;
    }
    // Pulse at most every ~2s while typing (avoids write spam).
    if (!_typingActive) {
      _typingActive = true;
      ChatService.instance.setTyping(chatId: chatId, userId: me.id, typing: true);
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_ctrl.text.trim().isEmpty) {
        _typingActive = false;
        ChatService.instance.setTyping(chatId: chatId, userId: me.id, typing: false);
        return;
      }
      // Keep "typing…" alive while text remains.
      ChatService.instance.setTyping(chatId: chatId, userId: me.id, typing: true);
      _typingIdleTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _typingActive = false;
        ChatService.instance.setTyping(chatId: chatId, userId: me.id, typing: false);
      });
    });
  }

  Future<void> _clearTypingNow() async {
    final me = context.read<AuthProvider>().user;
    final chatId = _chatId;
    _typingIdleTimer?.cancel();
    if (me == null || chatId == null || !_typingActive) {
      _typingActive = false;
      return;
    }
    _typingActive = false;
    await ChatService.instance.setTyping(chatId: chatId, userId: me.id, typing: false);
  }

  Future<void> _open() async {
    final me = context.read<AuthProvider>().user;
    if (me == null) {
      setState(() {
        _loading = false;
        _error = 'Please login to chat';
      });
      return;
    }
    if (me.id == widget.userId || widget.userId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = widget.userId.trim().isEmpty
            ? 'Unable to open chat'
            : 'Cannot chat with yourself';
      });
      return;
    }

    try {
      Map<String, dynamic>? brief;
      try {
        brief = await ChatService.instance
            .loadUserBrief(widget.userId)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        brief = null;
      }
      final peer = ChatService.peerInfoFromBrief(widget.userId, brief);
      final myRole = me.role.name;
      final myPerson = me.name?.trim().isNotEmpty == true ? me.name!.trim() : null;
      final myBusiness =
          me.businessName?.trim().isNotEmpty == true ? me.businessName!.trim() : null;
      final myDisplay = (myRole == 'manufacturer' && myBusiness != null)
          ? myBusiness
          : (myPerson ?? myBusiness ?? 'Me');

      final id = await ChatService.instance
          .ensureChat(
            myId: me.id,
            myName: myDisplay,
            myPersonName: myPerson ?? myDisplay,
            myBusinessName: myBusiness,
            myRole: myRole,
            otherId: widget.userId.trim(),
            otherName: peer.displayName,
            otherPersonName: peer.personName,
            otherBusinessName: peer.businessName,
            otherRole: peer.role,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      _myId = me.id;
      setState(() {
        _chatId = id;
        _peer = peer;
        _loading = false;
        _error = null;
      });

      // Don't block UI on follow-up writes.
      unawaited(ChatService.instance.markRead(chatId: id, userId: me.id));
      unawaited(
        ChatService.instance.setViewing(chatId: id, userId: me.id, viewing: true),
      );
      _goOnline();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        final raw = e.toString().replaceFirst('Exception: ', '');
        if (raw.toLowerCase().contains('permission-denied') ||
            raw.toLowerCase().contains('permission_denied')) {
          _error =
              'Chat open nahi ho paya (permission). Logout karke dubara login karke try karo.';
        } else if (raw.toLowerCase().contains('timed out') ||
            raw.toLowerCase().contains('timeout')) {
          _error = 'Chat load slow hai. Internet check karke Try again dabao.';
        } else {
          _error = raw;
        }
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final me = context.read<AuthProvider>().user;
    final chatId = _chatId;
    if (text.isEmpty || me == null || chatId == null || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    await _clearTypingNow();
    final myRole = me.role.name;
    final senderName = (myRole == 'manufacturer' &&
            me.businessName?.trim().isNotEmpty == true)
        ? me.businessName!.trim()
        : (me.name?.trim().isNotEmpty == true
            ? me.name!.trim()
            : me.businessName?.trim() ?? 'Me');
    try {
      await ChatService.instance.sendMessage(
        chatId: chatId,
        senderId: me.id,
        text: text,
        senderName: senderName,
      );
      _scrollToEnd(force: true);
    } catch (e) {
      if (!mounted) return;
      _ctrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scroll.hasClients) return;
      await Future.delayed(const Duration(milliseconds: 60));
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent + 80;
      if (force) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  void _showMessageInfo(ChatMessage message, MessageTick? tick) {
    final sent = DateFormat('dd MMM yyyy, hh:mm a').format(message.createdAt);
    String statusLine;
    switch (tick) {
      case MessageTick.read:
        statusLine = 'Read';
        break;
      case MessageTick.delivered:
        statusLine = 'Delivered';
        break;
      case MessageTick.sent:
        statusLine = 'Sent';
        break;
      case null:
        statusLine = 'Received';
        break;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message info',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 14),
            _InfoRow(icon: Icons.schedule, label: 'Sent', value: sent),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.done_all, label: 'Status', value: statusLine),
            if (message.senderName != null && message.senderName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'From',
                value: message.senderName!,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy message'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final accent = _accentFor(context);
    final accentLight = _accentLightFor(context);
    final peer = _peer;
    final title = peer?.headerTitle ?? 'Chat';
    final fallbackSubtitle = peer?.headerSubtitle ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              ChatNav.openInbox(context);
            }
          },
        ),
        titleSpacing: 0,
        title: peer == null
            ? Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))
            : StreamBuilder<ChatPresence>(
                stream: ChatService.instance.watchPresence(widget.userId),
                builder: (context, presenceSnap) {
                  final presence = presenceSnap.data;
                  return StreamBuilder<ChatThread?>(
                    stream: _chatId == null
                        ? Stream.value(null)
                        : ChatService.instance.watchThread(_chatId!),
                    builder: (context, threadSnap) {
                      final thread = threadSnap.data;
                      final typing = thread?.isTyping(widget.userId) == true;
                      final online = presence?.online == true;
                      String status;
                      Color statusColor = AppColors.textSecondary;
                      if (typing) {
                        status = 'typing…';
                        statusColor = accent;
                      } else if (online) {
                        status = 'online';
                        statusColor = const Color(0xFF2E7D32);
                      } else if (fallbackSubtitle.isNotEmpty) {
                        status = fallbackSubtitle;
                      } else {
                        status = 'tap for info';
                      }
                      return Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: accentLight,
                                child: Text(
                                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (online)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (peer.isVerified) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.verified, size: 16, color: accent),
                                    ],
                                  ],
                                ),
                                Text(
                                  status,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: typing || online
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: statusColor,
                                    fontStyle: typing
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ChatError(
                  message: _error!,
                  accent: accent,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _open();
                  },
                )
              : Column(
                  children: [
                    if (peer != null) _PeerBanner(peer: peer, accent: accent),
                    Expanded(
                      child: StreamBuilder<ChatThread?>(
                        stream: ChatService.instance.watchThread(_chatId!),
                        builder: (context, threadSnap) {
                          final thread = threadSnap.data;
                          final peerReadAt = thread?.lastReadFor(widget.userId);
                          return StreamBuilder<List<ChatMessage>>(
                            stream: ChatService.instance.watchMessages(_chatId!),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return _ChatError(
                                  message: 'Unable to load messages. Pull back and open chat again.',
                                  accent: accent,
                                  onRetry: () => setState(() {}),
                                );
                              }
                              final messages = snap.data ?? const <ChatMessage>[];
                              if (messages.length != _lastMsgCount) {
                                final previous = _lastMsgCount;
                                _lastMsgCount = messages.length;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _markReadNow();
                                  if (messages.isNotEmpty) {
                                    _scrollToEnd(force: previous > 0);
                                  }
                                });
                              }
                              if (messages.isEmpty) {
                                return _EmptyChat(
                                  accent: accent,
                                  name: title,
                                );
                              }
                              return ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                itemCount: messages.length,
                                itemBuilder: (_, i) {
                                  final m = messages[i];
                                  final mine = m.senderId == me?.id;
                                  final showDay = i == 0 ||
                                      !_sameDay(
                                        messages[i - 1].createdAt,
                                        m.createdAt,
                                      );
                                  final showName = !mine &&
                                      (i == 0 ||
                                          messages[i - 1].senderId != m.senderId);
                                  final tick = mine
                                      ? m.tickForPeerRead(peerReadAt)
                                      : null;
                                  return Column(
                                    children: [
                                      if (showDay) _DayChip(date: m.createdAt),
                                      _Bubble(
                                        message: m,
                                        mine: mine,
                                        accent: accent,
                                        tick: tick,
                                        showSenderName: showName,
                                        displayName: m.senderName ??
                                            peer?.headerTitle ??
                                            'User',
                                        onLongPress: () =>
                                            _showMessageInfo(m, tick),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _Composer(
                      controller: _ctrl,
                      focusNode: _focus,
                      accent: accent,
                      sending: _sending,
                      onSend: _send,
                    ),
                  ],
                ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PeerBanner extends StatelessWidget {
  final ChatPeerInfo peer;
  final Color accent;

  const _PeerBanner({required this.peer, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8))),
      ),
      child: Row(
        children: [
          Icon(
            peer.role == 'manufacturer' ? Icons.factory_outlined : Icons.storefront_outlined,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: 'Chatting with '),
                  TextSpan(
                    text: peer.headerTitle,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (peer.role == 'manufacturer' &&
                      peer.personName != null &&
                      peer.personName != peer.headerTitle)
                    TextSpan(text: ' · Contact: ${peer.personName}'),
                  if (peer.role == 'buyer' &&
                      peer.businessName != null &&
                      peer.businessName != peer.headerTitle)
                    TextSpan(text: ' · ${peer.businessName}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final Color accent;
  final MessageTick? tick;
  final bool showSenderName;
  final String displayName;
  final VoidCallback onLongPress;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.accent,
    required this.tick,
    required this.showSenderName,
    required this.displayName,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 6,
            left: mine ? 48 : 0,
            right: mine ? 0 : 48,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: mine ? accent : Colors.white,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSenderName) ...[
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mine ? Colors.white70 : accent,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: mine ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(message.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: mine ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  if (mine && tick != null) ...[
                    const SizedBox(width: 4),
                    _TickIcon(tick: tick!, onMineBubble: true),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickIcon extends StatelessWidget {
  final MessageTick tick;
  final bool onMineBubble;

  const _TickIcon({required this.tick, required this.onMineBubble});

  @override
  Widget build(BuildContext context) {
    // Single grey = delivered/sent · Double blue = read
    final Color grey = onMineBubble ? Colors.white70 : AppColors.textSecondary;
    switch (tick) {
      case MessageTick.sent:
      case MessageTick.delivered:
        return Icon(Icons.done, size: 14, color: grey);
      case MessageTick.read:
        return Icon(
          Icons.done_all,
          size: 15,
          color: onMineBubble ? const Color(0xFF4FC3F7) : AppColors.info,
        );
    }
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  const _DayChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat('dd MMM yyyy').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF4F6F8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.35)),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final Color accent;
  final String name;
  const _EmptyChat({required this.accent, required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 34, color: accent),
            ),
            const SizedBox(height: 16),
            Text(
              'Start conversation',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Say hello to $name.\nLong-press a message to see sent / read info.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  final String message;
  final Color accent;
  final VoidCallback onRetry;
  const _ChatError({
    required this.message,
    required this.accent,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 42, color: accent.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              'Unable to open chat',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  ChatNav.openInbox(context);
                }
              },
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inbox — buyer & manufacturer Messages tab.
class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final accent = _accentFor(context);
    final accentLight = _accentLightFor(context);
    final isMfr = context.watch<AuthProvider>().role == UserRole.manufacturer;

    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<ChatThread>>(
        initialData: ChatService.instance.cachedInbox(me.id),
        stream: ChatService.instance.watchInbox(me.id),
        builder: (context, snap) {
          // Never stick on a spinner — show cache / empty / history immediately.
          final threads = snap.data ??
              ChatService.instance.cachedInbox(me.id) ??
              const <ChatThread>[];
          if (threads.isEmpty) {
            return _EmptyInbox(isManufacturer: isMfr, accent: accent);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = threads[i];
              final other = t.otherId(me.id);
              final title = t.titleFor(me.id);
              final subtitle = t.subtitleFor(me.id);
              final unread = t.unreadFor(me.id);
              final peerTyping = t.isTyping(other);
              final preview = peerTyping
                  ? 'typing…'
                  : (t.lastMessage?.trim().isNotEmpty == true
                      ? t.lastMessage!
                      : 'No messages yet');
              final mineLast = t.lastSenderId == me.id;
              final role = t.roles[other] ?? '';
              return AppCard(
                padding: EdgeInsets.zero,
                onTap: () => ChatNav.openRoom(context, other),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: accentLight,
                            child: Text(
                              title.isNotEmpty ? title[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _shortDate(t.updatedAt),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: unread > 0 ? accent : AppColors.textSecondary,
                                    fontWeight:
                                        unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                subtitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ] else if (role.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                role == 'manufacturer' ? 'Seller' : 'Buyer',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (mineLast && !peerTyping)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.done,
                                      size: 14,
                                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    peerTyping
                                        ? 'typing…'
                                        : (mineLast ? 'You: $preview' : preview),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: peerTyping
                                          ? accent
                                          : (unread > 0
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary),
                                      fontWeight: peerTyping || unread > 0
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontStyle: peerTyping
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                if (unread > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _shortDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return DateFormat('hh:mm a').format(d);
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(d).inDays < 7) return DateFormat('EEE').format(d);
    return DateFormat('dd MMM').format(d);
  }
}

class _EmptyInbox extends StatelessWidget {
  final bool isManufacturer;
  final Color accent;
  const _EmptyInbox({required this.isManufacturer, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_outlined, size: 38, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              'No chat history',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isManufacturer
                  ? 'Jab buyer message karega, yahan purani chats dikhengi.'
                  : 'Manufacturer se chat start karo — history yahan dikhegi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: isManufacturer ? 'View enquiries' : 'Find manufacturers',
              color: accent,
              onPressed: () {
                if (isManufacturer) {
                  context.go('/manufacturer/enquiries');
                } else {
                  context.push('/buyer/find-manufacturer');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
