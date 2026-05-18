import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/exports.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

class CommentScreen extends StatefulWidget {
  final ResultPostModel post;
  const CommentScreen({super.key, required this.post});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen>
    with SingleTickerProviderStateMixin {
  // Caption & comments
  bool _showFullCaption = false;

  // Video & Audio
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isVideoInitialized = false;
  bool _isAudioPlaying = false;
  String? _videoErrorMessage;

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().fetchPostComents(post: widget.post);
    _initMedia();
  }

  void _initMedia() async {
    if (widget.post.postFormat == 'video' && widget.post.videoContent != null) {
      final url = widget.post.videoContent!;
      if (url.isNotEmpty && url.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isVideoInitialized = true;
              });
            }
          }).catchError((e) {
            if (mounted) {
              setState(() {
                _videoErrorMessage = e.toString();
              });
            }
          });
      }
    } else if (widget.post.postFormat == 'audio' &&
        widget.post.audioContent != null) {
      await _audioPlayer.setUrl(widget.post.audioContent!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildPostMedia() {
    final size = MediaQuery.sizeOf(context);
    if (widget.post.postFormat == 'image' && widget.post.imageContent != null) {
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: size.height * 0.4),
        child: AppNetwokImage(
          height: size.height * 0.4,
          width: double.infinity,
          imageUrl: widget.post.imageContent!,
          fit: BoxFit.contain,
        ),
      );
    } else if (widget.post.postFormat == 'video' && _videoController != null) {
      return Container(
        width: double.infinity,
        height: size.height * 0.4,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_videoErrorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Error: $_videoErrorMessage",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_isVideoInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            else
              const CircularProgressIndicator(color: Colors.cyanAccent),
            if (_isVideoInitialized && _videoErrorMessage == null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
                child: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 50,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      );
    } else if (widget.post.postFormat == 'audio') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.voice_chat, size: 40, color: Colors.cyanAccent),
            const SizedBox(height: 12),
            IconButton(
              icon: Icon(
                _isAudioPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 48,
                color: Colors.cyanAccent,
              ),
              onPressed: () async {
                if (_isAudioPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play();
                }
                setState(() => _isAudioPlaying = !_isAudioPlaying);
              },
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Toggle reaction for a comment by current user

  // Reply tracking: which comment we're replying to (may be nested)
  CommentModel? _replyTo;

  // Input controller and focus
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // Floating reaction animations
  final List<_FloatingEmoji> _floatingEmojis = [];

  // For simplicity, use small emoji set
  final List<String> _emojiSet = ['👍', '❤️', '😂', '🔥', '👏', '😮'];

  // Scroll controller for comments (keeps viewport stable)
  final ScrollController _scrollController = ScrollController();

  // Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // Toggle reaction for a comment by current user
  void _toggleReaction(CommentModel comment, String reaction) {
    context.read<HomeCubit>().reactToPost(
          postId: comment.id,
          reaction: reaction,
        );
  }

  void _toggleBookmark(CommentModel c) {
    setState(() {});
  }

  // Show who reacted (bottom sheet)
  void _showWhoReacted(CommentModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) {
        return SizedBox(
          height: min(360, 60 + 2 * 64),
          child: Column(
            children: [
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Reactions',
                      style: TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w700))),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView.separated(
                  itemCount: 2,
                  separatorBuilder: (BuildContext context, _) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: _avatarColorFor("${i}"),
                          child: AppText(text: "U", color: Colors.white)),
                      title: const AppText(text: "User", color: Colors.white),
                      trailing: const AppText(text: "👍", fontSize: 20),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Color _avatarColorFor(String name) {
    final h = name.hashCode;
    return Colors.primaries[h.abs() % Colors.primaries.length];
  }

  // spawn a subtle floating emoji for visual feedback
  void _spawnFloatingEmoji(String emoji) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fe = _FloatingEmoji(id: id, emoji: emoji);
    setState(() => _floatingEmojis.add(fe));
    Future.delayed(const Duration(milliseconds: 1400), () {
      setState(() => _floatingEmojis.removeWhere((e) => e.id == id));
    });
  }

  // Start reply: set target and keep input stable (no jumping)
  void _startReply(CommentModel target) {
    setState(() {
      _replyTo = target;
      FocusScope.of(context).requestFocus(_inputFocus);
    });
  }

  // Audio recording logic
  void _toggleRecording() {
    if (_isRecording) {
      _stopAndSendRecording();
    } else {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Microphone permission is required to record voice notes')),
          );
        }
        return;
      }

      if (await _audioRecorder.hasPermission()) {
        String? filePath;

        final Directory appDir = await getApplicationDocumentsDirectory();
        filePath =
            '${appDir.path}/comment_vn_${DateTime.now().millisecondsSinceEpoch}.m4a';

        _currentRecordingPath = filePath;

        await _audioRecorder.start(const RecordConfig(), path: filePath);

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
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      _recordTimer?.cancel();
      final String? path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
      });

      if (path != null) {
        // Send the recording
        if (mounted) {
          context.read<HomeCubit>().commentOnPost(
                postId: _replyTo?.id ?? "",
                post: _replyTo != null ? null : widget.post,
                audioFile: File(path),
              );
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordTimer?.cancel();
      await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording cancelled')),
        );
      }
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // Build a comment tile recursively
  Widget _buildCommentTile({int depth = 0, required CommentModel comment}) {
    final indent = depth * 12.0;
    // final reactionsCount =
    //     c.reactions.entries.fold<int>(0, (p, e) => p + e.value.length);

    // final showAllReplies = _expandedReplyParents.contains(c.id);
    // final replyCount = c.replies.length;
    // final shownReplies =
    //     showAllReplies ? c.replies : c.replies.take(2).toList();

    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8, bottom: 8, right: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: _avatarColorFor("${comment.senderUsername}"),
              child: AppText(
                  text: comment.senderUsername?[0] ?? "0",
                  color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AppText(
                    text: comment.senderUsername ?? '',
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                const SizedBox(width: 8),
                AppText(
                    text:
                        '· ${_formatTime(DateTime.parse(comment.updatedAt ?? DateTime.now().toString()))}',
                    color: Colors.white54,
                    fontSize: 12),
              ]),
              const SizedBox(height: 6),
              // content
              comment.postFormat == 'audio' || (comment.audioContent != null && comment.audioContent!.isNotEmpty)
                  ? CommentVoicePlayer(audioUrl: comment.audioContent!)
                  : _buildContentWithMentions(comment.textContent ?? ''),
              const SizedBox(height: 8),
              // actions: reactions preview, reply, bookmark, open emoji picker
              Row(children: [
                if ((comment.reactionsCount ?? 0) > 0)
                  GestureDetector(
                    onTap: () => _showWhoReacted(comment),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(24)),
                      child: Row(children: [
                        Text(
                          comment.currentUserReaction ?? '👍',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        AppText(
                            text: '${comment.reactionsCount}',
                            color: Colors.white70,
                            fontSize: 12),
                      ]),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: () => _startReply(comment),
                    child:
                        const AppText(text: 'Reply', color: Colors.cyanAccent)),
                IconButton(
                    onPressed: () => _toggleBookmark(comment),
                    icon: const Icon(
                        // c.bookmarked ? Icons.star :
                        Icons.star_border,
                        color: Colors.yellowAccent)),
                IconButton(
                    // onPressed: () {},
                    onPressed: () => _openEmojiPickerFor(comment),
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white70)),
              ])
            ]),
          )
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 44.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (comment.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comment.replies
                      .map((r) =>
                          _buildCommentTile(depth: depth + 1, comment: r))
                      .toList(),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // Render content but highlight @mentions (simple highlight for '@Name ')
  Widget _buildContentWithMentions(String content) {
    final parts = <InlineSpan>[];
    final regex = RegExp(r'@[\w]+');
    int last = 0;
    for (final match in regex.allMatches(content)) {
      if (match.start > last) {
        parts.add(TextSpan(
            text: content.substring(last, match.start),
            style: const TextStyle(color: Colors.white)));
      }
      final mention = match.group(0)!;
      parts.add(TextSpan(
          text: mention,
          style: const TextStyle(
              color: Colors.cyanAccent, fontWeight: FontWeight.w600)));
      last = match.end;
    }
    if (last < content.length) {
      parts.add(TextSpan(
          text: content.substring(last),
          style: const TextStyle(color: Colors.white)));
    }
    return RichText(text: TextSpan(children: parts));
  }

  // Emoji picker for a specific comment
  void _openEmojiPickerFor(CommentModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojiSet.map((e) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(e, style: const TextStyle(fontSize: 22))),
                );
              }).toList()),
        );
      },
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final watchHome = context.watch<HomeCubit>();
    final readHome = context.read<HomeCubit>();
    final size = MediaQuery.sizeOf(context);

    // dynamic bottom area height so list padding matches actual space used
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<HomeCubit, HomeState>(
      listener: (context, state) {
        if (state is PostCommented) {
          _textController.clear();
          setState(() => _replyTo = null);
          readHome.fetchPostComents(post: widget.post);
        }
        if (state is PostReact) {
          readHome.fetchPostComents(post: widget.post);
        }
      },
      child: Scaffold(
        // resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF0F0F10),
        appBar: AppBar(
            title: const AppText(
                text: 'Comments', fontSize: 18, color: Colors.white),
            backgroundColor: Colors.black,
            elevation: 0.5),
        body: SafeArea(
          child: Column(children: [
            _buildPostMedia(),
            // Caption card (poster avatar, caption, See more toggle, comment count)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Card(
                color: const Color(0xFF141416),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                  backgroundColor: Colors.deepPurple,
                                  child: AppText(
                                      text:
                                          '${widget.post.senderName?.substring(0, 1)}',
                                      color: Colors.white)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                          text: widget.post.senderName ?? "",
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            _showFullCaption =
                                                !_showFullCaption),
                                        child: AppText(
                                            text: widget.post.textContent ?? "",
                                            maxLines: _showFullCaption ? 2 : 10,
                                            color: Colors.white70),
                                      ),
                                    ]),
                              ),
                            ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          AppText(
                              text: '${widget.post.comments.length} comments',
                              color: Colors.white54),
                          const SizedBox(width: 12),
                          InkWell(
                              onTap: () => setState(
                                  () => _showFullCaption = !_showFullCaption),
                              child: AppText(
                                  text: _showFullCaption
                                      ? 'See less'
                                      : 'See more',
                                  color: Colors.cyanAccent)),
                        ]),
                      ]),
                ),
              ),
            ),
            // Comments list

            Expanded(
                child: ListView(children: [
              Column(
                  children: List.generate(
                      widget.post.comments.length,
                      (i) =>
                          _buildCommentTile(comment: widget.post.comments[i]))),
              // Floating emoji widgets
              ..._floatingEmojis.map((f) => _FloatingEmojiWidget(data: f)),
              // // Mention overlay (above keyboard / input) - show when typing @
              // if (_showMentionList && _mentionResults.isNotEmpty)
              //   Card(
              //     color: const Color(0xFF1A1A1C),
              //     shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(10)),
              //     child: ConstrainedBox(
              //       constraints: const BoxConstraints(maxHeight: 180),
              //       child: ListView.separated(
              //         shrinkWrap: true,
              //         itemCount: _mentionResults.length,
              //         separatorBuilder: (BuildContext context, _) =>
              //             const Divider(height: 1, color: Colors.white10),
              //         itemBuilder: (_, i) {
              //           final f = _mentionResults[i];
              //           return ListTile(
              //             leading: CircleAvatar(
              //                 backgroundColor: f.color,
              //                 child: Text(f.name[0],
              //                     style: const TextStyle(
              //                         color: Colors.white))),
              //             title: Text(f.name,
              //                 style: const TextStyle(color: Colors.white)),
              //             onTap: () => _insertMention(f),
              //           );
              //         },
              //       ),
              //     ),
              //   ),
              // // Bottom input panel (fixed) with reply indicator and stable layout
            ])),
            Container(
                color: const Color(0xFF0B0B0C),
                padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 10,
                    bottom: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Reply-to banner (if replying)
                  if (_replyTo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                'Replying to ${_replyTo?.senderUsername ?? ''}',
                                style:
                                    const TextStyle(color: Colors.cyanAccent))),
                        GestureDetector(
                            onTap: () => setState(() => _replyTo = null),
                            child:
                                const Icon(Icons.close, color: Colors.white70)),
                      ]),
                    ),

                  if (_replyTo != null) const SizedBox(height: 8),
                  Row(children: [
                    if (_isRecording)
                      Expanded(
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.red, size: 12),
                              const SizedBox(width: 8),
                              AppText(
                                  text: _formatDuration(_recordDuration),
                                  color: Colors.white,
                                  fontSize: 14),
                              const Spacer(),
                              GestureDetector(
                                onTap: _cancelRecording,
                                child: const AppText(
                                    text: "Cancel",
                                    color: Colors.red,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // mic button
                      InkWell(
                        onTap: _toggleRecording,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: const Color(0xFF161616),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.mic,
                                color: Colors.cyanAccent)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller: _textController,
                              focusNode: _inputFocus,
                              maxLines: null,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  hintText: _replyTo != null
                                      ? 'Reply to ${_replyTo?.senderUsername ?? ''}…'
                                      : 'Add a comment',
                                  hintStyle:
                                      const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF161616),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none)),
                              onSubmitted: (_) {})),
                    ],
                    const SizedBox(width: 8),
                    // quick emoji chooser / send
                    if (!_isRecording)
                      IconButton(
                          onPressed: () => _openQuickEmojiPicker(),
                          icon: const Icon(Icons.emoji_emotions_outlined,
                              color: Colors.white70)),
                    if (_isRecording)
                      IconButton(
                        onPressed: _stopAndSendRecording,
                        icon: const Icon(Icons.send, color: Colors.cyanAccent),
                      )
                    else
                      watchHome.state is PostCommenting
                          ? Padding(
                              padding:
                                  EdgeInsets.only(right: size.width * 0.02),
                              child: LoadingAnimationWidget.inkDrop(
                                  color: Theme.of(context).primaryColor,
                                  size: 20))
                          : IconButton(
                              onPressed: () {
                                final text = _textController.text.trim();
                                if (text.isEmpty) return;
                                if (_replyTo != null) {
                                  // Replying to a comment — post as reply to the parent POST
                                  readHome.commentOnPost(
                                      postId: widget.post.id ?? '',
                                      comment: '@${_replyTo!.senderUsername ?? ''} $text');
                                } else {
                                  // Top-level comment on the post
                                  readHome.commentOnPost(
                                      post: widget.post,
                                      comment: text);
                                }
                              },
                              icon: const Icon(Icons.send,
                                  color: Colors.cyanAccent)),
                  ]),
                ])),
          ]),
        ),
      ),
    );
  }

  // quick emoji sheet (applies to reply target if present, otherwise inserts character)
  void _openQuickEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojiSet.map((e) {
                return GestureDetector(
                  onTap: () {
                    if (_replyTo != null) {
                      _toggleReaction(_replyTo!, e);
                      _spawnFloatingEmoji(e);
                      Navigator.pop(context);
                    } else {
                      setState(() =>
                          _textController.text = _textController.text + e);
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(e, style: const TextStyle(fontSize: 22))),
                );
              }).toList()),
        );
      },
    );
  }
}

/// Floating emoji descriptor
class _FloatingEmoji {
  final String id;
  final String emoji;
  double bottom;
  double left;
  _FloatingEmoji({required this.id, required this.emoji})
      : bottom = 24 + Random().nextDouble() * 30,
        left = 40 + Random().nextDouble() * 200;
}

/// Floating emoji widget (subtle float + fade)
class _FloatingEmojiWidget extends StatefulWidget {
  final _FloatingEmoji data;
  const _FloatingEmojiWidget({required this.data, Key? key}) : super(key: key);

  @override
  State<_FloatingEmojiWidget> createState() => _FloatingEmojiWidgetState();
}

class _FloatingEmojiWidgetState extends State<_FloatingEmojiWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _dy;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _dy = Tween<double>(begin: 0, end: -60)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startLeft = widget.data.left;
    final startBottom = widget.data.bottom;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, ch) {
        return Positioned(
          left: startLeft,
          bottom: startBottom + _dy.value,
          child: Opacity(
              opacity: _opacity.value,
              child: Text(widget.data.emoji,
                  style: const TextStyle(fontSize: 28))),
        );
      },
    );
  }
}

class CommentVoicePlayer extends StatefulWidget {
  final String audioUrl;
  const CommentVoicePlayer({super.key, required this.audioUrl});

  @override
  State<CommentVoicePlayer> createState() => _CommentVoicePlayerState();
}

class _CommentVoicePlayerState extends State<CommentVoicePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);
      if (!mounted) return;
      _player.durationStream.listen((d) {
        if (mounted && d != null) {
          setState(() {
            _duration = d;
            _isInitialized = true;
          });
        }
      });
      _player.positionStream.listen((p) {
        if (mounted) {
          setState(() {
            _position = p;
          });
        }
      });
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
    } catch (e) {
      print("Error loading voice note: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (!_isInitialized) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position >= _duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: _isPlaying ? Colors.cyanAccent : Colors.white24,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: _isPlaying ? Colors.black : Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Pulsing Sound Wave / Slider
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.cyanAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.cyanAccent,
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds > 0
                    ? _duration.inSeconds.toDouble()
                    : 1.0,
                onChanged: (val) async {
                  if (_isInitialized) {
                    await _player.seek(Duration(seconds: val.toInt()));
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isPlaying
                ? "${_formatDuration(_position)} / ${_formatDuration(_duration)}"
                : _formatDuration(_duration),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

