import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:haptext_api/services/chat_ui/agora_call_service.dart';

class _Participant {
  final String id;
  final String name;
  final Color color;
  bool mutedByAdmin;
  bool mutedSelf;
  int? remoteUid;

  _Participant({
    required this.id,
    required this.name,
    required this.color,
    this.mutedByAdmin = false,
    this.mutedSelf = false,
    this.remoteUid,
  });
}

class VoiceCallPage extends StatefulWidget {
  final String? channelName;
  final int? localUid;

  const VoiceCallPage({super.key, this.channelName, this.localUid});

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage>
    with SingleTickerProviderStateMixin {
  // Agora service
  late final AgoraCallService _agoraService;
  bool _isJoining = true;
  bool _isConnected = false;

  // Participants
  final List<_Participant> _participants = [];
  String _mainParticipantId = 'local';

  // Controls
  bool _speakerOn = true;
  bool _isMuted = false;
  bool _focusMode = false;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Add local participant
    _participants.add(_Participant(
      id: 'local',
      name: 'You',
      color: Colors.teal,
    ));

    _agoraService = AgoraCallService();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    final success = await _agoraService.initialize();
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize. Check microphone permission.'),
            backgroundColor: Colors.red,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return;
    }

    _agoraService.onUserJoined = (int remoteUid) {
      if (mounted) {
        setState(() {
          if (!_participants.any((p) => p.remoteUid == remoteUid)) {
            _participants.add(_Participant(
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
          if (_mainParticipantId == 'remote_$remoteUid') {
            _mainParticipantId =
                _participants.isNotEmpty ? _participants.last.id : 'local';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User left the call'),
              backgroundColor: Colors.orange),
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
          if ((s.volume ?? 0) > maxVol) maxVol = (s.volume ?? 0).toDouble();
        }
        setState(() => _audioLevel = (maxVol / 255).clamp(0.0, 1.0));
      }
    };

    final channel = widget.channelName ?? 'hapzo_test_channel';
    await _agoraService.joinChannel(
      AgoraCallService.channelFromConversation(channel),
      uid: widget.localUid ?? 0,
      enableVideo: false,
    );
  }

  _Participant get _mainParticipant =>
      _participants.firstWhere((p) => p.id == _mainParticipantId,
          orElse: () => _participants.first);

  void _toggleSpeaker() {
    _agoraService.toggleSpeaker();
    setState(() => _speakerOn = _agoraService.isSpeakerOn);
  }

  void _toggleSelfMute() {
    _agoraService.toggleMute();
    setState(() {
      _isMuted = _agoraService.isMuted;
      _participants.first.mutedSelf = _isMuted;
    });
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
      if (mounted) setState(() => _reactions.removeWhere((x) => x.id == r.id));
    });
  }

  void _selectParticipant(String id) => setState(() => _mainParticipantId = id);

  Future<void> _endCall() async {
    _callStopwatch.stop();
    _timerUpdate?.cancel();
    await _agoraService.leaveChannel();
    if (mounted) Navigator.of(context).pop();
  }

  bool _mainParticipantMuted(_Participant p) => p.mutedByAdmin || p.mutedSelf;

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: main.color,
              child: Text(shortName[0],
                  style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(main.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _isConnected ? _callDuration : 'Connecting...',
                  style: TextStyle(
                    color: _isConnected ? Colors.white70 : Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_focusMode ? Icons.visibility : Icons.visibility_off),
            tooltip: _focusMode ? 'Focus mode on' : 'Focus mode off',
            onPressed: _toggleFocusMode,
          ),
        ],
      ),
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

          // Center large avatar with pulses
          Align(
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
                            final base = 1.0 +
                                ((_mainParticipantMuted(main)
                                        ? 0.0
                                        : _audioLevel) *
                                    0.35);
                            final scale = base + phase * (0.9 + i * 0.2);
                            final opacity =
                                (1.0 - phase).clamp(0.0, 1.0) * 0.25;
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
                            color: _mainParticipantMuted(main)
                                ? Colors.redAccent
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _mainParticipantMuted(main)
                                    ? Icons.mic_off
                                    : Icons.mic,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _mainParticipantMuted(main) ? 'Muted' : 'On',
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
                    Text(main.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(_speakerOn ? Icons.volume_up : Icons.volume_off,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(_speakerOn ? 'Speaker' : 'Earpiece',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

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
                      Text('Connecting...',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
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
              height: 120,
              child: Card(
                color: Colors.white12,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
                          width: isMain ? 84 : 74,
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
                                    child: Text(p.name[0],
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ),
                                  if (p.mutedByAdmin || p.mutedSelf)
                                    const CircleAvatar(
                                      radius: 7,
                                      backgroundColor: Colors.redAccent,
                                      child: Icon(Icons.mic_off, size: 10),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(p.name,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
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
          ..._reactions.map(
              (r) => _FloatingReactionWidget(key: ValueKey(r.id), data: r)),

          // Bottom controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          onPressed: _toggleSelfMute,
                          active: _isMuted,
                        ),
                        _ControlButton(
                          icon:
                              _speakerOn ? Icons.volume_up : Icons.volume_down,
                          label: 'Speaker',
                          onPressed: _toggleSpeaker,
                          active: _speakerOn,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.redAccent,
                      shape: const CircleBorder(),
                      elevation: 6,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _endCall,
                        child: const Padding(
                          padding: EdgeInsets.all(14.0),
                          child: Icon(Icons.call_end,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlButton(
                          icon: Icons.emoji_emotions_outlined,
                          label: 'React',
                          onPressed: () => _showReactionPicker(context),
                        ),
                        _ControlButton(
                          icon: _focusMode
                              ? Icons.visibility
                              : Icons.visibility_off,
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
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
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

/// Small control button
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

/// Reaction model
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
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward();
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
