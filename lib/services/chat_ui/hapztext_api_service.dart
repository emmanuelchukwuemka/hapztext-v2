import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
class HapzTextApiService {
  static const String baseUrl = 'http://72.62.4.119:8005';
  String? _token;
  String? currentUserId;

  String? get token => _token;

  // Set the authentication token
  void setToken(String token) {
    _token = token;
  }

  // Get headers with authorization
  Map<String, String> get _headers {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Test API connectivity
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schema/'),
        headers: {'Accept': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error testing API connection: $e');
      return false;
    }
  }

  // --- Chat API Endpoints ---

  // 1. Create Conversation
  Future<Map<String, dynamic>?> createConversation(List<String> participantIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat/conversations/'),
        headers: _headers,
        body: json.encode({'participant_ids': participantIds}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to create conversation: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error creating conversation: $e');
      return null;
    }
  }

  // 2. Get Conversations List
  Future<Map<String, dynamic>?> getConversations(int page, int pageSize) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/chat/conversations/$page/$pageSize/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get conversations: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting conversations: $e');
      return null;
    }
  }

  // 3. Send Message
  Future<Map<String, dynamic>?> sendMessage(String conversationId, String text,
      {String type = 'text', String? mediaUrl, bool isReply = false, String? previousMessageId}) async {
    try {
      final Map<String, dynamic> body = {
        'message_type': type,
        'text_content': text,
        'is_reply': isReply,
      };

      if (mediaUrl != null) {
        body['media_url'] = mediaUrl;
      }

      if (isReply && previousMessageId != null) {
        body['previous_message_id'] = previousMessageId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat/conversations/$conversationId/messages/'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Failed to send message: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // 4. Get Conversation Messages
  Future<Map<String, dynamic>?> getMessages(String conversationId, int page, int pageSize) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/chat/conversations/$conversationId/messages/$page/$pageSize/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get messages: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting messages: $e');
      return null;
    }
  }

  // 5. Mark Messages as Read
  Future<bool> markMessagesRead(String conversationId, List<String> messageIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat/conversations/$conversationId/mark-read/'),
        headers: _headers,
        body: json.encode({'message_ids': messageIds}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking messages read: $e');
      return false;
    }
  }

  // 6. Upload Media
  Future<Map<String, dynamic>?> uploadMedia(File file, String messageType) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/chat/media/upload/'),
      );
      
      request.headers.addAll(_headers);
      request.headers.remove('Content-Type'); // Let multipart request set it

      request.fields['message_type'] = messageType;

      final detectedMime = lookupMimeType(file.path);
      String effectiveMime;
      if (detectedMime != null) {
        effectiveMime = detectedMime;
      } else {
        if (messageType == 'audio') {
          effectiveMime = 'audio/mpeg';
        } else if (messageType == 'image') {
          effectiveMime = 'image/jpeg';
        } else if (messageType == 'video') {
          effectiveMime = 'video/mp4';
        } else {
          effectiveMime = 'application/octet-stream';
        }
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(effectiveMime),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Failed to upload media: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  // --- End Chat API Endpoints ---

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/users/$userId/profile/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Assuming we might want to verify current user ID here if it matches
        return data;
      } else {
        print('Failed to load user profile: ${response.statusCode}');
        return null;
      }
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
      final userData = {
        'email': email,
        'username': username,
        'password': password,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/authentication/register/'),
        headers: _headers,
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Failed to register user: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
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
      final loginData = {
        'username': username,
        'password': password,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/authentication/login/'),
        headers: _headers,
        body: json.encode(loginData),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['data'] != null) {
             if (result['data']['access_token'] != null) {
                _token = result['data']['access_token'];
             }
             if (result['data']['user'] != null && result['data']['user']['id'] != null) {
                 currentUserId = result['data']['user']['id'];
             }
        }
        return result;
      } else {
        print('Failed to login user: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error logging in user: $e');
      return null;
    }
  }
}
