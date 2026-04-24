import 'dart:convert';
import 'dart:developer';
import 'package:bloc/bloc.dart';
import 'package:haptext_api/models/searched_user_model.dart';
import 'package:haptext_api/repository/people_repo/people_repo.dart';
import 'package:haptext_api/utils/toast_helper.dart';
import 'package:haptext_api/utils/session_manager.dart';
import 'package:meta/meta.dart';

part 'people_state.dart';

class PeopleCubit extends Cubit<PeopleState> {
  PeopleRepo peopleRepo;
  PeopleCubit(this.peopleRepo) : super(PeopleInitial()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final currentUser = await SessionManager.getUser();
      final currentUserId = currentUser?.id;
      await fetchFollowings(userId: currentUserId);
      await fetchFriends();
      await fetchFollowers(userId: currentUserId);
      await fetchProfiles();
    } catch (e) {
      log("People init error $e");
    }
  }

  List<SearchedUserProfile> friends = [];
  fetchFriends() async {
    emit(PeopleLoading());
    try {
      final response = await peopleRepo.fetchFriends(page: 1);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        friends.clear();
        for (var user in body['data']['friends']) {
          friends.add(SearchedUserProfile.fromJson(user));
        }
        emit(PeopleLoaded());
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("get friends $e");
    }
  }

  fetchUserProfileById(
      {required String userId, bool loggedInUser = false}) async {
    emit(PeopleLoading());
    try {
      final response = await peopleRepo.getUsers(userId: userId);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        for (var user in searchedUsers) {
          if (user.id.toString() == userId) {
            user.profile = SearchedUserProfile.fromJson(body['data']);

            emit(PeopleSearched(user: user));
          }
        }
        if (loggedInUser) {
          emit(CurrentUser(user: SearchedUserProfile.fromJson(body['data'])));
        }
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("get Users $e");
    }
  }

  List<SearchedUserModel> searchedUsers = [];
  searchFriends({required String query}) async {
    emit(PeopleLoading());
    try {
      final response = await peopleRepo.searchUsers(query: query, page: 1);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        searchedUsers.clear();
        for (var user in body['data']['users']) {
          searchedUsers.add(SearchedUserModel.fromJson(user));
        }
        emit(PeopleLoaded());
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("get Users $e");
    }
  }

  List<SearchedUserProfile> profiles = [];
  fetchProfiles() async {
    emit(PeopleLoading());
    try {
      final response = await peopleRepo.fetchProfiles(page: 1, pageSize: 20);
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        profiles.clear();
        for (var profile in body['data']['result']) {
          profiles.add(SearchedUserProfile.fromJson(profile));
        }
        emit(PeopleLoaded());
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("get all profiles $e");
    }
  }

  List<SearchedUserProfile> followers = [];
  fetchFollowers({userId}) async {
    emit(PeopleLoading());
    try {
      final response = await peopleRepo.fetchFollowers(
          page: 1, userId: userId ?? '');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        followers.clear();
        for (var user in body['data']['followers']) {
          followers.add(SearchedUserProfile.fromJson(user));
        }
        emit(PeopleLoaded());
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("get folowers $e");
    }
  }

  List<SearchedUserProfile> followings = [];
  fetchFollowings({userId}) async {
    emit(PeopleLoading());
    try {
      final response = await peopleRepo.fetchFollowings(
          page: 1, userId: userId ?? '');
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        followings.clear();
        for (var user in body['data']['followings']) {
          followings.add(SearchedUserProfile.fromJson(user));
        }
        emit(PeopleLoaded());
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("get folowings $e");
    }
  }

  followUser({userId}) async {
    emit(PeopleFollowing());
    try {
      final response = await peopleRepo.followUser(userId: userId);
      final body = jsonDecode(response.body);
      if (response.statusCode == 201) {
        ToastMessage.showSuccessToast(message: body['message']);
        for (var user in searchedUsers) {
          if (user.id.toString() == userId) {
            user.following = true;
          }
        }

        emit(PeopleLoaded());
      } else {
        ToastMessage.showErrorToast(
            message: body["errors"]["detail"].toString());
        emit(PeopleError());
      }
    } catch (e) {
      emit(PeopleError());
      log("follow User $e");
    }
  }
}
