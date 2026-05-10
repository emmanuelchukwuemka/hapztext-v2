import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

class ExploreCarousel extends StatefulWidget {
  final String title;
  final int tabIndex;
  const ExploreCarousel({Key? key, required this.title, required this.tabIndex})
      : super(key: key);

  @override
  State<ExploreCarousel> createState() => _ExploreCarouselState();
}

class _ExploreCarouselState extends State<ExploreCarousel> {
  @override
  Widget build(BuildContext context) {
    final watchHome = context.watch<HomeCubit>();
    Iterable<ResultPostModel> rawPosts = [];

    if (widget.title == "Trending") {
      rawPosts = watchHome.trendingPosts.result ?? [];
    } else if (widget.title == "Most Liked") {
      rawPosts = watchHome.popularPosts.result ?? [];
    } else {
      rawPosts = watchHome.posts.result ?? [];
    }

    // Only show posts that have an actual media upload (image or video)
    final List<ResultPostModel> posts = rawPosts
        .where((post) => post.mediaFiles != null && post.mediaFiles!.isNotEmpty)
        .toList();

    if (posts.isEmpty && watchHome.state is HomeLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (posts.isEmpty) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            AppText(
                text: widget.title,
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
            GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const Trending()));
                },
                child: AppText(
                    text: "See more",
                    color: context.theme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600))
          ]),
          const SizedBox(height: 12),
          MasonryGridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: posts.length > 9 ? 9 : posts.length,
            itemBuilder: (context, index) {
              // Simulate different heights for masonry effect
              double height = (index % 3 == 0)
                  ? 180
                  : (index % 3 == 1)
                      ? 240
                      : 150;
              return SocialPostCard(
                height: height,
                isTrending: index == 0,
                post: posts[index],
              );
            },
          ),
          const SizedBox(height: 24)
        ],
      ),
    );
  }
}

class SocialPostCard extends StatelessWidget {
  final double height;
  final bool isTrending;
  final ResultPostModel? post;

  const SocialPostCard(
      {super.key, required this.height, this.isTrending = false, this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (post != null) {
          context.push(RouteName.innerPost.path, extra: post);
        }
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 1. Media Display
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.05),
                  child:
                      post?.mediaFiles != null && post!.mediaFiles!.isNotEmpty
                          ? AppNetwokImage(
                              height: height,
                              width: double.infinity,
                              imageUrl: post!.mediaFiles!.first.imageFile ??
                                  post!.mediaFiles!.first.videoFile ??
                                  "",
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Icon(
                                post?.postFormat == 'video'
                                    ? Icons.play_circle_outline
                                    : Icons.image_outlined,
                                color: Colors.white24,
                                size: 30,
                              ),
                            ),
                ),
              ),

              // 2. Trending Badge
              if (isTrending)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "TRENDING",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 3. Metrics Overlay & Gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MetricItem(
                            icon: post?.currentUserReaction != null
                                ? Icons.favorite
                                : Icons.favorite_border,
                            count:
                                "${post?.replyCount ?? 0}", // Assuming replyCount or likes? The model doesn't have likeCount directly but has currentUserReaction
                            color: post?.currentUserReaction != null
                                ? Colors.red
                                : Colors.white,
                            onTap: () {
                              if (post?.id != null) {
                                context.read<HomeCubit>().reactToPost(
                                    postId: post!.id, reaction: 'like');
                              }
                            },
                          ),
                          _MetricItem(
                            icon: Icons.repeat,
                            count: "${post?.shareCount ?? 0}",
                            onTap: () {
                              if (post?.id != null) {
                                context
                                    .read<HomeCubit>()
                                    .sharePost(postId: post!.id);
                              }
                            },
                          ),
                          _MetricItem(
                            icon: Icons.chat_bubble_outline,
                            count: "${post?.replyCount ?? 0}",
                            onTap: () {
                              if (post != null) {
                                context.push(RouteName.innerPost.path,
                                    extra: post);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String count;
  final Color color;
  final VoidCallback? onTap;

  const _MetricItem(
      {required this.icon,
      required this.count,
      this.color = Colors.white,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
