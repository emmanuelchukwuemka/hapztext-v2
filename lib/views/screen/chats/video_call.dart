import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:haptext_api/services/chat_ui/agora_call_service.dart';

class _GCallParticipant {
  final String id;
  String name;
  bool muted;
  bool videoOn;
  bool sharing;
  bool speaking;
  int? remoteUid;

  _GCallParticipant({
    required this.id,
    required this.name,
    this.muted = false,
    this.videoOn = true,
    this.sharing = false,
    this.speaking = false,
    this.remoteUid,
  });
}

class GroupCallPage extends StatefulWidget {
  final String? channelName;
  final int? localUid;

  const GroupCallPage({super.key, this.channelName, this.localUid});

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage>
    with TickerProviderStateMixin {
  // Agora
  late final AgoraCallService _agoraService;
  bool _isJoining = true;
  bool _isConnected = false;

  final List<_GCallParticipant> _participants = [];
  String myId = 'me';
  bool _muted = false;
  bool _videoOn = true;

  // UI state
  String? focusParticipantId;
  Offset myPreviewOffset = const Offset(18, 18);

  // Call timer
  final Stopwatch _callStopwatch = Stopwatch();
  Timer? _timerUpdate;
  String _callDuration = '00:00';

  @override
  void initState() {
    super.initState();
    _participants.add(
      _GCallParticipant(id: 'me', name: 'You', muted: false, videoOn: true),
    );

    _agoraService = AgoraCallService();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    final success = await _agoraService.initialize();
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to initialize call'),
              backgroundColor: Colors.red),
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
            _participants.add(_GCallParticipant(
              id: 'user_$remoteUid',
              name: 'User $remoteUid',
              remoteUid: remoteUid,
            ));
          }
        });
        _showToast('User $remoteUid joined');
      }
    };

    _agoraService.onUserOffline = (int remoteUid) {
      if (mounted) {
        setState(() {
          _participants.removeWhere((p) => p.remoteUid == remoteUid);
          if (focusParticipantId == 'user_$remoteUid')
            focusParticipantId = null;
        });
        _showToast('User $remoteUid left');
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
      if (mounted) {
        setState(() {
          // Reset speaking state
          for (var p in _participants) {
            p.speaking = false;
          }
          // Mark active speaker
          for (final s in speakers) {
            if ((s.volume ?? 0) > 50) {
              final uid = s.uid;
              if (uid == 0) {
                _participants.firstWhere((p) => p.id == 'me').speaking = true;
              } else {
                final p = _participants.where((p) => p.remoteUid == uid);
                if (p.isNotEmpty) p.first.speaking = true;
              }
            }
          }
        });
      }
    };

    final channel = widget.channelName ?? 'hapzo_group_test';
    await _agoraService.joinChannel(
      AgoraCallService.channelFromConversation(channel),
      uid: widget.localUid ?? 0,
      enableVideo: true,
    );
  }

  void _setFocus(String? id) {
    setState(() {
      focusParticipantId = focusParticipantId == id ? null : id;
    });
  }

  void _toggleMute() {
    _agoraService.toggleMute();
    setState(() {
      _muted = _agoraService.isMuted;
      final me = _participants.firstWhere((p) => p.id == myId);
      me.muted = _muted;
    });
    _showToast(_muted ? 'Muted' : 'Unmuted');
  }

  void _toggleVideo() {
    _agoraService.toggleVideo();
    setState(() {
      _videoOn = _agoraService.isVideoEnabled;
      final me = _participants.firstWhere((p) => p.id == myId);
      me.videoOn = _videoOn;
    });
    _showToast(_videoOn ? 'Camera on' : 'Camera off');
  }

  void _switchCamera() {
    _agoraService.switchCamera();
  }

  Future<void> _leaveCall() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Call?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End')),
        ],
      ),
    );
    if (confirm == true) {
      _callStopwatch.stop();
      _timerUpdate?.cancel();
      await _agoraService.leaveChannel();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showToast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  List<_GCallParticipant> get _others =>
      _participants.where((p) => p.id != myId).toList();
  _GCallParticipant get _me => _participants.firstWhere((p) => p.id == myId);

  @override
  void dispose() {
    _timerUpdate?.cancel();
    _callStopwatch.stop();
    _agoraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMainArea()),

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
                        Text('Joining group call...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),

            // Top info
            Positioned(
              top: 12,
              left: 12,
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Icon(Icons.videocam, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('${_participants.length} in call · $_callDuration',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ]),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(40)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Mute',
                      icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                      color: _muted ? Colors.orangeAccent : Colors.white,
                      onPressed: _toggleMute,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Toggle Camera',
                      icon:
                          Icon(_videoOn ? Icons.videocam : Icons.videocam_off),
                      color: Colors.white,
                      onPressed: _toggleVideo,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Switch Camera',
                      icon: const Icon(Icons.cameraswitch),
                      color: Colors.white,
                      onPressed: _switchCamera,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14)),
                      onPressed: _leaveCall,
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainArea() {
    // Focus mode: show focused participant full screen
    if (focusParticipantId != null) {
      final focused = _participants.firstWhere(
        (p) => p.id == focusParticipantId,
        orElse: () => _me,
      );
      return GestureDetector(
        onDoubleTap: () => _setFocus(null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(child: _videoTile(focused, big: true)),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6.0),
                    child: Text(
                        '${focused.name} · ${focused.muted ? 'muted' : 'live'}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              // Strip of other participants
              Positioned(
                left: 0,
                right: 0,
                bottom: 120,
                child: SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _participants
                        .where((p) => p.id != focused.id)
                        .map((p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                                onTap: () => _setFocus(p.id),
                                child:
                                    SizedBox(width: 100, child: _miniTile(p)))))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default: dynamic grid
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = _participants.length;
        int crossAxisCount;
        if (width > 1000)
          crossAxisCount = 4;
        else if (width > 700)
          crossAxisCount = min(3, max(1, count));
        else if (width > 450)
          crossAxisCount = min(2, max(1, count));
        else
          crossAxisCount = 1;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _participants.map((p) {
                final w =
                    (width - (12 * (crossAxisCount + 1))) / crossAxisCount;
                return GestureDetector(
                  onDoubleTap: () => _setFocus(p.id),
                  child: SizedBox(
                      width: w, height: w * 0.65, child: _videoTile(p)),
                );
              }).toList(),
            ),
          ),
        );
      }),
    );
  }

  /// Video tile for a participant — uses AgoraVideoView for real video
  Widget _videoTile(_GCallParticipant p,
      {bool big = false, bool mini = false}) {
    final border = p.speaking ? 3.5 : 0.5;
    final borderColor = p.speaking ? Colors.greenAccent : Colors.white12;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: border),
      ),
      child: Stack(
        children: [
          // Video or placeholder
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildVideoContent(p, big: big),
            ),
          ),
          // Name & status bar
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                Expanded(
                    child: Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white))),
                if (p.muted)
                  const Icon(Icons.mic_off, size: 18, color: Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(_GCallParticipant p, {bool big = false}) {
    if (p.id == 'me') {
      // Local video
      if (_videoOn && _agoraService.engine != null) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _agoraService.engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      }
    } else if (p.remoteUid != null &&
        p.videoOn &&
        _agoraService.engine != null) {
      // Remote video
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _agoraService.engine!,
          canvas: VideoCanvas(uid: p.remoteUid!),
          connection: RtcConnection(
            channelId: AgoraCallService.channelFromConversation(
                widget.channelName ?? 'hapzo_group_test'),
          ),
        ),
      );
    }

    // Fallback: avatar
    return Container(
      decoration: BoxDecoration(
        color: Colors
            .primaries[(p.name.hashCode.abs()) % Colors.primaries.length]
            .shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: p.videoOn
            ? Icon(Icons.videocam, size: big ? 84 : 40, color: Colors.white24)
            : Text(p.name[0],
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
      ),
    );
  }

  Widget _miniTile(_GCallParticipant p,
      {bool highlight = false, double size = 96}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size * 0.62,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: p.speaking ? Colors.greenAccent : Colors.white12,
            width: p.speaking ? 2.2 : 0.6),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildVideoContent(p),
          ),
        ),
        Positioned(
            right: 8,
            top: 8,
            child: Row(children: [
              if (p.muted)
                const Icon(Icons.mic_off, size: 16, color: Colors.redAccent),
              if (!p.videoOn) const SizedBox(width: 4),
              if (!p.videoOn)
                const Icon(Icons.videocam_off, size: 16, color: Colors.white54),
            ])),
        Positioned(
            left: 8,
            bottom: 8,
            child: Text(p.name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white))),
      ]),
    );
  }
}
