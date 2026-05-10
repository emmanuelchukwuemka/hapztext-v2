import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/utils/extensions.dart';

class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  @override
  Widget build(BuildContext context) {
    final watchPeople = context.watch<PeopleCubit>();
    final searchedPeople = watchPeople.searchedUsers;
    final discoverPeople = watchPeople.profiles;
    final size = MediaQuery.sizeOf(context);

    // If search is empty, show discovery list
    final List<dynamic> displayPeople =
        searchedPeople.isNotEmpty ? searchedPeople : discoverPeople;

    return BlocListener<PeopleCubit, PeopleState>(
        listener: (context, state) {
          if (state is PeopleSearched) {
            context.push(RouteName.friendsProfilePage.path, extra: state.user);
          }
        },
        child: Column(
          children: [
            if (searchedPeople.isEmpty && discoverPeople.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: AppText(
                  text: "Discover Recently Joined Patients",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: displayPeople.length,
                itemBuilder: (context, index) {
                  final person = displayPeople[index];
                  // Handle both SearchedUserModel (from search) and SearchedUserProfile (from discover)
                  final String username = ((person is SearchedUserModel
                              ? person.username
                              : (person is SearchedUserProfile
                                  ? person.username
                                  : (person as dynamic).firstName)) as String?)
                          ?.capitalizeFirstChar() ??
                      'User';
                  final String profilePic = person.profilePicture ?? "";
                  final String followers =
                      person.followerCount?.toString() ?? "0";
                  final String following =
                      person.followingCount?.toString() ?? "0";
                  final String mentions = (person is SearchedUserModel
                          ? person.mentionCount?.toString()
                          : "0") ??
                      "0";
                  final String userId = (person is SearchedUserModel
                          ? person.id
                          : (person is SearchedUserProfile
                              ? person.userId
                              : "0")) ??
                      "0";

                  return AppshadowContainer(
                    onTap: () {
                      if (person is SearchedUserProfile) {
                        // For discovery, we might need to fetch full profile or just navigate
                        context.push(RouteName.friendsProfilePage.path,
                            extra: SearchedUserModel(
                              id: person.userId,
                              username: person
                                  .firstName, // Assuming firstName as fallback
                              profilePicture: person.profilePicture,
                              followerCount: person.followerCount,
                              followingCount: person.followingCount,
                              profile: person,
                            ));
                      } else if (person.profile?.firstName == null) {
                        context
                            .read<PeopleCubit>()
                            .fetchUserProfileById(userId: userId);
                      } else {
                        context.push(RouteName.friendsProfilePage.path,
                            extra: person);
                      }
                    },
                    padding: EdgeInsets.all(size.width * 0.04),
                    margin: EdgeInsets.only(bottom: size.width * 0.04),
                    color: Theme.of(context).primaryColorDark,
                    child: Row(children: [
                      AppNetwokImage(
                          height: size.width * 0.1,
                          width: size.width * 0.1,
                          radius: size.width * 0.8,
                          fit: BoxFit.cover,
                          imageUrl: profilePic),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                                text: username,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.people,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 2),
                              AppText(
                                  text:
                                      "$followers Followers • $following Following",
                                  color: Colors.white,
                                  fontSize: 10),
                            ])
                          ]),
                      const Spacer(),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Row(children: [
                              Icon(Icons.favorite, size: 16, color: Colors.red),
                              SizedBox(width: 2),
                              AppText(
                                  text: "3.2k",
                                  color: Colors.white,
                                  fontSize: 12),
                            ]),
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.alternate_email,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 1),
                              AppText(
                                  text: "$mentions Mentions",
                                  color: Colors.white,
                                  fontSize: 12),
                            ])
                          ])
                    ]),
                  );
                },
              ),
            ),
          ],
        ));
  }
}
