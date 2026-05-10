import 'dart:developer' as d;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/exports.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

//----- FULL SCREEN FEED ----------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final post = context.watch<HomeCubit>().posts.result;
    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<HomeCubit>().fetchPosts();
        },
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: post?.length ?? 0,
          itemBuilder: (context, index) {
            debugPrint("message ${post?[index].postFormat}");
            return (post?[index].postFormat == "text")
                ? TextPost(post: post?[index] ?? ResultPostModel())
                : (post?[index].postFormat == "audio")
                    ? AudioPost(post: post?[index] ?? ResultPostModel())
                    : (post?[index].postFormat == "video")
                        ? VideoPost(post: post?[index] ?? ResultPostModel())
                        : ImagePost(post: post?[index] ?? ResultPostModel());
          },
        ),
      ),
    );
  }
}

// ---------- POST WRAPPER ----------
class PostWrapper extends StatefulWidget {
  final Widget content;
  final bool overlayHideEnabled;
  final ResultPostModel post;

  const PostWrapper({
    super.key,
    required this.content,
    this.overlayHideEnabled = true,
    required this.post,
  });

  @override
  _PostWrapperState createState() => _PostWrapperState();
}

class _PostWrapperState extends State<PostWrapper>
    with SingleTickerProviderStateMixin {
  bool overlayVisible = true;
  bool showComments = false;
  bool fullScreenMode = false;

  late AnimationController _controller;
  late Animation<double> _shrinkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shrinkAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void toggleOverlay() {
    if (!widget.overlayHideEnabled) return;
    setState(() {
      overlayVisible = !overlayVisible;
    });
  }

  void toggleComments() {
    setState(() {
      showComments = !showComments;
      if (showComments)
        _controller.forward();
      else
        _controller.reverse();
    });
  }

  void toggleFullScreen() {
    setState(() {
      fullScreenMode = !fullScreenMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggleOverlay,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _shrinkAnimation,
            builder: (context, child) {
              return Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: _shrinkAnimation.value,
                  child: widget.content,
                ),
              );
            },
          ),
          // removed tagCount and viewCount overlays as they were mock data
          if (overlayVisible)
            _PostOverlay(
              post: widget.post,
              onCommentTap: toggleComments,
              onFullScreenTap: toggleFullScreen,
            ),
          if (showComments)
            Align(
              alignment: Alignment.bottomCenter,
              child: CommentSection(
                onClose: toggleComments,
                comments: widget.post.comments,
                post: widget.post,
              ),
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

// ---------- COMMENT SECTION ----------
class CommentSection extends StatefulWidget {
  final VoidCallback onClose;
  final List<CommentModel> comments;
  final ResultPostModel post;

  const CommentSection(
      {super.key, required this.onClose, required this.comments, required this.post});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: context.theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  text: 'Comments (${widget.comments.length})',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05)),
          Expanded(
            child: widget.comments.isEmpty
                ? const Center(
                    child: Text("No comments yet",
                        style: TextStyle(color: Colors.white54)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.comments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final comment = widget.comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors
                                  .primaries[i % Colors.primaries.length]
                                  .withValues(alpha: 0.2),
                              child: Text(
                                  (comment.senderUsername?.isNotEmpty == true
                                          ? comment.senderUsername![0]
                                          : 'U')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('@${comment.senderUsername ?? 'user'}',
                                      style: GoogleFonts.roboto(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(comment.textContent ?? '',
                                      style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontSize: 14,
                                          height: 1.4)),
                                  const SizedBox(height: 4),
                                  Text(
                                      comment.createdAt != null
                                          ? 'on ${comment.createdAt!.split('T')[0]}'
                                          : '',
                                      style: const TextStyle(
                                          color: Colors.white24, fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.favorite_border,
                                color: Colors.white24, size: 16),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // COMMENT INPUT BAR
          BlocListener<HomeCubit, HomeState>(
            listener: (context, state) {
              if (state is PostCommented) {
                _commentController.clear();
                context.read<HomeCubit>().fetchPostComents(post: widget.post);
              }
            },
            child: Container(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 12),
              decoration: BoxDecoration(
                  color: context.theme.surfaceColor,
                  border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05)))),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final text = _commentController.text.trim();
                      if (text.isEmpty) return;
                      context.read<HomeCubit>().commentOnPost(
                            post: widget.post,
                            comment: text,
                          );
                    },
                    child: const Icon(Icons.send, color: Color(0xFF8B5CF6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- POST OVERLAY ----------
class _PostOverlay extends StatelessWidget {
  final ResultPostModel post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onFullScreenTap;

  const _PostOverlay({
    this.onCommentTap,
    this.onFullScreenTap,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.2, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF7C3AED)
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  ((post.senderUsername?.isNotEmpty == true)
                                          ? post.senderUsername!
                                          : (post.senderName?.isNotEmpty == true
                                              ? post.senderName!
                                              : 'U'))[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (post.senderUsername?.isNotEmpty == true)
                                      ? post.senderUsername!
                                      : (post.senderName?.isNotEmpty == true
                                          ? post.senderName!
                                          : 'user'),
                                  style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.remove_red_eye_outlined,
                                        color: Colors.white54, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${post.replyCount ?? 0} comments',
                                      style: GoogleFonts.roboto(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FOLLOW',
                                style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (post.textContent?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: AppText(
                              text: post.textContent!,
                              color: Colors.white,
                              maxLines: 3,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // VERTICAL ACTIONS
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          context.read<HomeCubit>().reactToPost(
                                postId: post.id,
                                reaction: 'like', // Default to like for now
                              );
                        },
                        child: _buildVerticalAction(
                            post.currentUserReaction == 'like'
                                ? Icons.favorite
                                : Icons.favorite_border,
                            '${post.likeCount ?? 0}',
                            post.currentUserReaction == 'like'),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          context.push(RouteName.commentpage.path, extra: post);
                        },
                        child: _buildVerticalAction(Icons.chat_bubble,
                            '${post.replyCount ?? 0}', false),
                      ),
                      const SizedBox(height: 20),
                      _buildVerticalAction(Icons.bookmark, 'SAVE', false),
                      const SizedBox(height: 20),
                      _buildVerticalAction(
                          Icons.send, '${post.shareCount ?? 0}', false),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalAction(IconData icon, String label, bool isLiked) {
    return Column(
      children: [
        Icon(icon,
            color: isLiked ? const Color(0xFF8B5CF6) : Colors.white, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.roboto(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ---------- REACTION DIALOG ----------
class ReactionDialog extends StatelessWidget {
  final List<Map<String, String>> reactions = [];

  ReactionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const AppText(
        text: 'People who reacted',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: reactions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final r = reactions[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: Colors
                    .primaries[index % Colors.primaries.length]
                    .withValues(alpha: 0.2),
                child: Text(
                  r['user']![0],
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                r['user']!,
                style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              trailing:
                  Text(r['reaction']!, style: const TextStyle(fontSize: 20)),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Close', style: TextStyle(color: Color(0xFF8B5CF6))),
        ),
      ],
    );
  }
}

// ---------- VIDEO POST ----------
// ---------- VIDEO POST ----------
class VideoPost extends StatefulWidget {
  const VideoPost({super.key, required this.post});
  final ResultPostModel post;

  @override
  State<VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<VideoPost> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() async {
    try {
      final url = widget.post.videoContent;
      if (url != null && url.isNotEmpty && url.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
                _controller.play();
                _controller.setLooping(true);
              });
            }
          }).catchError((e) {
            if (mounted) {
              setState(() {
                _errorMessage = e.toString();
              });
            }
          });
      } else {
        setState(() {
          _errorMessage = "Invalid video URL";
        });
      }
    } catch (e) {
      d.log("video init failed: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PostWrapper(
      post: widget.post,
      content: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Error: $_errorMessage",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
            if (_isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF8B5CF6),
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- IMAGE POST ----------
class ImagePost extends StatefulWidget {
  const ImagePost({super.key, required this.post});
  final ResultPostModel post;

  @override
  State<ImagePost> createState() => _ImagePostState();
}

class _ImagePostState extends State<ImagePost> {
  int _currentIndex = 0;

  // Collect all image URLs from mediaFiles (primary) or fallback to imageContent
  List<String> _getImageUrls() {
    if (widget.post.mediaFiles != null && widget.post.mediaFiles!.isNotEmpty) {
      final urls = widget.post.mediaFiles!
          .where((m) =>
              m.mediaType == 'image' &&
              m.imageFile != null &&
              m.imageFile!.isNotEmpty)
          .map((m) => m.imageFile!)
          .toList();
      if (urls.isNotEmpty) return urls;
    }
    // Fallback to imageContent field
    if (widget.post.imageContent != null &&
        widget.post.imageContent!.isNotEmpty) {
      return [widget.post.imageContent!];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final images = _getImageUrls();

    return PostWrapper(
      post: widget.post,
      content: Container(
        color: Colors.black,
        child: Stack(
          children: [
            if (images.isEmpty)
              const Center(
                child: Icon(Icons.image_not_supported,
                    color: Colors.white24, size: 64),
              )
            else if (images.length == 1)
              Center(
                child: AppNetwokImage(
                  height: size.height,
                  width: size.width,
                  fit: BoxFit.contain,
                  imageUrl: images[0],
                ),
              )
            else
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) => Center(
                  child: AppNetwokImage(
                    height: size.height,
                    width: size.width,
                    fit: BoxFit.contain,
                    imageUrl: images[i],
                  ),
                ),
              ),
            // Multi-image indicator
            if (images.length > 1)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppText(
                    text: '${_currentIndex + 1}/${images.length}',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- AUDIO POST ----------
class AudioPost extends StatefulWidget {
  const AudioPost({super.key, required this.post});
  final ResultPostModel post;
  @override
  AudioPostState createState() => AudioPostState();
}

class AudioPostState extends State<AudioPost>
    with SingleTickerProviderStateMixin {
  bool isPlaying = false;
  late AnimationController _waveController;
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    initAudio();
  }

  void initAudio() async {
    try {
      String? url = widget.post.audioContent;

      if ((url == null || url.isEmpty) && widget.post.mediaFiles != null) {
        for (final media in widget.post.mediaFiles!) {
          if (media.audioFile != null && media.audioFile!.isNotEmpty) {
            url = media.audioFile;
            break;
          }
        }
      }

      if (url != null && url.isNotEmpty) {
        await player.setUrl(url);
      }
    } catch (e) {
      d.log("audio init error: $e");
    }
  }

  void togglePlay() {
    if (!player.playerState.playing) {
      player.play();
      _waveController.repeat(reverse: true);
      setState(() => isPlaying = true);
    } else {
      player.pause();
      _waveController.stop();
      setState(() => isPlaying = false);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PostWrapper(
      post: widget.post,
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF131313),
              context.theme.surfaceColor!,
              const Color(0xFF0A0A0A)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative circles
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          width: 1),
                    ),
                  ),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          width: 1),
                    ),
                  ),
                  GestureDetector(
                    onTap: togglePlay,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFF8B5CF6),
                              blurRadius: 20,
                              spreadRadius: -5)
                        ],
                      ),
                      child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 40,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Waveform(controller: _waveController, isPlaying: isPlaying),
            const SizedBox(height: 20),
            Text(
              'Voice Note Post',
              style: GoogleFonts.roboto(
                  color: Colors.white54, fontSize: 14, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- WAVEFORM ----------
class Waveform extends AnimatedWidget {
  final bool isPlaying;
  Waveform(
      {super.key,
      required Animation<double> controller,
      this.isPlaying = false})
      : super(listenable: controller);
  final Random _rnd = Random(42); // Seed for consistency

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(32, (index) {
        double baseH = 8.0 + (index % 5) * 4;
        double h = isPlaying ? (baseH + animation.value * 20) : baseH;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ---------- TEXT POST ----------
class TextPost extends StatefulWidget {
  const TextPost({super.key, required this.post});
  final ResultPostModel post;
  @override
  State<TextPost> createState() => _TextPostState();
}

class _TextPostState extends State<TextPost> {
  @override
  Widget build(BuildContext context) {
    final isLiked = widget.post.currentUserReaction == 'like';
    return PostWrapper(
      post: widget.post,
      overlayHideEnabled: false,
      content: Container(
        color: context.theme.bgColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.theme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: AppText(
                  text: widget.post.textContent ?? '',
                  textAlign: TextAlign.center,
                  color: Colors.white,
                  maxLines: 10,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // FOOTER INFO
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        text:
                            '@${(widget.post.senderUsername?.isNotEmpty == true) ? widget.post.senderUsername : (widget.post.senderName?.isNotEmpty == true ? widget.post.senderName : 'user')}',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        text: '${widget.post.replyCount ?? 0} comments',
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.more_vert, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 24),
              // ACTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionItem(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    '${widget.post.likeCount ?? 0}',
                    isLiked,
                    () {
                      context.read<HomeCubit>().reactToPost(
                            postId: widget.post.id,
                            reaction: 'like',
                          );
                    },
                  ),
                  _buildActionItem(
                    Icons.chat_bubble_outline,
                    '${widget.post.replyCount ?? 0}',
                    false,
                    () => context.push(RouteName.commentpage.path,
                        extra: widget.post),
                  ),
                  _buildActionItem(
                    Icons.bookmark_border,
                    'Save',
                    false,
                    () {},
                  ),
                  _buildActionItem(
                    Icons.send_outlined,
                    '${widget.post.shareCount ?? 0}',
                    false,
                    () => context
                        .read<HomeCubit>()
                        .sharePost(postId: widget.post.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? const Color(0xFF8B5CF6) : Colors.white,
                size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.roboto(
                  color:
                      active ? const Color(0xFF8B5CF6) : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
