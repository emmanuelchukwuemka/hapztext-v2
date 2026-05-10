import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/models/posts_model.dart';
import 'package:haptext_api/exports.dart';
import 'package:go_router/go_router.dart';

class PostTab extends StatefulWidget {
  const PostTab({Key? key}) : super(key: key);

  @override
  State<PostTab> createState() => _PostTabState();
}

class _PostTabState extends State<PostTab> {
  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().fetchPosts(feedType: 'trending');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state is HomeLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = context.read<HomeCubit>().posts.result ?? [];

        if (posts.isEmpty) {
          return const Center(child: Text("No posts found."));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (BuildContext context, int index) {
            final post = posts[index];
            return InkWell(
              onTap: () => context.push(RouteName.innerPost.path, extra: post),
              child: Card(
                margin: const EdgeInsets.only(
                    bottom: 12, left: 8, right: 8, top: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.textContent ?? "",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ReactionIcon(
                              icon: Icons.favorite,
                              label: (post.likeCount ?? 0).toString()),
                          _ReactionIcon(
                              icon: Icons.comment,
                              label: (post.replyCount ?? 0).toString()),
                          _ReactionIcon(
                              icon: Icons.share,
                              label: (post.shareCount ?? 0).toString()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReactionIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReactionIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}
