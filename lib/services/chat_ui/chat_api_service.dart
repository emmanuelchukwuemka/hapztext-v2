import 'dart:async';
import 'dart:io';
import 'package:haptext_api/models/chat_ui/chat_item.dart';
import 'package:haptext_api/models/chat_ui/message.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatApiService {
  final HapzTextApiService _apiService;
  RealtimeChannel? _channel;
  StreamController<Message>? _messageController;
  Stream<Message>? _messageStream;
  Stream<Map<String, dynamic>>? _typingStream;
  Stream<Map<String, dynamic>>? _readReceiptStream;

  ChatApiService(this._apiService);

  // Expose the streams
  Stream<Message>? get messageStream => _messageStream;
  Stream<Map<String, dynamic>>? get typingStream => _typingStream;
  Stream<Map<String, dynamic>>? get readReceiptStream => _readReceiptStream;

  void connectToWebSocket(String conversationId) {
    disconnectWebSocket(); // Close any existing connection

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }

      _messageController = StreamController<Message>.broadcast();
      _messageStream = _messageController!.stream;

      _channel = client.channel('chat:$conversationId');
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          final record = payload.newRecord;
          if (record == null) return;
          final msg = _mapDbMessageToMessage(record, currentUserId: user.id);
          _messageController?.add(msg);
        },
      );
      _channel!.subscribe();
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  // Send Typing Indicator
  void sendTyping(bool isTyping) {}

  // Mark messages as read via API
  Future<bool> markMessagesAsRead(
      String conversationId, List<String> messageIds) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;
      await client
          .from('messages')
          .update({'status': 'read'})
          .inFilter('id', messageIds)
          .eq('conversation_id', conversationId);
      return true;
    } catch (e) {
      print('Error marking read: $e');
      return false;
    }
  }

  void disconnectWebSocket() {
    _messageController?.close();
    _messageController = null;
    if (_channel != null) {
      _channel!.unsubscribe();
      _channel = null;
    }
  }

  // Send Read Receipt via WS
  void sendReadReceipts(List<String> messageIds) {}

  Message _mapDbMessageToMessage(Map<String, dynamic> record,
      {required String currentUserId}) {
    final senderId = record['sender_id']?.toString();
    final bool me = senderId != null && senderId == currentUserId;

    final messageType = record['message_type']?.toString() ?? 'text';
    final mediaUrl = record['media_url']?.toString();

    return Message(
      id: record['id']?.toString() ?? DateTime.now().toIso8601String(),
      text: record['text_content']?.toString() ?? '',
      me: me,
      timestamp: DateTime.tryParse(record['created_at']?.toString() ?? '') ??
          DateTime.now(),
      viewed: record['status']?.toString() == 'read',
      isVoice: messageType == 'audio',
      audioPath: messageType == 'audio' ? mediaUrl : null,
      isImage: messageType == 'image',
      imageUrl: messageType == 'image' ? mediaUrl : null,
      isVideo: messageType == 'video',
      videoUrl: messageType == 'video' ? mediaUrl : null,
      isReply: record['is_reply'] == true,
      previousMessageId: record['previous_message_id']?.toString(),
      previousMessageContent: record['previous_message_content']?.toString(),
      previousMessageSenderId: record['previous_message_sender_id']?.toString(),
    );
  }

  // Convert API message data to Message objects
  List<Message> convertApiMessagesToMessages(dynamic messagesData) {
    List<Message> messages = [];

    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return messages;

    if (messagesData is List) {
      for (final record in messagesData) {
        if (record is Map<String, dynamic>) {
          messages.add(
              _mapDbMessageToMessage(record, currentUserId: currentUserId));
        }
      }
    }

    return messages;
  }

  // Send a message (Text or Media)
  Future<bool> sendMessage(String conversationId, String text,
      {File? file,
      String messageType = 'text',
      bool isReply = false,
      String? previousMessageId}) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      String? mediaUrl;
      if (file != null) {
        final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
        final ext = file.path.contains('.')
            ? file.path.substring(file.path.lastIndexOf('.'))
            : '';
        final path =
            '${user.id}/chat/${conversationId}/${DateTime.now().millisecondsSinceEpoch}$ext';
        await client.storage.from('chat_media').upload(
              path,
              file,
              fileOptions: FileOptions(upsert: true, contentType: mime),
            );
        mediaUrl = client.storage.from('chat_media').getPublicUrl(path);
      }

      await client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'message_type': messageType,
        'text_content': text,
        'media_url': mediaUrl,
        'is_reply': isReply,
        'previous_message_id': previousMessageId,
        'status': 'sent',
      });

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get messages for a conversation
  Future<List<Message>> getConversationMessages(String conversationId) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return [];
      final rows = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(50);
      return convertApiMessagesToMessages(rows);
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // Get conversations list (Optional, if needed for a list screen)
  Future<List<ChatItem>> getConversations() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return [];

      final participantRows = await client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', user.id);

      final conversationIds = participantRows
          .map((e) => e['conversation_id']?.toString())
          .whereType<String>()
          .toList();

      final chats = <ChatItem>[];
      for (final conversationId in conversationIds) {
        final last = await client
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(1);

        final lastMsgText = last.isNotEmpty
            ? (last.first['text_content']?.toString() ?? '')
            : '';

        final unreadRows = await client
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId)
            .neq('sender_id', user.id)
            .neq('status', 'read');
        final unreadCount = unreadRows.length;

        chats.add(ChatItem(
          id: conversationId,
          name: 'Chat ${conversationId.substring(0, 4)}',
          lastMessage: lastMsgText,
          unread: unreadCount,
        ));
      }

      return chats;
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  // Deprecated/Legacy adapters to keep code compiling if needed,
  // but we should update usage in ChatScreen.
  Future<List<Message>> getRecentPostsAsMessages() async {
    // This logic is flawed for a chat app, returning empty or trying to fetch from a default conversation if possible
    return [];
  }

  Future<bool> sendMessageAsPost(String text) async {
    return false;
  }
}
