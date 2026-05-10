import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/models/searched_user_model.dart';
import 'package:haptext_api/utils/extensions.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:haptext_api/exports.dart';

class Followings extends StatefulWidget {
  const Followings({super.key});

  @override
  State<Followings> createState() => _FollowingsState();
}

class _FollowingsState extends State<Followings> {
  @override
  Widget build(BuildContext context) {
    final followings = context.watch<PeopleCubit>().followings;
    return Column(
      children: [
        // SEARCH CONTAINER
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            height: 48.0,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 12.0),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search followings...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_outlined,
                      color: Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
        ),
        // CONTENT
        followings.isEmpty
            ? const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      AppText(
                        text: 'Not following anyone yet',
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 8),
                      AppText(
                        text: 'Explore and connect with peers!',
                        color: Colors.white24,
                        fontSize: 14,
                      ),
                    ],
                  ),
                ),
              )
            : Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: followings.length,
                    itemBuilder: (context, index) {
                      final userProfile = followings[index];
                      // Create a SearchedUserModel from the SearchedUserProfile data
                      final userModel = SearchedUserModel(
                        id: userProfile.id,
                        username:
                            "${userProfile.firstName ?? ""} ${userProfile.lastName ?? ""}"
                                .trim(),
                        profilePicture: userProfile.profilePicture,
                        profile: userProfile,
                      );
                      return friendCardWidget(
                        context,
                        "${userProfile.lastName ?? ""} ${userProfile.firstName ?? ""}"
                            .trim(),
                        userProfile.profilePicture ??
                            'assets/images/placeholder.jpg',
                        user: userModel,
                      );
                    },
                  ),
                ),
              ),
      ],
    );
  }
}
