import 'package:flutter/material.dart';
import 'package:haptext_api/utils/chat_ui/enums.dart';
import 'package:haptext_api/utils/chat_ui/emoji_list.dart';
import 'package:haptext_api/models/chat_ui/message.dart';

class InputArea extends StatefulWidget {
  final ChatMode chatMode;
  final bool autoClearActive;
  final Function(String, {bool isEmoji}) onSendText;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;
  final ValueChanged<String>? onChanged;
  final Message? replyMessage;
  final VoidCallback? onCancelReply;

  const InputArea({
    super.key,
    required this.chatMode,
    this.autoClearActive = false,
    required this.onSendText,
    required this.onStartVoice,
    required this.onStopVoice,
    this.onChanged,
    this.replyMessage,
    this.onCancelReply,
  });

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  bool _showEmojiPicker = false;

  @override
  Widget build(BuildContext context) {
    if (widget.chatMode == ChatMode.callsOnly) {
      return _buildCallsOnlyInput();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyMessage != null) _buildReplyPreview(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(
              top: widget.replyMessage == null
                  ? const Radius.circular(24)
                  : Radius.zero,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showEmojiPicker
                        ? Icons.keyboard
                        : Icons.emoji_emotions_outlined,
                    color: Colors.tealAccent,
                  ),
                  onPressed: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                    });
                    if (_showEmojiPicker) {
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: widget.chatMode == ChatMode.voiceOnly
                        ? _buildVoicePrompt()
                        : TextField(
                            controller: _controller,
                            onTap: () {
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            },
                            onChanged: widget.onChanged,
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                widget.onSendText(val.trim());
                                _controller.clear();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: widget.autoClearActive
                                  ? "Message (auto-clear active)"
                                  : "Type a message...",
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.chatMode != ChatMode.voiceOnly)
                  IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.tealAccent),
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        widget.onSendText(_controller.text);
                        _controller.clear();
                      }
                    },
                  ),
                if (widget.chatMode != ChatMode.textOnly)
                  GestureDetector(
                    onLongPressStart: (_) {
                      setState(() => _isRecording = true);
                      widget.onStartVoice();
                    },
                    onLongPressEnd: (_) async {
                      setState(() => _isRecording = false);
                      widget.onStopVoice();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(_isRecording ? 12 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isRecording
                              ? [Colors.redAccent, Colors.red.shade900]
                              : [Colors.tealAccent, Colors.teal.shade700],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? Colors.red : Colors.teal)
                                .withValues(alpha: 0.4),
                            blurRadius: _isRecording ? 12 : 8,
                            spreadRadius: _isRecording ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none_rounded,
                        color: _isRecording ? Colors.white : Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showEmojiPicker) _buildEmojiPicker(),
      ],
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 280,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: EmojiList.assets.length,
              itemBuilder: (context, index) {
                final assetName = EmojiList.assets[index];
                return InkWell(
                  onTap: () {
                    widget.onSendText(assetName, isEmoji: true);
                  },
                  child: Image.asset(
                    EmojiList.getPath(assetName),
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePrompt() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Text(
        "Hold mic to record voice note",
        style: TextStyle(
            color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCallsOnlyInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).cardColor,
      child: const SafeArea(
        child: Center(
          child: Text(
            "Use the call icons in the app bar to start a call",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.tealAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.replyMessage!.me
                      ? "Replying to yourself"
                      : "Replying to someone",
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyMessage!.isVoice
                      ? "Voice Note"
                      : widget.replyMessage!.text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
