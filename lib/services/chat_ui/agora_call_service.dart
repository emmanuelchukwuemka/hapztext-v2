import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration constants for Agora SDK.
/// Replace [appId] with your Agora project App ID from https://console.agora.io
class AgoraConfig {
  static String get appId => dotenv.env['AGORA_APP_ID'] ?? 'YOUR_AGORA_APP_ID';

  // For testing without a token server, set to empty string.
  // For production, generate tokens server-side.
  static const String tempToken = '';
}

/// Callback signatures for call events
typedef OnUserJoined = void Function(int remoteUid);
typedef OnUserOffline = void Function(int remoteUid);
typedef OnConnectionStateChanged = void Function(
    ConnectionStateType state, ConnectionChangedReasonType reason);
typedef OnAudioVolumeIndication = void Function(
    List<AudioVolumeInfo> speakers, int totalVolume);

/// Service that wraps the Agora RTC Engine for voice and video calls.
///
/// Usage:
/// ```dart
/// final service = AgoraCallService();
/// await service.initialize();
/// await service.joinChannel('channel_name', uid: 123);
/// // ... call in progress ...
/// await service.leaveChannel();
/// service.dispose();
/// ```
class AgoraCallService extends ChangeNotifier {
  bool _isMock = false;
  bool get isMock => _isMock;

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInChannel = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;

  // Remote users currently in the channel
  final List<int> _remoteUsers = [];
  // Active speaker UID (0 = local user)
  int? _activeSpeakerUid;
  // Connection state
  ConnectionStateType _connectionState =
      ConnectionStateType.connectionStateDisconnected;

  // Event callbacks
  OnUserJoined? onUserJoined;
  OnUserOffline? onUserOffline;
  OnConnectionStateChanged? onConnectionStateChanged;
  OnAudioVolumeIndication? onAudioVolumeIndication;
  VoidCallback? onJoinChannelSuccess;
  VoidCallback? onLeaveChannel;

  // Getters
  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isFrontCamera => _isFrontCamera;
  List<int> get remoteUsers => List.unmodifiable(_remoteUsers);
  int? get activeSpeakerUid => _activeSpeakerUid;
  ConnectionStateType get connectionState => _connectionState;

  /// Initialize the Agora RTC Engine.
  /// Must be called before any other operations.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (AgoraConfig.appId == 'YOUR_AGORA_APP_ID' || AgoraConfig.appId.isEmpty) {
      debugPrint('AgoraCallService: Entering MOCK mode (App ID not set)');
      _isMock = true;
      _isInitialized = true;
      notifyListeners();
      return true;
    }

    try {
      // Request permissions
      final cameraGranted = await Permission.camera.request().isGranted;
      final micGranted = await Permission.microphone.request().isGranted;

      if (!micGranted) {
        debugPrint('AgoraCallService: Microphone permission denied. Falling back to MOCK mode.');
        _isMock = true;
        _isInitialized = true;
        notifyListeners();
        return true;
      }

      // Create engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Register event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
              'AgoraCallService: Joined channel ${connection.channelId} in ${elapsed}ms');
          _isInChannel = true;
          onJoinChannelSuccess?.call();
          notifyListeners();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint(
              'AgoraCallService: Left channel. Duration: ${stats.duration}s');
          _isInChannel = false;
          _remoteUsers.clear();
          onLeaveChannel?.call();
          notifyListeners();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('AgoraCallService: Remote user $remoteUid joined');
          if (!_remoteUsers.contains(remoteUid)) {
            _remoteUsers.add(remoteUid);
          }
          onUserJoined?.call(remoteUid);
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint('AgoraCallService: Remote user $remoteUid left ($reason)');
          _remoteUsers.remove(remoteUid);
          onUserOffline?.call(remoteUid);
          notifyListeners();
        },
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('AgoraCallService: Connection state: $state ($reason)');
          _connectionState = state;
          onConnectionStateChanged?.call(state, reason);
          notifyListeners();
        },
        onAudioVolumeIndication: (RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int totalVolume,
            int speakerNumber) {
          // Find the loudest speaker
          if (speakers.isNotEmpty) {
            int maxVol = 0;
            int? loudestUid;
            for (final s in speakers) {
              if ((s.volume ?? 0) > maxVol) {
                maxVol = s.volume ?? 0;
                loudestUid = s.uid;
              }
            }
            _activeSpeakerUid = loudestUid;
          }
          onAudioVolumeIndication?.call(speakers, totalVolume);
          notifyListeners();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('AgoraCallService ERROR: $err - $msg');
        },
      ));

      // Enable audio volume indication (for speaker detection)
      await _engine!.enableAudioVolumeIndication(
        interval: 500,
        smooth: 3,
        reportVad: true,
      );

      _isInitialized = true;
      debugPrint('AgoraCallService: Engine initialized successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AgoraCallService: Failed to initialize real Agora: $e. Falling back to MOCK mode.');
      _isMock = true;
      _isInitialized = true;
      notifyListeners();
      return true;
    }
  }

  /// Join a voice/video channel.
  ///
  /// [channelName] - Unique channel name (use conversation ID)
  /// [uid] - Local user ID (0 = auto-assign)
  /// [enableVideo] - Whether to enable video on join
  /// [isBroadcaster] - True if streaming, false if audience
  Future<void> joinChannel(String channelName,
      {int uid = 0,
      bool enableVideo = false,
      bool isBroadcaster = true}) async {
    if (!_isInitialized) {
      debugPrint('AgoraCallService: Engine not initialized');
      return;
    }

    if (_isMock) {
      _isInChannel = true;
      _isVideoEnabled = enableVideo;
      onJoinChannelSuccess?.call();
      notifyListeners();

      // If we are audience (isBroadcaster = false), simulate a remote streamer joining after 1.5 seconds!
      if (!isBroadcaster) {
        Timer(const Duration(milliseconds: 1500), () {
          if (_isInChannel) {
            _remoteUsers.add(9999);
            onUserJoined?.call(9999);
            notifyListeners();
          }
        });
      }
      return;
    }

    // Enable/disable video before joining based on broadcaster role
    if (isBroadcaster && enableVideo) {
      await _engine!.enableVideo();
      _isVideoEnabled = true;
    } else {
      await _engine!.disableVideo();
      _isVideoEnabled = false;
    }

    // Enable audio
    if (isBroadcaster) {
      await _engine!.enableAudio();
    }

    // Set speaker mode
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);

    // Join the channel
    await _engine!.joinChannel(
      token: AgoraConfig.tempToken,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: isBroadcaster
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true, // Always subscribe to video
        publishMicrophoneTrack: isBroadcaster,
        publishCameraTrack: isBroadcaster && enableVideo,
      ),
    );

    debugPrint('AgoraCallService: Joining channel $channelName...');
  }

  /// Leave the current channel.
  Future<void> leaveChannel() async {
    if (_isMock) {
      _isInChannel = false;
      _remoteUsers.clear();
      onLeaveChannel?.call();
      notifyListeners();
      return;
    }

    if (!_isInChannel || _engine == null) return;

    await _engine!.leaveChannel();
    _remoteUsers.clear();
    _isInChannel = false;
    notifyListeners();
  }

  /// Toggle local microphone mute.
  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  /// Set mute state explicitly.
  Future<void> setMuted(bool muted) async {
    if (_engine == null) return;
    _isMuted = muted;
    await _engine!.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  /// Toggle local video on/off.
  Future<void> toggleVideo() async {
    if (_engine == null) return;
    _isVideoEnabled = !_isVideoEnabled;
    if (_isVideoEnabled) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
      await _engine!.muteLocalVideoStream(false);
    } else {
      await _engine!.muteLocalVideoStream(true);
      await _engine!.stopPreview();
    }
    notifyListeners();
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  /// Toggle speaker/earpiece.
  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    _isSpeakerOn = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    notifyListeners();
  }

  /// Mute a specific remote user's audio (local only).
  Future<void> muteRemoteAudio(int uid, bool mute) async {
    if (_engine == null) return;
    await _engine!.muteRemoteAudioStream(uid: uid, mute: mute);
  }

  /// Get the channel name from a conversation/chat ID.
  /// This creates a deterministic channel name both users will join.
  static String channelFromConversation(String conversationId) {
    return 'hapzo_call_$conversationId';
  }

  /// Dispose the engine and clean up resources.
  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    _isInitialized = false;
    _isInChannel = false;
    _remoteUsers.clear();
    super.dispose();
  }
}
