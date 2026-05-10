import 'package:flutter/material.dart';
import 'package:haptext_api/models/posts_model.dart';

class ProfileVideoTab extends StatelessWidget {
  const ProfileVideoTab({super.key, required this.videposts});
  final List<ResultPostModel> videposts;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 1.2,
        mainAxisSpacing: 1.2,
      ),
      itemCount: videposts.length,
      itemBuilder: (BuildContext context, int index) => Container(
        color: Colors.black12,
        child: const Center(
          child:
              Icon(Icons.play_circle_outline, color: Colors.white54, size: 30),
        ),
      ),
    );
  }
}
