import 'dart:async';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LivestreamWebsocketService {
  final HapzTextApiService _apiService;
  RealtimeChannel? _channel;

  StreamController<Map<String, dynamic>> _streamEventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get streamEvents =>
      _streamEventsController.stream;

  LivestreamWebsocketService(this._apiService);

  void connectToWebSocket(String streamId) {
    disconnectWebSocket(); // Close any existing connection

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }

      _channel = client.channel('livestream:$streamId');
      _channel!.onBroadcast(
        event: 'livestream',
        callback: (payload) {
          final raw = payload['payload'];
          if (raw is Map<String, dynamic>) {
            _streamEventsController.add(raw);
          }
        },
      );
      _channel!.subscribe();
    } catch (e) {
      print('Error connecting to Livestream WebSocket: $e');
    }
  }

  void startStream(String title) {
    _sendMessage({"type": "start_stream", "title": title});
  }

  void endStream() {
    _sendMessage({"type": "end_stream"});
  }

  void sendComment(String text,
      {String commentType = 'text', String duration = ''}) {
    _sendMessage({
      "type": "send_comment",
      "text": text,
      "comment_type": commentType,
      "duration": duration
    });
  }

  void sendGift(String giftType) {
    _sendMessage({"type": "send_gift", "gift_type": giftType});
  }

  void sendReaction(String emoji) {
    _sendMessage({"type": "send_reaction", "emoji": emoji});
  }

  void _sendMessage(Map<String, dynamic> data) {
    if (_channel != null) {
      try {
        _channel!.sendBroadcastMessage(event: 'livestream', payload: data);
      } catch (e) {
        print('Error sending to Livestream WS: $e');
      }
    }
  }

  void disconnectWebSocket() {
    if (_channel != null) {
      _channel!.unsubscribe();
      _channel = null;
    }
  }

  void dispose() {
    disconnectWebSocket();
    _streamEventsController.close();
  }
}
