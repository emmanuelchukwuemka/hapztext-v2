import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HapzTextApiService {
  static const String baseUrl = '';
  String? _token;
  String? currentUserId;

  String? get token => _token;

  // Set the authentication token
  void setToken(String token) {
    _token = token;
  }

  // Get headers with authorization
  Map<String, String> get _headers {
    return const {'Content-Type': 'application/json'};
  }

  // Test API connectivity
  Future<bool> testConnection() async {
    return true;
  }

  // --- Chat API Endpoints ---

  // 1. Create Conversation
  Future<Map<String, dynamic>?> createConversation(
      List<String> participantIds) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final ids = participantIds.map((e) => e.toString()).toSet().toList();
      if (!ids.contains(user.id)) {
        ids.add(user.id);
      }

      final conversation = await client
          .from('conversations')
          .insert({'created_by': user.id})
          .select()
          .single();
      final conversationId = conversation['id'].toString();

      for (final id in ids) {
        await client.from('conversation_participants').upsert({
          'conversation_id': conversationId,
          'user_id': id,
        });
      }

      return {
        'success': true,
        'data': {'id': conversationId}
      };
    } catch (e) {
      print('Error creating conversation: $e');
      return null;
    }
  }

  // 2. Get Conversations List
  Future<Map<String, dynamic>?> getConversations(int page, int pageSize) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final participantRows = await client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', user.id);

      final conversationIds = participantRows
          .map((e) => e['conversation_id']?.toString())
          .whereType<String>()
          .toList();

      final result = <Map<String, dynamic>>[];
      for (final conversationId in conversationIds) {
        final participantsRows = await client
            .from('conversation_participants')
            .select('user_id')
            .eq('conversation_id', conversationId);
        final participantIds = participantsRows
            .map((e) => e['user_id']?.toString())
            .whereType<String>()
            .toList();

        final profiles = participantIds.isEmpty
            ? <dynamic>[]
            : await client
                .from('profiles')
                .select('user_id, username')
                .inFilter('user_id', participantIds);

        final participants = profiles
            .map((p) => {
                  'id': p['user_id']?.toString(),
                  'username': p['username']?.toString(),
                })
            .toList();

        final lastMessages = await client
            .from('messages')
            .select(
                'id, text_content, created_at, sender_id, message_type, media_url, status')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(1);

        final lastMessage = lastMessages.isNotEmpty ? lastMessages.first : null;

        result.add({
          'id': conversationId,
          'participants': participants,
          'last_message': lastMessage,
        });
      }

      return {
        'data': {'result': result}
      };
    } catch (e) {
      print('Error getting conversations: $e');
      return null;
    }
  }

  // 3. Send Message
  Future<Map<String, dynamic>?> sendMessage(String conversationId, String text,
      {String type = 'text',
      String? mediaUrl,
      bool isReply = false,
      String? previousMessageId}) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final inserted = await client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': user.id,
            'message_type': type,
            'text_content': text,
            'media_url': mediaUrl,
            'is_reply': isReply,
            'previous_message_id': previousMessageId,
            'status': 'sent',
          })
          .select()
          .single();

      return {'success': true, 'data': inserted};
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // 4. Get Conversation Messages
  Future<Map<String, dynamic>?> getMessages(
      String conversationId, int page, int pageSize) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final rows = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(from, to);

      return {
        'data': {'result': rows}
      };
    } catch (e) {
      print('Error getting messages: $e');
      return null;
    }
  }

  // 5. Mark Messages as Read
  Future<bool> markMessagesRead(
      String conversationId, List<String> messageIds) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      await client
          .from('messages')
          .update({'status': 'read'})
          .eq('conversation_id', conversationId)
          .inFilter('id', messageIds);
      return true;
    } catch (e) {
      print('Error marking messages read: $e');
      return false;
    }
  }

  // 6. Upload Media
  Future<Map<String, dynamic>?> uploadMedia(
      File file, String messageType) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
      final ext = file.path.contains('.')
          ? file.path.substring(file.path.lastIndexOf('.'))
          : '';
      final path =
          '${user.id}/chat/${DateTime.now().millisecondsSinceEpoch}$ext';

      await client.storage.from('chat_media').upload(
            path,
            file,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );

      final url = client.storage.from('chat_media').getPublicUrl(path);
      return {
        'success': true,
        'data': {'media_url': url}
      };
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  // --- End Chat API Endpoints ---

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (profile == null) return null;
      return {'data': profile};
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Register a new user
  Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      await client.auth.signInWithPassword(email: email, password: password);

      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) return null;

      await client.from('profiles').upsert({
        'user_id': user.id,
        'email': email,
        'username': username,
      });

      _token = session.accessToken;
      currentUserId = user.id;

      return {
        'success': true,
        'data': {
          'access_token': session.accessToken,
          'user': {'id': user.id}
        }
      };
    } catch (e) {
      print('Error registering user: $e');
      return null;
    }
  }

  // Login user
  Future<Map<String, dynamic>?> loginUser({
    required String username,
    required String password,
  }) async {
    try {
      final client = Supabase.instance.client;
      String email = username;
      if (!email.contains('@')) {
        final profile = await client
            .from('profiles')
            .select('email')
            .eq('username', username)
            .maybeSingle();
        final profileEmail = profile?['email']?.toString();
        if (profileEmail == null || profileEmail.isEmpty) {
          return null;
        }
        email = profileEmail;
      }

      await client.auth.signInWithPassword(email: email, password: password);

      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      if (session == null || user == null) return null;

      _token = session.accessToken;
      currentUserId = user.id;

      return {
        'success': true,
        'data': {
          'access_token': session.accessToken,
          'user': {'id': user.id}
        }
      };
    } catch (e) {
      print('Error logging in user: $e');
      return null;
    }
  }
}
