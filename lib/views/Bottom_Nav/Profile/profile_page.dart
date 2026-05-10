// ignore_for_file: use_build_context_synchronously

import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/bloc/profile/cubit/profile_cubit.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/network/export_network.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  static const routeName = '/profile-screen';

  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  int current = 0;
  late TabController tabController;
  List<ResultPostModel> userPosts = [];

  Future<dynamic> _showOptionsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () {},
            child: Center(
              child: AppText(
                  text: context.read<AuthCubit>().useInfo.profile?.bio ??
                      'No bio available',
                  fontSize: 15,
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  List<String> items = [
    "Pictures",
    "Videos",
    "Texts",
    "Audios",
    // "Downloads",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<PeopleCubit>().fetchUserProfileById(
          userId: context.read<AuthCubit>().useInfo.id ?? '',
          loggedInUser: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final user = context.watch<AuthCubit>().useInfo;
    final primaryGradient = const LinearGradient(
        colors: [Coloors.primaryStart, Coloors.primaryEnd]);
    final theme = Theme.of(context).extension<CustomThemeExtension>();

    return Scaffold(
      backgroundColor: theme?.bgColor ?? Coloors.darkBackground,
      body: MultiBlocListener(
        listeners: [
          BlocListener<PeopleCubit, PeopleState>(
            listener: (context, state) {
              if (state is CurrentUser) {
                setState(() {
                  user.profile = state.user;
                });
              }
            },
          ),
          BlocListener<ProfileCubit, ProfileState>(
            listener: (context, state) {
              if (state is ProfileUpdated) {
                final shouldWarn =
                    state.warnings != null && state.warnings!.isNotEmpty;
                if (shouldWarn) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ToastMessage.showWarningToast(
                        message:
                            'Image upload blocked. Fix Storage policies, then try again.');
                  });
                }
                if (state.profile != null) {
                  setState(() {
                    user.profile = state.profile;
                  });
                } else {
                  context.read<PeopleCubit>().fetchUserProfileById(
                      userId: user.id ?? '', loggedInUser: true);
                }
              }
            },
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<PeopleCubit>().fetchUserProfileById(
                userId: user.id ?? '', loggedInUser: true);
            userPosts = await context
                    .read<HomeCubit>()
                    .fetchUserPosts(userId: user.id ?? "") ??
                [];
          },
          child: CustomScrollView(
            slivers: [
              // 1. Dynamic AppBar
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                backgroundColor: theme?.bgColor ?? Coloors.darkBackground,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner Gradient Background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Coloors.primaryStart.withOpacity(0.8),
                              Coloors.primaryEnd.withOpacity(0.4),
                              Coloors.background,
                            ],
                          ),
                        ),
                      ),
                      // Cover picture
                      if (user.profile?.coverPicture != null &&
                          user.profile!.coverPicture!.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(
                            user.profile!.coverPicture!,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        // Backdrop image if available (using profile pic as placeholder)
                        Opacity(
                          opacity: 0.3,
                          child: AppNetwokImage(
                            height: 240,
                            width: size.width,
                            imageUrl: user.profile?.profilePicture ?? "",
                            fit: BoxFit.cover,
                          ),
                        ),
                      // Overlay for name/username inside flexible space
                      Positioned(
                        bottom: 40,
                        left: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              text:
                                  "${user.profile?.firstName ?? ''} ${user.profile?.lastName ?? ''}",
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            AppText(
                              text: "@${user.username}",
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon:
                        const Icon(Icons.logout_outlined, color: Colors.white),
                    onPressed: () async {
                      await context.read<AuthCubit>().logout();
                      await context.read<AuthProvider>().logout();
                      context.go(RouteName.login.path);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // 2. Profile Info Section
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -30, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overlapping Avatar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      theme?.bgColor ?? Coloors.darkBackground,
                                  width: 4),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4))
                              ],
                            ),
                            child: AppNetwokImage(
                              width: 90,
                              height: 90,
                              radius: 45,
                              fit: BoxFit.cover,
                              imageUrl: user.profile?.profilePicture ?? "",
                            ),
                          ),
                          // Edit Button
                          GestureDetector(
                            onTap: () =>
                                context.push(RouteName.editProfile.path),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Edit Profile",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bio
                      if (user.profile?.bio?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            user.profile?.bio ?? '',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5),
                          ),
                        ),

                      // Location/Info Badges
                      Row(
                        children: [
                          _infoBadge(Icons.location_on_outlined,
                              user.profile?.location ?? "Global"),
                          const SizedBox(width: 16),
                          _infoBadge(Icons.calendar_month_outlined,
                              "Joined ${user.profile?.createdAt != null ? user.profile!.createdAt!.split('T')[0] : 'Recently'}"),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Stats Row
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme?.surfaceColor ?? Coloors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(
                                "${user.profile?.postCount ?? 0}", "Posts"),
                            _statDivider(),
                            _statItem("${user.profile?.followerCount ?? 0}",
                                "Followers"),
                            _statDivider(),
                            _statItem("${user.profile?.followingCount ?? 0}",
                                "Following"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 3. Sticky Tabs Indicator
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  child: Container(
                    color: theme?.bgColor ?? Coloors.darkBackground,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(items.length, (index) {
                          bool isActive = current == index;
                          return GestureDetector(
                            onTap: () => setState(() => current = index),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  items[index],
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white38,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 3,
                                  width: isActive ? 40 : 0,
                                  decoration: BoxDecoration(
                                    gradient: primaryGradient,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Content Grid
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildTabContent(user),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _statItem(String count, String label) {
    return Column(
      children: [
        Text(count,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _statDivider() {
    return Container(height: 30, width: 1, color: Colors.white10);
  }

  Widget _buildTabContent(user) {
    if (current == 0) {
      return Tab1(
          photoPosts: userPosts.where((e) => e.postFormat == 'image').toList());
    } else if (current == 1) {
      return ProfileVideoTab(
          videposts: userPosts.where((e) => e.postFormat == 'video').toList());
    } else if (current == 2) {
      return ProfileTextTab(
          textPosts: userPosts.where((e) => e.postFormat == 'text').toList());
    } else {
      return ProfileAudioTab(
          audioPosts: userPosts.where((e) => e.postFormat == 'audio').toList());
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 60; // Increased slightly to provide more headroom
  @override
  double get maxExtent => 60;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
