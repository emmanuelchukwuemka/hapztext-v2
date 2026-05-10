import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:haptext_api/services/chat_ui/agora_call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final bool isVideoCall;
  final String? channelName; // Conversation ID for Agora channel
  final int? localUid; // Local user UID

  const VoiceCallScreen({
    super.key,
    this.isVideoCall = false,
    this.channelName,
    this.localUid,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  // Agora service
  late final AgoraCallService _agoraService;
  bool _isJoining = true;
  bool _isConnected = false;

  // Video state
  late bool _videoEnabled;

  // Participants tracking
  final List<_CallParticipant> _participants = [];

  String _mainParticipantId = 'remote'; // focused participant
  bool _focusMode = false;

  // Controls
  bool _speakerOn = true;
  bool _isMuted = false;

  // Call timer
  final Stopwatch _callStopwatch = Stopwatch();
  Timer? _timerUpdate;
  String _callDuration = '00:00';

  // Reactions
  final List<_ReactionData> _reactions = [];

  // Animation controller for pulses
  late final AnimationController _pulseController;
  double _audioLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _videoEnabled = widget.isVideoCall;

    // Initialize Agora
    _agoraService = AgoraCallService();
    _initializeAgora();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Start local participant
    _participants.add(
      _CallParticipant(
        id: 'local',
        name: 'You',
        color: Colors.teal,
        isLocal: true,
      ),
    );
  }

  Future<void> _initializeAgora() async {
    final success = await _agoraService.initialize();
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to initialize call engine. Check permissions.'),
            backgroundColor: Colors.red,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return;
    }

    // Set up event callbacks
    _agoraService.onUserJoined = (int remoteUid) {
      if (mounted) {
        setState(() {
          final exists = _participants.any((p) => p.remoteUid == remoteUid);
          if (!exists) {
            _participants.add(_CallParticipant(
              id: 'remote_$remoteUid',
              name: 'User $remoteUid',
              color: Colors
                  .primaries[remoteUid % Colors.primaries.length].shade600,
              remoteUid: remoteUid,
            ));
          }
          _mainParticipantId = 'remote_$remoteUid';
        });
      }
    };

    _agoraService.onUserOffline = (int remoteUid) {
      if (mounted) {
        setState(() {
          _participants.removeWhere((p) => p.remoteUid == remoteUid);
          if (_participants.length > 1) {
            _mainParticipantId = _participants.last.id;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The other user left the call'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    };

    _agoraService.onJoinChannelSuccess = () {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _isConnected = true;
        });
        _callStopwatch.start();
        _timerUpdate = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            final elapsed = _callStopwatch.elapsed;
            setState(() {
              _callDuration =
                  '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
            });
          }
        });
      }
    };

    _agoraService.onAudioVolumeIndication = (speakers, totalVolume) {
      if (mounted && speakers.isNotEmpty) {
        double maxVol = 0;
        for (final s in speakers) {
          if ((s.volume ?? 0) > maxVol) {
            maxVol = (s.volume ?? 0).toDouble();
          }
        }
        setState(() {
          _audioLevel = (maxVol / 255).clamp(0.0, 1.0);
        });
      }
    };

    // Join channel
    final channel = widget.channelName ?? 'hapzo_test_channel';
    await _agoraService.joinChannel(
      AgoraCallService.channelFromConversation(channel),
      uid: widget.localUid ?? 0,
      enableVideo: widget.isVideoCall,
    );
  }

  _CallParticipant get _mainParticipant {
    return _participants.firstWhere(
      (p) => p.id == _mainParticipantId,
      orElse: () => _participants.first,
    );
  }

  void _toggleSelfMute() {
    _agoraService.toggleMute();
    setState(() {
      _isMuted = _agoraService.isMuted;
      _participants.first.mutedSelf = _isMuted;
    });
  }

  void _toggleVideo() {
    _agoraService.toggleVideo();
    setState(() {
      _videoEnabled = _agoraService.isVideoEnabled;
    });
  }

  void _toggleSpeaker() {
    _agoraService.toggleSpeaker();
    setState(() {
      _speakerOn = _agoraService.isSpeakerOn;
    });
  }

  void _switchCamera() {
    _agoraService.switchCamera();
  }

  void _toggleFocusMode() => setState(() => _focusMode = !_focusMode);

  void _sendReaction(String emoji) {
    final r = _ReactionData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      emoji: emoji,
      start: const Offset(0.85, 0.78),
      dxJitter: (Random().nextDouble() - 0.5) * 0.12,
    );
    setState(() => _reactions.add(r));
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _reactions.removeWhere((x) => x.id == r.id));
      }
    });
  }

  void _selectParticipant(String id) => setState(() => _mainParticipantId = id);

  Future<void> _endCall() async {
    _callStopwatch.stop();
    _timerUpdate?.cancel();
    await _agoraService.leaveChannel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timerUpdate?.cancel();
    _callStopwatch.stop();
    _pulseController.dispose();
    _agoraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final main = _mainParticipant;
    final shortName = main.name.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Navy
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.white, size: 30),
          onPressed: _endCall,
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ColorFilter.mode(
                Colors.white.withOpacity(0.05), BlendMode.lighten),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: main.color,
                    child: Text(
                      shortName[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        main.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _isConnected ? 'Connected' : 'Connecting...',
                        style: TextStyle(
                          color: _isConnected
                              ? Colors.cyanAccent
                              : Colors.orangeAccent,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _callDuration,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF071018),
                  Colors.blueGrey.shade900.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Video/Audio main content
          if (widget.isVideoCall)
            _buildVideoCallContent(main, shortName)
          else
            _buildVoiceCallContent(main, shortName),

          // Joining overlay
          if (_isJoining)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 16),
                      Text(
                        'Connecting...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Participants strip
          Positioned(
            left: 12,
            right: 12,
            bottom: 140,
            child: SizedBox(
              height: 110,
              child: Card(
                color: Colors.white12,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _participants.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final p = _participants[i];
                      final isMain = p.id == _mainParticipantId;
                      return GestureDetector(
                        onTap: () => _selectParticipant(p.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isMain ? 90 : 80,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMain
                                  ? Colors.cyanAccent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  CircleAvatar(
                                    radius: isMain ? 22 : 20,
                                    backgroundColor: p.color,
                                    child: Text(
                                      p.name[0],
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  if (p.mutedSelf)
                                    const CircleAvatar(
                                      radius: 7,
                                      backgroundColor: Colors.redAccent,
                                      child: Icon(Icons.mic_off, size: 10),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.name,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Reactions
          ..._reactions.map((r) {
            return _FloatingReactionWidget(key: ValueKey(r.id), data: r);
          }),

          // Bottom controls - Floating Glassy Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ControlButton(
                                icon: _isMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                label: _isMuted ? 'Unmute' : 'Mute',
                                onPressed: _toggleSelfMute,
                                active: _isMuted,
                              ),
                              _ControlButton(
                                icon: _videoEnabled
                                    ? Icons.videocam_rounded
                                    : Icons.videocam_off_rounded,
                                label: _videoEnabled ? 'Video' : 'Off',
                                onPressed: _toggleVideo,
                                active: _videoEnabled,
                              ),
                              _ControlButton(
                                icon: _speakerOn
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                label: 'Speaker',
                                onPressed: _toggleSpeaker,
                                active: _speakerOn,
                              ),
                            ],
                          ),
                        ),
                        // End Call Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Material(
                            color: Colors.redAccent.withOpacity(0.9),
                            shape: const CircleBorder(),
                            elevation: 8,
                            shadowColor: Colors.redAccent.withOpacity(0.5),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _endCall,
                              child: const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Icon(
                                  Icons.call_end_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ControlButton(
                                icon: Icons.emoji_emotions_rounded,
                                label: 'React',
                                onPressed: () => _showReactionPicker(context),
                              ),
                              if (widget.isVideoCall)
                                _ControlButton(
                                  icon: Icons.cameraswitch_rounded,
                                  label: 'Flip',
                                  onPressed: _switchCamera,
                                ),
                              _ControlButton(
                                icon: _focusMode
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                label: 'Focus',
                                onPressed: _toggleFocusMode,
                                active: _focusMode,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the video call main content area with Agora video views
  Widget _buildVideoCallContent(_CallParticipant main, String shortName) {
    final remoteUids = _agoraService.remoteUsers;
    final hasRemote = remoteUids.isNotEmpty;

    return Stack(
      children: [
        // Remote participant video (full screen)
        if (hasRemote)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: remoteUids.first),
                connection: RtcConnection(
                  channelId: AgoraCallService.channelFromConversation(
                      widget.channelName ?? 'hapzo_test_channel'),
                ),
              ),
            ),
          )
        else
          // Waiting for remote user
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E1E2E),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: main.color.withOpacity(0.3), width: 4),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: main.color.withOpacity(0.2),
                        child: Text(
                          shortName[0],
                          style: TextStyle(
                              fontSize: 48,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      main.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.cyanAccent),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Waiting for participant...',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Local self-preview PiP (Agora video view)
        if (_videoEnabled && _agoraService.engine != null)
          Positioned(
            top: 100,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 130,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _agoraService.engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                    // Self label
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Camera switch
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cameraswitch_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (widget.isVideoCall)
          // Video off - show avatar PiP
          Positioned(
            top: 100,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 130,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade900, Colors.black],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, color: Colors.white38, size: 30),
                      SizedBox(height: 8),
                      Text('Camera Off',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build voice call content with pulse animations
  Widget _buildVoiceCallContent(_CallParticipant main, String shortName) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF1E293B), Color(0xFF020617)],
          ),
        ),
        child: Align(
          alignment: const Alignment(0, -0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (int i = 0; i < 3; i++)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final t = _pulseController.value;
                          final phase = (i / 3 + t) % 1.0;
                          final base =
                              1.0 + ((_isMuted ? 0.0 : _audioLevel) * 0.35);
                          final scale = base + phase * (0.9 + i * 0.2);
                          final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.25;
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: main.color.withOpacity(0.9),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    // Main avatar
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: main.color,
                        boxShadow: [
                          BoxShadow(
                            color: main.color.withOpacity(0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          shortName[0],
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // mic badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isMuted ? Colors.redAccent : Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isMuted ? Icons.mic_off : Icons.mic,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isMuted ? 'Muted' : 'On',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    main.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _speakerOn ? Icons.volume_up : Icons.volume_off,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _speakerOn ? 'Speaker' : 'Earpiece',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        final emojis = ['👍', '❤️', '😂', '🔥', '👏', '😮'];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _sendReaction(e);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────

class _CallParticipant {
  final String id;
  String name;
  final Color color;
  bool isLocal;
  bool mutedSelf;
  bool mutedByAdmin;
  int? remoteUid; // Agora remote user ID

  _CallParticipant({
    required this.id,
    required this.name,
    required this.color,
    this.isLocal = false,
    this.mutedSelf = false,
    this.mutedByAdmin = false,
    this.remoteUid,
  });
}

// ─── Reaction Widgets ─────────────────────────────────────────────

class _ReactionData {
  final String id;
  final String emoji;
  final Offset start;
  final double dxJitter;
  _ReactionData({
    required this.id,
    required this.emoji,
    required this.start,
    required this.dxJitter,
  });
}

class _FloatingReactionWidget extends StatefulWidget {
  final _ReactionData data;
  const _FloatingReactionWidget({required Key key, required this.data})
      : super(key: key);

  @override
  State<_FloatingReactionWidget> createState() =>
      _FloatingReactionWidgetState();
}

class _FloatingReactionWidgetState extends State<_FloatingReactionWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _dy;
  late final Animation<double> _opacity;
  late final double _startXFraction;

  @override
  void initState() {
    super.initState();
    _startXFraction = widget.data.start.dx + widget.data.dxJitter;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _dy = Tween<double>(begin: 0, end: -180)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final startX = screen.width * _startXFraction;
    final startY = screen.height * widget.data.start.dy;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned(
          left: startX,
          top: startY + _dy.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.rotate(
              angle: (1 - _ctrl.value) * 0.12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.data.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Control Button ───────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.cyanAccent.withOpacity(0.14) : Colors.white10;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}
