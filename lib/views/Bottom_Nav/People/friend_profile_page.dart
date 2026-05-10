import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:haptext_api/bloc/home/cubit/home_cubit.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:haptext_api/models/searched_user_model.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/config/page_route/route_name.dart';

class FriendProfilePage extends StatefulWidget {
  final SearchedUserModel user;

  const FriendProfilePage({super.key, required this.user});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  late bool _isFollowing;

  @override
  void initState() {
    _isFollowing = widget.user.following;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final posts = await context
          .read<HomeCubit>()
          .fetchUserPosts(userId: widget.user.id ?? '');
      if (posts != null && mounted) {
        setState(() {
          widget.user.userPhotoPost =
              posts.where((e) => e.postFormat == "photo").toList();
          widget.user.userTextPost =
              posts.where((e) => e.postFormat == "text").toList();
          // Fixed potential copy-paste error in previous logic
          widget.user.userAudioPost =
              posts.where((e) => e.postFormat == "audio").toList();
          widget.user.userVideoPost =
              posts.where((e) => e.postFormat == "video").toList();
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      body: CustomScrollView(
        slivers: [
          // PROFESSIONAL HEADER
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: context.theme.bgColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // BANNER
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // AVATAR OVERLAP
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.theme.bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            NetworkImage(widget.user.profilePicture ?? ''),
                        backgroundColor: context.theme.surfaceColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // USERNAME & BIO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "@${widget.user.username ?? ''}",
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user.profile?.bio ?? 'No bio yet',
                            style: GoogleFonts.roboto(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      // ACTION BUTTONS
                      Row(
                        children: [
                          _buildActionButton(
                            icon: _isFollowing
                                ? Icons.person_remove
                                : Icons.person_add,
                            color: _isFollowing
                                ? Colors.white12
                                : const Color(0xFF8B5CF6),
                            onTap: () {
                              if (_isFollowing) {
                                context
                                    .read<PeopleCubit>()
                                    .unfollowUser(userId: widget.user.id ?? '');
                                setState(() {
                                  _isFollowing = false;
                                });
                              } else {
                                context
                                    .read<PeopleCubit>()
                                    .followUser(userId: widget.user.id ?? '');
                                setState(() {
                                  _isFollowing = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildActionButton(
                            icon: Icons.chat_bubble_outline,
                            color: Colors.white12,
                            onTap: () async {
                              final HapzTextApiService apiService =
                                  HapzTextApiService();
                              final authCubit = context.read<AuthCubit>();
                              final token = authCubit.useInfo.tokens?.auth;
                              final currentUserId = authCubit.useInfo.id;
                              final otherUserId = widget.user.id;
                              if (token != null &&
                                  currentUserId != null &&
                                  otherUserId != null) {
                                apiService.setToken(token);
                                final result =
                                    await apiService.createConversation([
                                  currentUserId,
                                  otherUserId,
                                ]);
                                if (result != null && result['data'] != null) {
                                  final conv = result['data'];
                                  final chatItem = ChatItem(
                                    id: conv['id'].toString(),
                                    name: widget.user.username ?? 'User',
                                    lastMessage: '',
                                    chatMode: ChatMode.mixed,
                                  );
                                  context.push('/chat-screen', extra: chatItem);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // STATS BAR
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: context.theme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Posts', '124'),
                        _buildStat(
                            'Followers', '${widget.user.followerCount ?? 0}'),
                        _buildStat(
                            'Following', '${widget.user.followingCount ?? 0}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ABOUT SECTION
                  Text(
                    'About',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailCard([
                    _buildDetailRow(Icons.person_outline, 'Name',
                        "${widget.user.profile?.firstName ?? ""} ${widget.user.profile?.lastName ?? ""}"),
                    _buildDetailRow(Icons.work_outline, 'Occupation',
                        widget.user.profile?.occupation ?? "Unspecified"),
                    _buildDetailRow(Icons.cake_outlined, 'Birthday',
                        widget.user.profile?.birthDate ?? "Unspecified"),
                    _buildDetailRow(Icons.location_on_outlined, 'Location',
                        widget.user.profile?.location ?? "Unspecified"),
                    _buildDetailRow(
                        Icons.favorite_border,
                        'Relationship',
                        widget.user.profile?.relationshipStatus ??
                            "Unspecified"),
                  ]),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.roboto(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.roboto(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.roboto(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
