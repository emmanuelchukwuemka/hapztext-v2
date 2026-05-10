import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/views/Bottom_Nav/People/follower.dart';
import 'package:haptext_api/views/Bottom_Nav/People/followings.dart';
import 'package:haptext_api/views/Bottom_Nav/People/friend.dart';
import 'package:haptext_api/widgets/app_text.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.theme.bgColor,
        appBar: AppBar(
          backgroundColor: context.theme.bgColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: AppText(
            text: 'Social Network',
            fontSize: 22,
            color: context.theme.titleTextColor,
            fontWeight: FontWeight.bold,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: TabBar(
                onTap: (value) {
                  final cubit = context.read<PeopleCubit>();
                  final userId = context.read<AuthCubit>().useInfo.id ?? "";
                  switch (value) {
                    case 0:
                      cubit.fetchFollowers(userId: userId);
                      break;
                    case 1:
                      cubit.fetchFollowings(userId: userId);
                      break;
                    case 2:
                      cubit.fetchFriends();
                      break;
                  }
                },
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3, color: Color(0xFF8B5CF6)),
                  insets: EdgeInsets.symmetric(horizontal: 16),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.roboto(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Followers'),
                  Tab(text: 'Following'),
                  Tab(text: 'Friends'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            Followers(),
            Followings(),
            Friend(),
          ],
        ),
      ),
    );
  }
}
