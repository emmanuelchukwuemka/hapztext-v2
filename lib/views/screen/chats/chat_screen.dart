import 'package:haptext_api/exports.dart';
import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';

// Paste this into lib/main.dart (or DartPad Flutter) and run.
// Full chat UI with injected Chat Mode Options (single file)

enum ChatMode { mixed, textOnly, voiceOnly, callsOnly }

enum DisappearOption { off, fiveSeconds, day24h, week7d }

// Helper label for ChatMode (top-level so it can be reused)
String modeLabel(ChatMode m) {
  switch (m) {
    case ChatMode.textOnly:
      return 'Text Only';
    case ChatMode.voiceOnly:
      return 'Voice Notes Only';
    case ChatMode.callsOnly:
      return 'Calls Only';
    default:
      return 'Mixed';
  }
}

/* -----------------------
   Models (in-memory only)
   -----------------------*/

class ChatItem {
  final String id;
  final String name;
  String lastMessage;
  int unread;
  ChatMode chatMode;
  bool pinned;
  bool muted;
  DisappearOption disappearing;
  bool autoClearEnabled;
  TimeOfDay? autoClearStart;
  TimeOfDay? autoClearEnd;
  int themeIndex; // 0 default, 1 blue, 2 purple, 3 green
  String notificationTone;

  ChatItem({
    required this.id,
    required this.name,
    this.lastMessage = '',
    this.unread = 0,
    this.chatMode = ChatMode.mixed,
    this.pinned = false,
    this.muted = false,
    this.disappearing = DisappearOption.off,
    this.autoClearEnabled = false,
    this.autoClearStart,
    this.autoClearEnd,
    this.themeIndex = 0,
    this.notificationTone = 'Default',
  });

  ChatItem copyWith({
    String? lastMessage,
    int? unread,
    ChatMode? chatMode,
    bool? pinned,
    bool? muted,
    DisappearOption? disappearing,
    bool? autoClearEnabled,
    TimeOfDay? autoClearStart,
    TimeOfDay? autoClearEnd,
    int? themeIndex,
    String? notificationTone,
  }) {
    return ChatItem(
      id: id,
      name: name,
      lastMessage: lastMessage ?? this.lastMessage,
      unread: unread ?? this.unread,
      chatMode: chatMode ?? this.chatMode,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      disappearing: disappearing ?? this.disappearing,
      autoClearEnabled: autoClearEnabled ?? this.autoClearEnabled,
      autoClearStart: autoClearStart ?? this.autoClearStart,
      autoClearEnd: autoClearEnd ?? this.autoClearEnd,
      themeIndex: themeIndex ?? this.themeIndex,
      notificationTone: notificationTone ?? this.notificationTone,
    );
  }
}

class Message {
  final String id;
  final String text;
  final bool me;
  final bool isVoice;
  final DateTime timestamp;
  bool viewOnce; // auto-clear after being viewed once
  bool viewed;
  bool isFeedLink; // in-chat feed notification example
  bool disappearing; // set when disappearing messages active (demo)
  Message({
    required this.id,
    required this.text,
    required this.me,
    this.isVoice = false,
    required this.timestamp,
    this.viewOnce = false,
    this.viewed = false,
    this.isFeedLink = false,
    this.disappearing = false,
  });
}

/* -----------------------
   Sample Data
   -----------------------*/

List<ChatItem> initialChats() {
  return [];
}

/* -----------------------
   Chats Home (pinned + list)
   -----------------------*/

class ChatsHome extends StatefulWidget {
  const ChatsHome({super.key});
  @override
  State<ChatsHome> createState() => _ChatsHomeState();
}

class _ChatsHomeState extends State<ChatsHome> {
  List<ChatItem> chats = [];
  bool pinnedExpanded = true;
  bool isLoading = false;
  final HapzTextApiService _apiService = HapzTextApiService();

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => isLoading = true);
    final token = context.read<AuthCubit>().useInfo.tokens?.auth;
    if (token != null) {
      _apiService.setToken(token);
      final result = await _apiService.getConversations(1, 20);
      if (result != null &&
          result['data'] != null &&
          result['data']['result'] != null) {
        setState(() {
          chats = (result['data']['result'] as List).map((c) {
            // Map API response to ChatItem model
            // The API return might have different field names, adjusting accordingly
            final participants = c['participants'] as List;
            final otherUser = participants.firstWhere(
              (p) => p['id'] != context.read<AuthCubit>().useInfo.id,
              orElse: () => participants.first,
            );

            return ChatItem(
              id: c['id'].toString(),
              name: otherUser['username'] ?? 'User',
              lastMessage: c['last_message'] != null
                  ? c['last_message']['text_content'] ?? ''
                  : '',
              unread:
                  0, // Backend might not provide unread count in this endpoint
              chatMode: ChatMode.mixed,
            );
          }).toList();
        });
      }
    }
    setState(() => isLoading = false);
  }

  void openChat(ChatItem chat) async {
    final result = await Navigator.of(context).push<ChatItem>(
      MaterialPageRoute(
          builder: (_) => ChatScreen(chat: chat, apiService: _apiService)),
    );
    if (result != null) {
      _loadConversations(); // Refresh list on return
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinned = chats.where((c) => c.pinned).toList();
    final normal = chats.where((c) => !c.pinned).toList();

    return Scaffold(
      appBar: AppBar(
          title: const AppText(
              text: 'Chats',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            const SizedBox(width: 6)
          ]),
      body: Column(children: [
        // Pinned bar
        GestureDetector(
          onTap: () => setState(() => pinnedExpanded = !pinnedExpanded),
          child: AnimatedContainer(
            padding: const EdgeInsets.all(12),
            duration: const Duration(milliseconds: 250),
            height: pinnedExpanded ? 120 : 56,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const AppText(
                    text: 'Pinned',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                const Spacer(),
                Icon(pinnedExpanded ? Icons.expand_less : Icons.expand_more)
              ]),
              const SizedBox(height: 8),
              if (pinnedExpanded)
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pinned.length,
                    separatorBuilder: (BuildContext context, _) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final p = pinned[i];
                      return GestureDetector(
                        onTap: () => openChat(p),
                        child: Container(
                          width: 160,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10)),
                          child: Row(children: [
                            CircleAvatar(radius: 26, child: Text(p.name[0])),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                  AppText(
                                      text: p.name,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                  const SizedBox(height: 6),
                                  AppText(
                                      text: p.lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      color: Colors.white70,
                                      fontSize: 12)
                                ])),
                          ]),
                        ),
                      );
                    },
                  ),
                )
              else
                const SizedBox()
            ]),
          ),
        ),

        const Divider(height: 1, color: Colors.white12),

        // Chat list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (BuildContext context, _) =>
                const Divider(height: 1, color: Colors.white12),
            itemCount: normal.length,
            itemBuilder: (context, idx) {
              final c = normal[idx];
              return ListTile(
                onTap: () => openChat(c),
                leading: Stack(children: [
                  CircleAvatar(radius: 26, child: Text(c.name[0])),
                  if (c.chatMode != ChatMode.mixed)
                    Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: _modeColor(c.chatMode),
                                shape: BoxShape.circle),
                            child: Icon(_modeIcon(c.chatMode),
                                size: 12, color: Colors.white))),
                ]),
                title: Row(children: [
                  Expanded(
                      child: AppText(
                          text: c.name,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ]),
                subtitle: AppText(
                    text: c.lastMessage,
                    color: Colors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (c.unread > 0)
                    Badge.count(
                        count: c.unread,
                        textColor: Colors.white,
                        backgroundColor: Colors.red),
                  const AppText(
                      text: 'Now', color: Colors.white54, fontSize: 12),
                  if (c.muted)
                    const Icon(Icons.notifications_off,
                        size: 14, color: Colors.white30)
                ]),
              );
            },
          ),
        )
      ]),
    );
  }

  static Color _modeColor(ChatMode m) {
    switch (m) {
      case ChatMode.textOnly:
        return Colors.orange;
      case ChatMode.voiceOnly:
        return Colors.purpleAccent;
      case ChatMode.callsOnly:
        return Colors.greenAccent;
      default:
        return Colors.transparent;
    }
  }

  static IconData _modeIcon(ChatMode m) {
    switch (m) {
      case ChatMode.textOnly:
        return Icons.text_fields;
      case ChatMode.voiceOnly:
        return Icons.mic;
      case ChatMode.callsOnly:
        return Icons.call;
      default:
        return Icons.chat_bubble;
    }
  }
}

/* -----------------------
   Chat Screen (full)
   -----------------------*/

class ChatScreen extends StatefulWidget {
  final ChatItem chat;
  final HapzTextApiService apiService;
  const ChatScreen({super.key, required this.chat, required this.apiService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatItem chat;
  final List<Message> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool recordingMock = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => isLoading = true);
    final result = await widget.apiService.getMessages(chat.id, 1, 50);
    if (result != null &&
        result['data'] != null &&
        result['data']['result'] != null) {
      setState(() {
        messages.clear();
        messages.addAll((result['data']['result'] as List).map((m) {
          return Message(
            id: m['id'].toString(),
            text: m['text_content'] ?? '',
            me: m['sender_id'] == context.read<AuthCubit>().useInfo.id,
            timestamp: DateTime.parse(m['created_at']),
            isVoice: m['message_type'] == 'voice',
          );
        }));
      });
    }
    setState(() => isLoading = false);
  }

  // Helpers: check if current time is within auto-clear window
  bool _isWithinAutoClearWindow() {
    if (!chat.autoClearEnabled ||
        chat.autoClearStart == null ||
        chat.autoClearEnd == null) return false;
    final now = TimeOfDay.now();
    final start = chat.autoClearStart!;
    final end = chat.autoClearEnd!;
    final nowMinutes = now.hour * 60 + now.minute;
    final startM = start.hour * 60 + start.minute;
    final endM = end.hour * 60 + end.minute;
    if (startM <= endM) {
      return nowMinutes >= startM && nowMinutes <= endM;
    } else {
      // window crosses midnight
      return nowMinutes >= startM || nowMinutes <= endM;
    }
  }

  Future<void> _sendText() async {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;

    final result = await widget.apiService.sendMessage(chat.id, txt);
    if (result != null && result['data'] != null) {
      final m = result['data'];
      setState(() {
        messages.insert(
            0,
            Message(
              id: m['id'].toString(),
              text: m['text_content'] ?? '',
              me: true,
              timestamp: DateTime.parse(m['created_at']),
            ));
        chat.lastMessage = 'You: $txt';
        _controller.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')));
    }
  }

  void _toggleRecord() {
    if (recordingMock) {
      _stopAndSendRecord();
    } else {
      _startRecord();
    }
  }

  void _startRecord() {
    setState(() {
      recordingMock = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Recording started')));
  }

  Future<void> _stopAndSendRecord() async {
    _recordTimer?.cancel();
    // TODO: Implement actual voice note recording and uploading
    final msgText = 'Voice note (${_formatDuration(_recordDuration)})';

    setState(() {
      recordingMock = false;
      // We keep the optimistic UI update but without "(demo)" context
      messages.insert(
          0,
          Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: msgText,
            me: true,
            isVoice: true,
            timestamp: DateTime.now(),
          ));
      chat.lastMessage = 'You: $msgText';
    });
  }

  void _cancelRecord() {
    _recordTimer?.cancel();
    setState(() {
      recordingMock = false;
      _recordDuration = Duration.zero;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Recording cancelled')));
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _openProfilePanel() async {
    final updated = await showModalBottomSheet<ChatItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ProfilePanel(chat: chat)),
      ),
    );
    if (updated != null) {
      setState(() => chat = updated);
    }
  }

  void _onTapMessage(Message m) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Open feed link: ${m.text}')));
    if (m.viewOnce && !m.viewed) {
      // show content then remove (simulate)
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          content: Text(m.text),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      ).then((_) {
        setState(() {
          m.viewed = true;
          messages.removeWhere((x) => x.id == m.id);
        });
      });
      return;
    }

    if (m.isVoice) {
      // TODO: Implement actual voice playback
      return;
    }

    // open menu: react / reply / delete
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Reply'),
            onTap: () => Navigator.pop(context)),
        ListTile(
            leading: const Icon(Icons.emoji_emotions),
            title: const Text('React'),
            onTap: () => Navigator.pop(context)),
        ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              setState(() => messages.removeWhere((x) => x.id == m.id));
              Navigator.pop(context);
            }),
      ]),
    );
  }

  Color _bubbleColor(bool me) {
    switch (chat.themeIndex) {
      case 1:
        return me ? Colors.blueAccent : Colors.blueGrey.shade800;
      case 2:
        return me ? Colors.purple : Colors.deepPurple.shade700;
      case 3:
        return me ? Colors.greenAccent : Colors.green.shade900;
      default:
        return me ? Colors.teal : Colors.grey.shade800;
    }
  }

  BoxDecoration _backgroundDecoration() {
    switch (chat.themeIndex) {
      case 1:
        return BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.blueGrey.shade900, Colors.blue.shade700]));
      case 2:
        return BoxDecoration(
            gradient: LinearGradient(colors: [
          Colors.deepPurple.shade900,
          Colors.purpleAccent.shade200
        ]));
      case 3:
        return const BoxDecoration(color: Colors.black87);
      default:
        return const BoxDecoration(color: Colors.black);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSendText =
        chat.chatMode == ChatMode.mixed || chat.chatMode == ChatMode.textOnly;
    final canSendVoice =
        chat.chatMode == ChatMode.mixed || chat.chatMode == ChatMode.voiceOnly;
    final callsOnly = chat.chatMode == ChatMode.callsOnly;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Row(children: [
          CircleAvatar(radius: 18, child: Text(chat.name[0])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(chat.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(modeLabel(chat.chatMode),
                style: const TextStyle(color: Colors.white70, fontSize: 12))
          ])
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.video_call),
              onPressed: () {
                context.push(RouteName.videoCallPage.path);
              }),
          IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () {
                context.push(RouteName.voiceCallPage.path);
              }),
          IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _openProfilePanel)
        ],
      ),
      body: Container(
        decoration: _backgroundDecoration(),
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, idx) {
                final m = messages[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment:
                        m.me ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => _onTapMessage(m),
                      child: Column(
                          crossAxisAlignment: m.me
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.72),
                              padding: EdgeInsets.symmetric(
                                  horizontal: m.isVoice ? 12 : 14,
                                  vertical: m.isVoice ? 10 : 12),
                              decoration: BoxDecoration(
                                  color: _bubbleColor(m.me),
                                  borderRadius: BorderRadius.circular(12)),
                              child: m.isVoice
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                          const Icon(Icons.play_arrow,
                                              color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(m.text,
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                          const SizedBox(width: 8),
                                          Text(_formatTime(m.timestamp),
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11))
                                        ])
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          Row(children: [
                                            Expanded(
                                                child: Text(m.text,
                                                    style: const TextStyle(
                                                        color: Colors.white))),
                                            if (m.disappearing)
                                              const Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 6),
                                                  child: Icon(Icons.timer,
                                                      size: 14,
                                                      color: Colors.white70))
                                          ]),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            Text(_formatTime(m.timestamp),
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 11)),
                                            const SizedBox(width: 8),
                                            if (m.viewOnce)
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                      color: Colors.orange
                                                          .withOpacity(0.9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                  child: const Text('View-once',
                                                      style: TextStyle(
                                                          fontSize: 11)))
                                          ]),
                                        ]),
                            ),
                            if (m.isFeedLink)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: GestureDetector(
                                  onTap: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(
                                              'Open feed post: ${m.text}'))),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Text('Open post in feed →',
                                          style: TextStyle(
                                              color: Colors.white70))),
                                ),
                              ),
                          ]),
                    ),
                  ),
                );
              },
            ),
          ),

          // Calls-only quick UI
          if (callsOnly)
            Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[900],
                child: Row(children: [
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call),
                          label: const Text('Audio Call'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.videocam),
                          label: const Text('Video Call')))
                ])),

          // Input area
          if (!callsOnly)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  GestureDetector(
                    onLongPressDown: (_) {
                      if (canSendVoice && !recordingMock) {
                        _startRecord();
                      }
                    },
                    onLongPressEnd: (_) {
                      if (recordingMock) {
                        _stopAndSendRecord();
                      }
                    },
                    onLongPressCancel: () {
                      if (recordingMock) {
                        _cancelRecord();
                      }
                    },
                    child: Icon(recordingMock ? Icons.stop_circle : Icons.mic,
                        color: recordingMock ? Colors.red : Colors.white),
                  ),
                  Expanded(
                    child: recordingMock
                        ? Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: Colors.red, size: 12),
                                const SizedBox(width: 8),
                                Text(_formatDuration(_recordDuration),
                                    style:
                                        const TextStyle(color: Colors.white)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _cancelRecord,
                                  child: const Text("Cancel",
                                      style:
                                          TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: _controller,
                            enabled: canSendText,
                            decoration: InputDecoration(
                                hintText: canSendText
                                    ? (chat.autoClearEnabled
                                        ? 'Message (auto-clear active)'
                                        : 'Message')
                                    : 'Text disabled by mode',
                                filled: true,
                                fillColor: Colors.white12,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12)),
                            onSubmitted: (v) {},
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: recordingMock
                          ? _stopAndSendRecord
                          : (canSendText ? _sendText : null)),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'toggleViewOnce') {
                          setState(() {
                            chat.autoClearEnabled = !chat.autoClearEnabled;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(chat.autoClearEnabled
                                  ? 'Auto-clear (view-once) enabled'
                                  : 'Auto-clear disabled')));
                        } else if (v == 'setTimer') {
                          _pickAutoClearWindow();
                        }
                      },
                      itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'toggleViewOnce',
                                child: Text(chat.autoClearEnabled
                                    ? 'Stop auto-clear window'
                                    : 'Start auto-clear window')),
                            const PopupMenuItem(
                                value: 'setTimer',
                                child: Text('Set auto-clear window')),
                          ]),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _pickAutoClearWindow() async {
    final start =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (start == null) return;
    final end = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute));
    if (end == null) return;
    setState(() {
      chat.autoClearStart = start;
      chat.autoClearEnd = end;
      chat.autoClearEnabled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Auto-clear window set: ${start.format(context)} → ${end.format(context)}')));
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/* -----------------------
   Profile Panel (inject settings + Chat Mode Options)
   -----------------------*/

class ProfilePanel extends StatefulWidget {
  final ChatItem chat;
  const ProfilePanel({super.key, required this.chat});
  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel> {
  late ChatItem editing;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    editing = widget.chat;
  }

  void _pickDisappearing() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            title: const Text('Off'),
            onTap: () => Navigator.pop(context, DisappearOption.off)),
        ListTile(
            title: const Text('5 seconds'),
            onTap: () => Navigator.pop(context, DisappearOption.fiveSeconds)),
        ListTile(
            title: const Text('24 hours'),
            onTap: () => Navigator.pop(context, DisappearOption.day24h)),
        ListTile(
            title: const Text('7 days'),
            onTap: () => Navigator.pop(context, DisappearOption.week7d)),
      ]),
    ).then((value) {
      if (value != null && value is DisappearOption) {
        setState(() => editing = editing.copyWith(disappearing: value));
      }
    });
  }

  void _pickTheme() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            title: const Text('Default (Dark)'),
            onTap: () => Navigator.pop(context, 0)),
        ListTile(
            title: const Text('Blue gradient'),
            onTap: () => Navigator.pop(context, 1)),
        ListTile(
            title: const Text('Purple neon'),
            onTap: () => Navigator.pop(context, 2)),
        ListTile(
            title: const Text('Green dark'),
            onTap: () => Navigator.pop(context, 3)),
      ]),
    ).then((value) {
      if (value != null && value is int)
        setState(() => editing = editing.copyWith(themeIndex: value));
    });
  }

  void _pickNotificationTone() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            title: const Text('Default'),
            onTap: () => Navigator.pop(context, 'Default')),
        ListTile(
            title: const Text('Chime'),
            onTap: () => Navigator.pop(context, 'Chime')),
        ListTile(
            title: const Text('Bell'),
            onTap: () => Navigator.pop(context, 'Bell')),
        ListTile(
            title: const Text('Song A'),
            onTap: () => Navigator.pop(context, 'Song A')),
      ]),
    ).then((value) {
      if (value != null && value is String)
        setState(() => editing = editing.copyWith(notificationTone: value));
    });
  }

  void _pickAutoClearWindow() async {
    final start =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (start == null) return;
    final end = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute));
    if (end == null) return;
    setState(() {
      editing = editing.copyWith(
          autoClearEnabled: true, autoClearStart: start, autoClearEnd: end);
    });
  }

  void _pickChatMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Chat Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Mixed (All)'),
              subtitle: const Text('Text, voice notes & calls allowed'),
              trailing: editing.chatMode == ChatMode.mixed
                  ? const Icon(Icons.check, color: Colors.greenAccent)
                  : null,
              onTap: () => setState(
                  () => editing = editing.copyWith(chatMode: ChatMode.mixed)),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Text Only'),
              subtitle: const Text('Only text messages allowed'),
              trailing: editing.chatMode == ChatMode.textOnly
                  ? const Icon(Icons.check, color: Colors.greenAccent)
                  : null,
              onTap: () => setState(() =>
                  editing = editing.copyWith(chatMode: ChatMode.textOnly)),
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Voice Notes Only'),
              subtitle: const Text('Only voice notes allowed'),
              trailing: editing.chatMode == ChatMode.voiceOnly
                  ? const Icon(Icons.check, color: Colors.greenAccent)
                  : null,
              onTap: () => setState(() =>
                  editing = editing.copyWith(chatMode: ChatMode.voiceOnly)),
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Calls Only'),
              subtitle: const Text('Only audio/video calls allowed'),
              trailing: editing.chatMode == ChatMode.callsOnly
                  ? const Icon(Icons.check, color: Colors.greenAccent)
                  : null,
              onTap: () => setState(() =>
                  editing = editing.copyWith(chatMode: ChatMode.callsOnly)),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(children: [
                Expanded(
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))),
              ]),
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 30, child: Text(editing.name[0])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(editing.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Last seen recently',
                style: TextStyle(color: Colors.white54))
          ]),
          const Spacer(),
          IconButton(
              icon: Icon(
                  editing.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(
                  () => editing = editing.copyWith(pinned: !editing.pinned)))
        ]),
        const SizedBox(height: 12),

        // tabs (Media, Files, Voice, Settings)
        Row(children: [
          _tabPill(
              'Media', _tabIndex == 0, () => setState(() => _tabIndex = 0)),
          const SizedBox(width: 8),
          _tabPill(
              'Files', _tabIndex == 1, () => setState(() => _tabIndex = 1)),
          const SizedBox(width: 8),
          _tabPill(
              'Voice', _tabIndex == 2, () => setState(() => _tabIndex = 2)),
          const SizedBox(width: 8),
          _tabPill(
              'Settings', _tabIndex == 3, () => setState(() => _tabIndex = 3)),
        ]),
        const SizedBox(height: 12),

        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                padding: const EdgeInsets.all(8),
                children: [],
              ),

              ListView(padding: const EdgeInsets.all(8), children: []),

              ListView(padding: const EdgeInsets.all(8), children: []),

              // Settings (this includes Chat Mode)
              ListView(padding: const EdgeInsets.all(8), children: [
                ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Mute Notifications'),
                    trailing: Switch(
                        value: editing.muted,
                        onChanged: (v) => setState(
                            () => editing = editing.copyWith(muted: v)))),
                ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('Disappearing Messages'),
                    subtitle: Text(_disappearLabel(editing.disappearing)),
                    onTap: _pickDisappearing),
                ListTile(
                    leading: const Icon(Icons.visibility_off),
                    title: const Text('Auto-clear (view-once) window'),
                    subtitle: Text(editing.autoClearEnabled
                        ? 'Active: ${editing.autoClearStart?.format(context) ?? '—'} → ${editing.autoClearEnd?.format(context) ?? '—'}'
                        : 'Disabled'),
                    onTap: _pickAutoClearWindow),
                ListTile(
                    leading: const Icon(Icons.music_note),
                    title: const Text('Notification Tone'),
                    subtitle: Text(editing.notificationTone),
                    onTap: _pickNotificationTone),
                ListTile(
                    leading: const Icon(Icons.color_lens),
                    title: const Text('Chat Theme'),
                    subtitle: Text(_themeLabel(editing.themeIndex)),
                    onTap: _pickTheme),
                const Divider(),
                // ======= Chat Mode Option injected here =======
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Chat Mode Options'),
                  subtitle: Text(modeLabel(editing.chatMode)),
                  onTap: _pickChatMode,
                ),
                const Divider(),
                ListTile(
                    leading: const Icon(Icons.photo),
                    title: const Text('Media, Links & Docs'),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Media panel')))),
                ListTile(
                    leading: const Icon(Icons.block),
                    title: Text('Block ${editing.name}'),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Blocked ${editing.name}')))),
                const SizedBox(height: 12),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Expanded(
                          child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, editing),
                              child: const Text('Save'))),
                      const SizedBox(width: 12),
                      OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'))
                    ])),
                const SizedBox(height: 12),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _tabPill(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: active ? Colors.blueAccent : Colors.white12,
                borderRadius: BorderRadius.circular(30)),
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      );

  static String _disappearLabel(DisappearOption d) {
    switch (d) {
      case DisappearOption.off:
        return 'Off';
      case DisappearOption.fiveSeconds:
        return '5 seconds';
      case DisappearOption.day24h:
        return '24 hours';
      case DisappearOption.week7d:
        return '7 days';
    }
  }

  static String _themeLabel(int idx) {
    switch (idx) {
      case 1:
        return 'Blue gradient';
      case 2:
        return 'Purple neon';
      case 3:
        return 'Green dark';
      default:
        return 'Default (Dark)';
    }
  }
}
