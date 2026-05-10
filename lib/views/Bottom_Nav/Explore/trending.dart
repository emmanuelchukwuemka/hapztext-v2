import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/views/Bottom_Nav/Explore/explore_carousel.dart';

class Trending extends StatefulWidget {
  const Trending({Key? key}) : super(key: key);

  @override
  State<Trending> createState() => _TrendingState();
}

class _TrendingState extends State<Trending> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      appBar: AppBar(
          backgroundColor: context.theme.appBarColor,
          automaticallyImplyLeading: false,
          iconTheme: IconThemeData(color: context.theme.primaryColor),
          title: AppText(
              text: '  Trending',
              color: context.theme.primaryColor,
              fontWeight: FontWeight.bold)),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final rawPosts = context.read<HomeCubit>().posts.result ?? [];
          final posts = rawPosts
              .where((post) =>
                  post.mediaFiles != null && post.mediaFiles!.isNotEmpty)
              .toList();

          if (posts.isEmpty && state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (posts.isEmpty) {
            return const Center(
                child: AppText(text: 'No trending posts found'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) => SocialPostCard(
                height: 240, isTrending: index < 2, post: posts[index]),
          );
        },
      ),
    );
  }
}
