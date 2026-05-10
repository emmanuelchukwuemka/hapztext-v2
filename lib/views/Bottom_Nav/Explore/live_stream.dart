import 'dart:ui';
import 'dart:async';
import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/exports.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:haptext_api/services/chat_ui/agora_call_service.dart';
import 'package:haptext_api/services/chat_ui/livestream_websocket_service.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';

class LiveStreamApp extends StatelessWidget {
  const LiveStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
        scrollDirection: Axis.vertical,
        itemBuilder: (BuildContext context, int index) {
          return const LiveStreamPage();
        });
  }
}

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage>
    with SingleTickerProviderStateMixin {
  final bool _isStreamer = false;
  late final AgoraCallService _agoraService;
  late final LivestreamWebsocketService _wsService;
  int _viewerCount = 0;
  bool _isLive = false;
  final String _streamId =
      "live_stream_${DateTime.now().millisecondsSinceEpoch}";
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  // Recording State
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _agoraService = AgoraCallService();
    _wsService = LivestreamWebsocketService(HapzTextApiService());

    _agoraService.addListener(() {
      if (mounted) setState(() {});
    });

    _wsService.streamEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event['type'] == 'new_comment') {
          _comments.add({
            'user': event['username'] ?? 'User',
            'text': event['text'] ?? '',
            'type': event['comment_type'] ?? 'text',
          });
        } else if (event['type'] == 'viewer_joined' ||
            event['type'] == 'viewer_left' ||
            event['type'] == 'viewer_count_update') {
          _viewerCount = event['viewer_count'] ?? _viewerCount;
        }
      });
    });

    _initLive();
  }

  Future<void> _initLive() async {
    final success = await _agoraService.initialize();
    if (success) {
      await _agoraService.joinChannel(_streamId,
          isBroadcaster: false, enableVideo: false);
      if (mounted) {
        setState(() {
          _isLive = true;
        });
        _wsService.connectToWebSocket(_streamId);
      }
    }
  }

  @override
  void dispose() {
    _wsService.dispose();
    _agoraService.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Main Video Stream Placeholder
          if (_isLive &&
              _agoraService.engine != null &&
              _agoraService.remoteUsers.isNotEmpty)
            SizedBox.expand(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _agoraService.engine!,
                  canvas: VideoCanvas(uid: _agoraService.remoteUsers.first),
                  connection: RtcConnection(channelId: _streamId),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.videocam_off,
                      color: Colors.white10, size: 100),
                ),
              ),
            ),

          // 2. Top Bar (Live Badge & Viewer Count)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Coloors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isStreamer ? "Your Stream" : "No active stream",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.remove_red_eye_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "$_viewerCount",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  if (_isStreamer) ...[
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {},
                    )
                  ]
                ],
              ),
            ),
          ),

          // 3. Bottom Area (Live Chat & Controls)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live Chat (Scrollable placeholder)
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return _buildCommentItem(comment);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Control Bar / Input Area
                  if (_isStreamer)
                    _buildStreamerControls()
                  else
                    _buildViewerInput(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopAndSendRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
  }

  void _stopAndSendRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _comments.add({
        "user": "You",
        "text": "🔊 Voice Note ${_formatDuration(_recordDuration)}",
        "type": "voice",
        "duration": _formatDuration(_recordDuration)
      });
    });
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    bool isGift = comment['type'] == 'gift';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${comment['user']}: ",
            style: TextStyle(
              color: isGift ? const Color(0xFFFFD700) : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: comment['type'] == 'voice'
                ? Row(
                    children: [
                      const Icon(Icons.volume_up,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "[Voice Note ${comment['duration']}]",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  )
                : Text(
                    comment['text'],
                    style: TextStyle(
                      color: isGift ? const Color(0xFFFFD700) : Colors.white,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(Icons.mic, "Mic"),
        _buildControlButton(Icons.videocam, "Camera"),
        _buildControlButton(Icons.settings, "Settings"),
        _buildControlButton(Icons.stop_circle, "END", color: Coloors.error),
      ],
    );
  }

  Widget _buildViewerInput() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withOpacity(0.1),
                child: Row(
                  children: [
                    if (_isRecording)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.circle,
                                color: Colors.red, size: 12),
                            const SizedBox(width: 8),
                            Text(_formatDuration(_recordDuration),
                                style: const TextStyle(color: Colors.white)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _cancelRecording,
                              child: const Text("Cancel",
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Type message...",
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () {
                        if (_isRecording) {
                          _toggleRecording();
                        } else {
                          final text = _commentController.text.trim();
                          if (text.isNotEmpty) {
                            _wsService.sendComment(text);
                            _commentController.clear();
                          }
                        }
                      },
                      icon: Icon(
                        _isRecording ? Icons.send : Icons.mic,
                        color:
                            _isRecording ? Colors.cyanAccent : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildSmallIconAction(Icons.card_giftcard, const Color(0xFFFFD700)),
        const SizedBox(width: 12),
        _buildSmallIconAction(Icons.favorite, Coloors.error),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, String label, {Color? color}) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.1),
          child: Icon(icon, color: color ?? Colors.white),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSmallIconAction(IconData icon, Color color) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
