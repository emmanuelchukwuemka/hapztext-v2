import 'package:flutter/material.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/exports.dart';

class Friend extends StatefulWidget {
  const Friend({super.key});

  @override
  State<Friend> createState() => _FriendState();
}

class _FriendState extends State<Friend> {
  @override
  Widget build(BuildContext context) {
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
                      hintText: 'Search friends...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // CONTENT
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: BlocBuilder<PeopleCubit, PeopleState>(
              builder: (context, state) {
                final friends = context.read<PeopleCubit>().friends;
                if (friends.isEmpty) {
                  return Center(child: AppText(text: 'No friends found'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final userModel = SearchedUserModel(
                      id: friend.id,
                      username:
                          "${friend.firstName ?? ""} ${friend.lastName ?? ""}"
                              .trim(),
                      profilePicture: friend.profilePicture,
                      profile: friend,
                    );
                    return friendCardWidget(
                      context,
                      '${friend.firstName ?? ""} ${friend.lastName ?? ""}'.trim(),
                      friend.profilePicture ?? 'assets/images/placeholder.jpg',
                      user: userModel,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
