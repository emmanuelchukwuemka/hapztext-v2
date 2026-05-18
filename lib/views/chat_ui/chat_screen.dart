import 'package:flutter/material.dart';
import 'package:haptext_api/models/chat_ui/chat_item.dart';
import 'package:haptext_api/models/chat_ui/message.dart';
import 'package:haptext_api/widgets/chat_ui/message_bubble.dart';
import 'package:haptext_api/widgets/chat_ui/input_area.dart';
import 'package:haptext_api/widgets/chat_ui/profile_panel.dart';
import 'package:haptext_api/utils/chat_ui/themes.dart';
import 'package:haptext_api/utils/chat_ui/enums.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:haptext_api/services/chat_ui/chat_api_service.dart';
import 'package:haptext_api/views/chat_ui/voice_call_screen.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';

// ... (existing imports, no change)

class ChatScreen extends StatefulWidget {
  final ChatItem chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatItem _chat;
  late List<Message> _messages;
  final HapzTextApiService _apiService = HapzTextApiService();
  late ChatApiService _chatApiService;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;
  StreamSubscription<Message>? _msgSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  String? _typingUser;
  Timer? _typingDebounce;
  Message? _replyMessage;

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _chatApiService = ChatApiService(_apiService);

    // Inject auth token
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUserToken != null) {
        _apiService.setToken(authProvider.currentUserToken!);
        _apiService.currentUserId = authProvider.currentUserId;

        // Connect to WebSocket
        _chatApiService.connectToWebSocket(_chat.id);

        // Listen for new messages
        if (_chatApiService.messageStream != null) {
          _msgSubscription =
              _chatApiService.messageStream!.listen((newMessage) {
            if (mounted) {
              setState(() {
                final existingIndex = _messages.indexWhere((m) =>
                    m.id == newMessage.id ||
                    (newMessage.me &&
                        m.id.startsWith('local_') &&
                        m.text == newMessage.text));
                if (existingIndex != -1) {
                  _messages[existingIndex] =
                      newMessage; // Update with server data
                } else {
                  _messages.add(newMessage);
                }
                _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              });
              _markAsRead([newMessage]);
            }
          });
        }

        // Listen for typing events
        if (_chatApiService.typingStream != null) {
          _typingSubscription = _chatApiService.typingStream!.listen((data) {
            if (mounted) {
              final isTyping = data['is_typing'] == true;
              final username = data['username'] ?? 'Someone';
              setState(() {
                _typingUser = isTyping ? "$username is typing..." : null;
              });
            }
          });
        }

        // Listen for read receipts
        if (_chatApiService.readReceiptStream != null) {
          _readSubscription = _chatApiService.readReceiptStream!.listen((data) {
            if (mounted) {
              final messageIds = List<String>.from(data['message_ids'] ?? []);
              setState(() {
                for (var msg in _messages) {
                  if (msg.me && messageIds.contains(msg.id)) {
                    // We can't update 'final' fields in Message directly if it's immutable
                    // Need to replace the message in the list
                    final index = _messages.indexOf(msg);
                    _messages[index] = msg.copyWith(viewed: true);
                  }
                }
              });
            }
          });
        }
      }

      // Load messages from API in the background
      _loadMessagesFromApi();
    });

    // Initialize with empty list and load from API
    _messages = [];
  }

  bool _isWithinAutoClearWindow() {
    if (!_chat.autoClearEnabled ||
        _chat.autoClearStart == null ||
        _chat.autoClearEnd == null) return false;
    final now = TimeOfDay.now();
    final start = _chat.autoClearStart!;
    final end = _chat.autoClearEnd!;
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

  // Load messages from the HapzText API
  Future<void> _loadMessagesFromApi() async {
    try {
      final apiMessages =
          await _chatApiService.getConversationMessages(_chat.id);
      if (mounted) {
        setState(() {
          // Replace dummy messages with API messages
          _messages = apiMessages;
          // Ensure chronological order (Oldest -> Newest) as ListView is reversed (Bottom=last=Newest)
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        _markAsRead(apiMessages);
      }
    } catch (e) {
      print('Error loading messages from API: $e');
    }
  }

  void _markAsRead(List<Message> messages) {
    final unreadFromOthers =
        messages.where((m) => !m.me && !m.viewed).map((m) => m.id).toList();

    if (unreadFromOthers.isNotEmpty) {
      _chatApiService.markMessagesAsRead(_chat.id, unreadFromOthers);
      _chatApiService.sendReadReceipts(unreadFromOthers);
      // Locally mark them as viewed to avoid re-triggering
      setState(() {
        for (var id in unreadFromOthers) {
          final index = _messages.indexWhere((m) => m.id == id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(viewed: true);
          }
        }
      });
    }
  }

  void _addMessage(Message message) {
    setState(() {
      _messages.add(message);
    });

    // If the message is from the current user, send it to the API
    if (message.me) {
      _sendMessageToApi(message);
    }

    if (_replyMessage != null) {
      setState(() {
        _replyMessage = null;
      });
    }

    if (message.disappearing) {
      // TODO: Handle disappearing messages on the server side
    }
  }

  // Send the message to the HapzText API
  Future<void> _sendMessageToApi(Message message) async {
    try {
      if (message.isVoice && message.audioPath != null) {
        await _chatApiService.sendMessage(
          _chat.id,
          message.text, // "Voice Note" usually
          file: File(message.audioPath!),
          messageType: 'audio',
          isReply: message.isReply,
          previousMessageId: message.previousMessageId,
        );
      } else {
        await _chatApiService.sendMessage(
          _chat.id,
          message.text,
          isReply: message.isReply,
          previousMessageId: message.previousMessageId,
        );
      }
    } catch (e) {
      print('Error sending message to API: $e');
      // Optionally show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
    _typingSubscription?.cancel();
    _readSubscription?.cancel();
    _typingDebounce?.cancel();
    _chatApiService.disconnectWebSocket();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppThemes.getThemeFromIndex(_chat.themeIndex),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_chat.name, style: const TextStyle(fontSize: 16)),
              Row(
                children: [
                  Icon(
                    _chat.chatMode.icon,
                    size: 14,
                    color: Colors.teal.shade200,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _chat.chatMode.label,
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade200),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () => _startVideoCall(),
              tooltip: 'Video Call',
            ),
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _startVoiceCall(),
              tooltip: 'Voice Call',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String result) {
                if (result == 'settings') {
                  _openProfilePanel();
                } else if (result.startsWith('mode_')) {
                  _quickChangeMode(result.split('_')[1]);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'mode_mixed',
                  child: Row(
                    children: [
                      Icon(ChatMode.mixed.icon, size: 18),
                      const SizedBox(width: 8),
                      const Text('Mixed Mode'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'mode_textOnly',
                  child: Row(
                    children: [
                      Icon(ChatMode.textOnly.icon, size: 18),
                      const SizedBox(width: 8),
                      const Text('Text Only'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'mode_voiceOnly',
                  child: Row(
                    children: [
                      Icon(ChatMode.voiceOnly.icon, size: 18),
                      const SizedBox(width: 8),
                      const Text('Voice Only'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'mode_callsOnly',
                  child: Row(
                    children: [
                      Icon(ChatMode.callsOnly.icon, size: 18),
                      const SizedBox(width: 8),
                      const Text('Calls Only'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 18),
                      SizedBox(width: 8),
                      Text('Chat Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppThemes.getBackgroundGradient(_chat.themeIndex),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  reverse: true, // New messages at bottom
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    return MessageBubble(
                      message: message,
                      themeIndex: _chat.themeIndex,
                      onTap: () => _handleMessageTap(message),
                      onReply: () {
                        setState(() {
                          _replyMessage = message;
                        });
                      },
                    );
                  },
                ),
              ),
              if (_typingUser != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _typingUser!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              InputArea(
                chatMode: _chat.chatMode,
                autoClearActive: _isWithinAutoClearWindow(),
                replyMessage: _replyMessage,
                onCancelReply: () {
                  setState(() {
                    _replyMessage = null;
                  });
                },
                onSendText: (text, {isEmoji = false}) {
                  _chatApiService
                      .sendTyping(false); // Stop typing immediately on send
                  final bool willViewOnce = _isWithinAutoClearWindow();
                  final bool willDisappear =
                      _chat.disappearing == DisappearingOption.fiveSeconds;
                  _addMessage(Message(
                    id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                    text: text,
                    me: true,
                    timestamp: DateTime.now(),
                    viewOnce: willViewOnce,
                    disappearing: willDisappear,
                    isEmoji: isEmoji,
                    isReply: _replyMessage != null,
                    previousMessageId: _replyMessage?.id,
                    previousMessageContent: _replyMessage?.text,
                    previousMessageSenderId:
                        _replyMessage?.me == true ? "You" : "Someone",
                  ));
                },
                onStartVoice: _startVoiceRecording,
                onStopVoice: _stopVoiceRecording,
                onChanged: _onTextChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMessageTap(Message message) {
    if (message.viewOnce && !message.viewed) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("View Once Message"),
          content:
              const Text("This message will disappear after you close it."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  final index = _messages.indexWhere((m) => m.id == message.id);
                  if (index != -1) {
                    _messages[index] = _messages[index].copyWith(viewed: true);
                  }
                });
              },
              child: const Text("View"),
            ),
          ],
        ),
      );
    } else if (message.isFeedLink) {
      // TODO: Implement navigation to Feed Post
    }
  }

  void _startVoiceCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          isVideoCall: false,
          channelName: _chat.id,
        ),
      ),
    );
  }

  void _startVideoCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          isVideoCall: true,
          channelName: _chat.id,
        ),
      ),
    );
  }

  void _quickChangeMode(String modeString) {
    ChatMode newMode;
    switch (modeString) {
      case 'mixed':
        newMode = ChatMode.mixed;
        break;
      case 'textOnly':
        newMode = ChatMode.textOnly;
        break;
      case 'voiceOnly':
        newMode = ChatMode.voiceOnly;
        break;
      case 'callsOnly':
        newMode = ChatMode.callsOnly;
        break;
      default:
        return;
    }

    setState(() {
      _chat = _chat.copyWith(chatMode: newMode);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔄 Chat mode changed to ${newMode.label}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startVoiceRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Microphone permission is required to record voice notes')),
          );
        }
        return;
      }

      if (await _audioRecorder.hasPermission()) {
        String? filePath;

        if (!kIsWeb) {
          final Directory appDir = await getApplicationDocumentsDirectory();
          filePath =
              '${appDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        _currentRecordingPath = filePath;

        await _audioRecorder.start(const RecordConfig(), path: filePath ?? '');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎙️ Recording...'),
              duration: Duration(hours: 1),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final String? path = await _audioRecorder.stop();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (path != null) {
        final bool willViewOnce = _isWithinAutoClearWindow();
        final bool willDisappear =
            _chat.disappearing == DisappearingOption.fiveSeconds;

        _addMessage(Message(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          text: "Voice Note",
          me: true,
          isVoice: true,
          timestamp: DateTime.now(),
          viewOnce: willViewOnce,
          disappearing: willDisappear,
          audioPath: path,
          isReply: _replyMessage != null,
          previousMessageId: _replyMessage?.id,
          previousMessageContent: _replyMessage?.isVoice == true
              ? "Voice Note"
              : _replyMessage?.text,
          previousMessageSenderId:
              _replyMessage?.me == true ? "You" : "Someone",
        ));
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _onTextChanged(String text) {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    _chatApiService.sendTyping(true);

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _chatApiService.sendTyping(false);
    });
  }

  void _openProfilePanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfilePanel(
        chat: _chat,
        onUpdate: (updatedChat) {
          setState(() => _chat = updatedChat);
        },
      ),
    ).then((_) {
      // Logic for when modal closes
    });
  }
}
