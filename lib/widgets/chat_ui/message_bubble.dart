import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:haptext_api/models/chat_ui/message.dart';
import 'package:haptext_api/utils/chat_ui/themes.dart';
import 'package:haptext_api/utils/chat_ui/constants.dart';
import 'package:haptext_api/utils/chat_ui/emoji_list.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final int themeIndex;
  final VoidCallback? onTap;
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.themeIndex,
    this.onTap,
    this.onReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPauseAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.message.audioPath != null) {
        if (widget.message.audioPath!.startsWith('http')) {
          await _audioPlayer.play(UrlSource(widget.message.audioPath!));
        } else {
          await _audioPlayer.play(DeviceFileSource(widget.message.audioPath!));
        }
      } else {
        print("No audio path available");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleGradient =
        AppThemes.getBubbleGradient(widget.themeIndex, widget.message.me);

    return Align(
      alignment:
          widget.message.me ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: () => _showMessageMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.hPadding,
            vertical: 4,
          ),
          padding: const EdgeInsets.all(AppConstants.messagePadding),
          decoration: BoxDecoration(
            gradient: widget.message.isEmoji
                ? null
                : LinearGradient(
                    colors: bubbleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.message.isEmoji ? Colors.transparent : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppConstants.bubbleRadius),
              topRight: const Radius.circular(AppConstants.bubbleRadius),
              bottomLeft: Radius.circular(
                  widget.message.me ? AppConstants.bubbleRadius : 4),
              bottomRight: Radius.circular(
                  widget.message.me ? 4 : AppConstants.bubbleRadius),
            ),
            boxShadow: widget.message.isEmoji
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: widget.message.me
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (widget.message.isReply) _buildReplySection(),
              if (widget.message.isVoice)
                _buildVoiceMessage()
              else if (widget.message.isImage)
                _buildImageMessage()
              else if (widget.message.isVideo)
                _buildVideoMessage()
              else if (widget.message.isEmoji)
                _buildEmojiMessage()
              else if (widget.message.viewOnce)
                _buildViewOnceMessage()
              else if (widget.message.isFeedLink)
                _buildFeedLink()
              else
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      widget.message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (widget.message.disappearing)
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 2),
                        child:
                            Icon(Icons.timer, size: 14, color: Colors.white70),
                      ),
                  ],
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(widget.message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                  if (widget.message.me) ...[
                    const SizedBox(width: 4),
                    Icon(
                      widget.message.viewed ? Icons.done_all : Icons.done,
                      size: 14,
                      color: widget.message.viewed
                          ? Colors.blueAccent.shade100
                          : Colors.white54,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text("Reply"),
              onTap: () {
                Navigator.pop(context);
                if (widget.onReply != null) {
                  widget.onReply!();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("Copy Text"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete", style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.teal.shade200,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.previousMessageSenderId ?? "Someone",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.teal.shade200,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.previousMessageContent ?? "Message",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white),
          onPressed: _playPauseAudio,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: _position.inSeconds.toDouble(),
            max: _duration.inSeconds.toDouble() > 0
                ? _duration.inSeconds.toDouble()
                : 1.0,
            onChanged: (value) async {
              final position = Duration(seconds: value.toInt());
              await _audioPlayer.seek(position);
            },
            activeColor: Colors.white,
            inactiveColor: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildVideoMessage() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.videocam, color: Colors.white, size: 50),
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    return widget.message.imageUrl != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              widget.message.imageUrl!,
              width: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 150,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          )
        : const Icon(Icons.image_not_supported, color: Colors.white);
  }

  Widget _buildViewOnceMessage() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.message.viewed ? Icons.visibility_off : Icons.visibility,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          widget.message.viewed ? "Opened" : "Tap to view",
          style: const TextStyle(
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiMessage() {
    return Image.asset(
      EmojiList.getPath(widget.message.text),
      width: 120,
      fit: BoxFit.contain,
    );
  }

  Widget _buildFeedLink() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.message.text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, color: Colors.blueAccent, size: 16),
              SizedBox(width: 8),
              Text(
                "View on Feed",
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
