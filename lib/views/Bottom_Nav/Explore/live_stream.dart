import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/exports.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:haptext_api/services/chat_ui/agora_call_service.dart';
import 'package:haptext_api/services/chat_ui/livestream_websocket_service.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _noActiveStream = false;
  String? _streamId;
  String _streamerUsername = "Chloe";
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  // Recording State
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // Mock stream simulation
  Timer? _mockTimer;
  final List<String> _mockUsers = ["Alex", "Jessica", "Marcus", "Emma", "David", "Chloe", "Sophia", "Lucas"];
  final List<String> _mockComments = [
    "Wow, this is amazing! 🔥",
    "Hey Chloe! Looking great today!",
    "Awesome live stream! 👏👏",
    "Where are you streaming from?",
    "This song is fire! 🎶🎶",
    "Love the vibes here!",
    "Amazing stream! 😍",
    "Hello from NYC! 🗽"
  ];
  final List<String> _mockGifts = ["Rose 🌹", "Crown 👑", "Magic Wand 🪄", "Ice Cream 🍦"];

  void _startMockStreamActivity() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final random = Random();
      final actionType = random.nextInt(4); // 0: comment, 1: gift, 2: join, 3: reaction

      setState(() {
        if (actionType == 0) {
          final user = _mockUsers[random.nextInt(_mockUsers.length)];
          final text = _mockComments[random.nextInt(_mockComments.length)];
          _comments.add({
            'user': user,
            'text': text,
            'type': 'text',
          });
        } else if (actionType == 1) {
          final user = _mockUsers[random.nextInt(_mockUsers.length)];
          final gift = _mockGifts[random.nextInt(_mockGifts.length)];
          _comments.add({
            'user': user,
            'text': 'sent $gift',
            'type': 'gift',
          });
        } else if (actionType == 2) {
          _viewerCount += random.nextBool() ? 1 : -1;
          if (_viewerCount < 1) _viewerCount = 1;
        } else {
          final user = _mockUsers[random.nextInt(_mockUsers.length)];
          _comments.add({
            'user': user,
            'text': 'reacted ❤️',
            'type': 'text',
          });
        }
        
        // Keep list size under control
        if (_comments.length > 50) {
          _comments.removeAt(0);
        }
      });
    });
  }

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
    setState(() {
      _noActiveStream = false;
    });
    final success = await _agoraService.initialize();
    if (success) {
      bool foundActive = false;
      // Query active livestream from Supabase posts
      try {
        final client = Supabase.instance.client;
        final activeStreams = await client
            .from('posts')
            .select('sender_username, video_content')
            .eq('post_format', 'live')
            .order('created_at', ascending: false)
            .limit(1);

        if (activeStreams != null && (activeStreams as List).isNotEmpty) {
          final streamData = activeStreams.first;
          _streamId = streamData['video_content']?.toString();
          _streamerUsername = streamData['sender_username']?.toString() ?? "Streamer";
          foundActive = true;
          debugPrint('Found active stream channel ID: $_streamId from $_streamerUsername');
        }
      } catch (e) {
        debugPrint('Error fetching active livestream post: $e');
      }

      if (!foundActive) {
        if (mounted) {
          setState(() {
            _noActiveStream = true;
            _isLive = false;
          });
        }
        return;
      }

      await _agoraService.joinChannel(_streamId!,
          isBroadcaster: false, enableVideo: false);
      if (mounted) {
        setState(() {
          _isLive = true;
          if (_agoraService.isMock) {
            _viewerCount = 12; // Start with a realistic mock viewer count
            _startMockStreamActivity();
          }
        });
        _wsService.connectToWebSocket(_streamId!);
      }
    }
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _wsService.dispose();
    _agoraService.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_noActiveStream) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sensors_off_outlined,
                  color: Colors.white24,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  "No Active Livestreams",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "There are no live broadcasts right now. Tap the 'Go Live' icon on the top right to start a stream!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _noActiveStream = false;
                      _isLive = false;
                      _streamId = null;
                    });
                    _initLive();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    "Refresh",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Main Video Stream Placeholder
          if (_isLive &&
              !_agoraService.isMock &&
              _agoraService.engine != null &&
              _agoraService.remoteUsers.isNotEmpty)
            SizedBox.expand(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _agoraService.engine!,
                  canvas: VideoCanvas(uid: _agoraService.remoteUsers.first),
                  connection: RtcConnection(channelId: _streamId!),
                ),
              ),
            )
          else
            _buildLiveStreamAmbientWidget(),

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
                    _isStreamer
                        ? "Your Stream"
                        : (_streamId != null && !_streamId!.startsWith("live_stream_")
                            ? "$_streamerUsername is Live"
                            : "Demo Mode"),
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
                      reverse: true,
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
    bool isVoice = comment['type'] == 'voice';

    if (isVoice) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${comment['user']}: ",
                style: const TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              VoiceNoteCommentWidget(comment: comment),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "${comment['user']}: ",
              style: TextStyle(
                color: isGift ? const Color(0xFFFFD700) : const Color(0xFF8B5CF6),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              comment['text'],
              style: TextStyle(
                color: isGift ? const Color(0xFFFFD700) : Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
                          onSubmitted: (text) {
                            final textTrim = text.trim();
                            if (textTrim.isNotEmpty) {
                              _wsService.sendComment(textTrim);
                              setState(() {
                                _comments.insert(0, {
                                  'user': 'You',
                                  'text': textTrim,
                                  'type': 'text',
                                });
                              });
                              _commentController.clear();
                            }
                          },
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
                            setState(() {
                              _comments.insert(0, {
                                'user': 'You',
                                'text': text,
                                'type': 'text',
                              });
                            });
                            _commentController.clear();
                          } else {
                            // Start voice note recording when text is empty
                            _toggleRecording();
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
        _buildSmallIconAction(
          Icons.card_giftcard,
          const Color(0xFFFFD700),
          onTap: () {
            _wsService.sendGift("Super Gift");
            setState(() {
              _comments.insert(0, {
                'user': 'You',
                'text': 'sent Rose 🌹',
                'type': 'gift',
              });
            });
          },
        ),
        const SizedBox(width: 12),
        _buildSmallIconAction(
          Icons.favorite,
          Coloors.error,
          onTap: () {
            _wsService.sendReaction("❤️");
            setState(() {
              _comments.insert(0, {
                'user': 'You',
                'text': 'reacted ❤️',
                'type': 'text',
              });
            });
          },
        ),
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

  Widget _buildSmallIconAction(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildLiveStreamAmbientWidget() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F0C20),
              Color(0xFF15102A),
              Color(0xFF06040A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient glowing waves
            const Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  physics: NeverScrollableScrollPhysics(),
                  child: Opacity(
                    opacity: 0.15,
                    child: Icon(
                      Icons.waves,
                      size: 400,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing glowing rings around avatar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/images/placeholder.jpg'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _streamId != null && !_streamId!.startsWith("live_stream_")
                      ? "$_streamerUsername is live"
                      : "Chloe is live (Demo)",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi, color: Color(0xFF8B5CF6), size: 14),
                      SizedBox(width: 6),
                      Text(
                        "Streaming Video & Audio",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceNoteCommentWidget extends StatefulWidget {
  final Map<String, dynamic> comment;
  const VoiceNoteCommentWidget({super.key, required this.comment});

  @override
  State<VoiceNoteCommentWidget> createState() => _VoiceNoteCommentWidgetState();
}

class _VoiceNoteCommentWidgetState extends State<VoiceNoteCommentWidget> {
  bool _isPlaying = false;
  Duration _elapsed = Duration.zero;
  Timer? _playbackTimer;
  late Duration _totalDuration;

  @override
  void initState() {
    super.initState();
    _totalDuration = _parseDuration(widget.comment['duration'] ?? '00:05');
  }

  Duration _parseDuration(String durationStr) {
    try {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return const Duration(seconds: 5);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopPlay();
    } else {
      _startPlay();
    }
  }

  void _startPlay() {
    setState(() {
      _isPlaying = true;
      _elapsed = Duration.zero;
    });

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_elapsed >= _totalDuration) {
          _stopPlay();
        } else {
          _elapsed += const Duration(seconds: 1);
        }
      });
    });
  }

  void _stopPlay() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _elapsed = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: CircleAvatar(
            radius: 12,
            backgroundColor: _isPlaying ? const Color(0xFF8B5CF6) : Colors.white24,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Pulsing audio equalizers
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(6, (index) {
            final double height = _isPlaying
                ? (4 + (index * 3) % 8 + (DateTime.now().millisecondsSinceEpoch ~/ 150 + index) % 6).toDouble()
                : 4.0;
            return Container(
              width: 1.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _isPlaying ? const Color(0xFF8B5CF6) : Colors.white54,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          _isPlaying
              ? "${_formatDuration(_elapsed)} / ${_formatDuration(_totalDuration)}"
              : _formatDuration(_totalDuration),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

